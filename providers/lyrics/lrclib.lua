local lrc_parser = require("lib.lrc_parser")

local lrclib = {}

local BASE_URL = "https://lrclib.net/api"

-- CC:Tweaked's textutils.urlEncode may mishandle multi-byte UTF-8 sequences
-- (e.g. interpreting raw bytes as Latin-1 before encoding). This encoder
-- works directly on bytes: each non-unreserved byte gets percent-encoded,
-- which is correct for UTF-8 strings since the bytes are already valid UTF-8.
local function url_encode(str)
    return str:gsub("([^%w%-_.~ ])", function(c)
        return string.format("%%%02X", string.byte(c))
    end):gsub(" ", "%%20")
end

local function parse_plain(text)
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, { time_ms = 0, text = line })
    end
    return lines
end

local function fetch_exact(artist, title)
    local url = BASE_URL .. "/get?artist_name=" .. url_encode(artist)
        .. "&track_name=" .. url_encode(title)

    local response = http.get(url, {
        ["User-Agent"] = "sptlrx-cc v1.0.0",
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

local function fetch_search(query)
    local url = BASE_URL .. "/search?q=" .. url_encode(query)

    local response = http.get(url, {
        ["User-Agent"] = "sptlrx-cc v1.0.0",
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
        data = fetch_search(artist .. " " .. title)
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

-- Exposed for testing
lrclib._url_encode = url_encode

return lrclib
