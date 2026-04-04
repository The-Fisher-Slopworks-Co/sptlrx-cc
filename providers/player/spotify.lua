local spotify = {}

local TOKEN_URL = "https://accounts.spotify.com/api/token"
local PLAYER_URL = "https://api.spotify.com/v1/me/player/currently-playing"

local function refresh_access_token(self)
    local body = "grant_type=refresh_token"
        .. "&refresh_token=" .. textutils.urlEncode(self.config.spotify.refresh_token)
        .. "&client_id=" .. textutils.urlEncode(self.config.spotify.client_id)
        .. "&client_secret=" .. textutils.urlEncode(self.config.spotify.client_secret)

    local response, err = http.post(TOKEN_URL, body, {
        ["Content-Type"] = "application/x-www-form-urlencoded",
    })

    if not response then
        return nil, "Failed to refresh token: " .. (err or "unknown error")
    end

    local data = textutils.unserializeJSON(response.readAll())
    response.close()

    if not data or not data.access_token then
        return nil, "Token expired. Update refresh_token in config.lua"
    end

    self.access_token = data.access_token
    self.expires_at = os.epoch("utc") + (data.expires_in * 1000)

    return true
end

spotify.name = "spotify"

function spotify.setup(config)
    local instance = {
        access_token = nil,
        expires_at = 0,
        config = config,
    }
    setmetatable(instance, { __index = spotify })

    local ok, err = refresh_access_token(instance)
    if not ok then
        return nil, err
    end

    return instance, nil
end

function spotify.get_state(self)
    -- Auto-refresh if needed
    if os.epoch("utc") >= self.expires_at - 60000 then
        local ok, err = refresh_access_token(self)
        if not ok then
            return nil, "Token expired. Update refresh_token in config.lua"
        end
    end

    local response, err = http.get(PLAYER_URL, {
        ["Authorization"] = "Bearer " .. self.access_token,
    })

    if not response then
        return nil, "No connection, retrying..."
    end

    local code = response.getResponseCode()

    if code == 204 then
        response.close()
        return nil, nil
    end

    local body = response.readAll()
    response.close()

    local data = textutils.unserializeJSON(body)
    if not data then
        return nil, "Failed to parse Spotify response"
    end

    if data.currently_playing_type and data.currently_playing_type ~= "track" then
        return nil, "Unsupported content type"
    end

    if not data.item then
        return nil, nil
    end

    local artist = "Unknown"
    if data.item.artists and #data.item.artists > 0 then
        artist = data.item.artists[1].name
    end

    return {
        track_id = data.item.id,
        artist = artist,
        title = data.item.name,
        position_ms = data.progress_ms or 0,
        is_playing = data.is_playing or false,
    }, nil
end

return spotify
