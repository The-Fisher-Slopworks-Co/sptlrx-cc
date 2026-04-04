local lrc_parser = require("lib.lrc_parser")

local lrclib = {}

local BASE_URL = "https://lrclib.net/api"

-- CC:Tweaked's JSON parser may convert Unicode codepoints to single Latin-1
-- bytes (e.g. ñ U+00F1 → byte 0xF1). textutils.urlEncode then produces %F1
-- instead of the UTF-8 %C3%B1 that LRCLib expects. This function re-encodes
-- bytes 0x80-0xFF as proper two-byte UTF-8 sequences.
local function latin1_to_utf8(str)
    return str:gsub("[\128-\255]", function(c)
        local b = string.byte(c)
        return string.char(0xC0 + math.floor(b / 64), 0x80 + (b % 64))
    end)
end

-- Strip everything outside printable ASCII for a last-resort fuzzy search.
-- "Déjà Vu" → "Dj Vu", which is messy but LRCLib's search handles it.
local function strip_non_ascii(str)
    return str:gsub("[\128-\255]+", ""):gsub("%s+", " ")
end

local function parse_plain(text)
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, { time_ms = 0, text = line })
    end
    return lines
end

local function fetch_exact(artist, title)
    local url = BASE_URL .. "/get?artist_name=" .. textutils.urlEncode(latin1_to_utf8(artist))
        .. "&track_name=" .. textutils.urlEncode(latin1_to_utf8(title))

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

local function fetch_search(query)
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
    -- 1. Exact match (latin1→utf8 encoded)
    local data = fetch_exact(artist, title)

    -- 2. Fuzzy search with utf8-fixed query
    if not data then
        local query = latin1_to_utf8(artist) .. " " .. latin1_to_utf8(title)
        data = fetch_search(query)
    end

    -- 3. Last resort: ASCII-only search (strips diacritics etc.)
    if not data then
        local stripped = strip_non_ascii(artist) .. " " .. strip_non_ascii(title)
        stripped = stripped:gsub("^%s+", ""):gsub("%s+$", "")
        if stripped ~= "" then
            data = fetch_search(stripped)
        end
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
lrclib._latin1_to_utf8 = latin1_to_utf8
lrclib._strip_non_ascii = strip_non_ascii

return lrclib
