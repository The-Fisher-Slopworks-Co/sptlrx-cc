local config_loader = {}

local DEFAULTS = {
    lyrics = "lrclib",
    update_interval = 2000,
    timer_interval = 200,
    style = {
        current_color = colors.white,
        before_color = colors.gray,
        after_color = colors.gray,
        bg_color = colors.black,
    },
}

local function check_required(raw, path)
    local parts = {}
    for part in (path .. "."):gmatch("(.-)%.") do
        table.insert(parts, part)
    end

    local current = raw
    for i, part in ipairs(parts) do
        if type(current) ~= "table" or current[part] == nil or current[part] == "" then
            return "Missing required field: " .. path
        end
        current = current[part]
    end
    return nil
end

function config_loader.load(raw)
    if type(raw) ~= "table" then
        return nil, "Config must be a table"
    end

    local required = {
        "player",
        "spotify",
        "spotify.client_id",
        "spotify.client_secret",
        "spotify.refresh_token",
    }

    for _, path in ipairs(required) do
        local err = check_required(raw, path)
        if err then return nil, err end
    end

    local cfg = {}
    cfg.player = raw.player
    cfg.lyrics = raw.lyrics or DEFAULTS.lyrics
    cfg.spotify = {
        client_id = raw.spotify.client_id,
        client_secret = raw.spotify.client_secret,
        refresh_token = raw.spotify.refresh_token,
    }
    cfg.update_interval = raw.update_interval or DEFAULTS.update_interval
    cfg.timer_interval = raw.timer_interval or DEFAULTS.timer_interval

    cfg.style = {}
    local raw_style = raw.style or {}
    cfg.style.current_color = raw_style.current_color or DEFAULTS.style.current_color
    cfg.style.before_color = raw_style.before_color or DEFAULTS.style.before_color
    cfg.style.after_color = raw_style.after_color or DEFAULTS.style.after_color
    cfg.style.bg_color = raw_style.bg_color or DEFAULTS.style.bg_color

    return cfg, nil
end

return config_loader
