local lrc_parser = require("lib.lrc_parser")

local lrclib = {}

local BASE_URL = "https://lrclib.net/api"

local function parse_plain(text)
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, { time_ms = 0, text = line })
    end
    return lines
end

local function fetch_exact(artist, title)
    local url = BASE_URL .. "/get?artist_name=" .. textutils.urlEncode(artist)
        .. "&track_name=" .. textutils.urlEncode(title)

    local response = http.get(url, {
        ["User-Agent"] = "sptlrx-ng v1.0.0",
    })

    if not response then return nil end

    local code = response.getResponseCode()
    if code ~= 200 then
        response.close()
        return nil
    end

    local body = response.readAll()
    response.close()

    return textutils.unserializeJSON(body)
end

local function fetch_search(artist, title)
    local query = artist .. " " .. title
    local url = BASE_URL .. "/search?q=" .. textutils.urlEncode(query)

    local response = http.get(url, {
        ["User-Agent"] = "sptlrx-ng v1.0.0",
    })

    if not response then return nil end

    local code = response.getResponseCode()
    if code ~= 200 then
        response.close()
        return nil
    end

    local body = response.readAll()
    response.close()

    local results = textutils.unserializeJSON(body)
    if results and #results > 0 then
        return results[1]
    end

    return nil
end

lrclib.name = "lrclib"

function lrclib.setup(config)
    local instance = {}
    setmetatable(instance, { __index = lrclib })
    return instance, nil
end

function lrclib.get_lyrics(self, artist, title)
    local data = fetch_exact(artist, title)

    if not data then
        data = fetch_search(artist, title)
    end

    if not data then
        return nil, "No lyrics found for " .. artist .. " - " .. title
    end

    if data.syncedLyrics and data.syncedLyrics ~= "" then
        return lrc_parser.parse(data.syncedLyrics), nil
    end

    if data.plainLyrics and data.plainLyrics ~= "" then
        return parse_plain(data.plainLyrics), nil
    end

    return nil, "No lyrics found for " .. artist .. " - " .. title
end

return lrclib
