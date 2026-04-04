package.path = "../?.lua;../providers/?.lua;../lib/?.lua;" .. package.path

local runner = require("tests.runner")
local mocks = require("tests.mocks")

mocks.setup()

local describe, it, expect = runner.describe, runner.it, runner.expect

local lrclib = require("providers.lyrics.lrclib")

describe("lrclib provider", function()
    it("has required interface fields", function()
        expect(lrclib.name).to_equal("lrclib")
        expect(type(lrclib.setup)).to_equal("function")
        expect(type(lrclib.get_lyrics)).to_equal("function")
    end)
end)

describe("lrclib._url_encode", function()
    it("passes simple ASCII through", function()
        expect(lrclib._url_encode("hello")).to_equal("hello")
    end)

    it("encodes spaces as %20", function()
        expect(lrclib._url_encode("hello world")).to_equal("hello%20world")
    end)

    it("encodes UTF-8 Cyrillic bytes individually", function()
        -- "т" = D1 82 in UTF-8
        local input = string.char(0xD1, 0x82)
        expect(lrclib._url_encode(input)).to_equal("%D1%82")
    end)

    it("encodes mixed ASCII and UTF-8", function()
        -- "ok т" = 6F 6B 20 D1 82
        local input = "ok " .. string.char(0xD1, 0x82)
        expect(lrclib._url_encode(input)).to_equal("ok%20%D1%82")
    end)

    it("preserves unreserved characters", function()
        expect(lrclib._url_encode("a-b_c.d~e")).to_equal("a-b_c.d~e")
    end)

    it("encodes special characters", function()
        expect(lrclib._url_encode("a&b=c")).to_equal("a%26b%3Dc")
    end)
end)

describe("lrclib.get_lyrics", function()
    it("returns synced lyrics from exact match", function()
        local synced = "[00:05.00]Line one\n[00:10.00]Line two"
        local response_body = "exact_match"
        textutils._json_responses[response_body] = {
            syncedLyrics = synced,
            plainLyrics = "Line one\nLine two",
        }

        local url = "https://lrclib.net/api/get?artist_name=Artist&track_name=Song"
        http._set_response(url, 200, response_body)

        local instance, _ = lrclib.setup({})
        local lines, err = lrclib.get_lyrics(instance, "Artist", "Song")

        expect(err).to_be_nil()
        expect(#lines).to_equal(2)
        expect(lines[1].time_ms).to_equal(5000)
        expect(lines[1].text).to_equal("Line one")
        expect(lines[2].time_ms).to_equal(10000)

        http._clear()
        textutils._json_responses = {}
    end)

    it("falls back to search when exact match fails", function()
        local exact_url = "https://lrclib.net/api/get?artist_name=Artist&track_name=Song"
        http._set_response(exact_url, 404, "")

        local search_body = "search_result"
        textutils._json_responses[search_body] = {
            {
                syncedLyrics = "[00:03.00]Found it",
                plainLyrics = "Found it",
            },
        }

        local search_url = "https://lrclib.net/api/search?q=Artist%20Song"
        http._set_response(search_url, 200, search_body)

        local instance, _ = lrclib.setup({})
        local lines, err = lrclib.get_lyrics(instance, "Artist", "Song")

        expect(err).to_be_nil()
        expect(#lines).to_equal(1)
        expect(lines[1].text).to_equal("Found it")

        http._clear()
        textutils._json_responses = {}
    end)

    it("returns plain lyrics when no synced available", function()
        local response_body = "plain_only"
        textutils._json_responses[response_body] = {
            syncedLyrics = nil,
            plainLyrics = "Line one\nLine two\nLine three",
        }

        local url = "https://lrclib.net/api/get?artist_name=Artist&track_name=Song"
        http._set_response(url, 200, response_body)

        local instance, _ = lrclib.setup({})
        local lines, err = lrclib.get_lyrics(instance, "Artist", "Song")

        expect(err).to_be_nil()
        expect(#lines).to_equal(3)
        expect(lines[1].time_ms).to_equal(0)
        expect(lines[1].text).to_equal("Line one")
        expect(lines[2].time_ms).to_equal(0)

        http._clear()
        textutils._json_responses = {}
    end)

    it("encodes Cyrillic UTF-8 in search URL", function()
        -- Exact match fails
        -- "т" in UTF-8 is D1 82
        local artist = string.char(0xD1, 0x82) -- "т"
        local title = "song"
        local exact_url = "https://lrclib.net/api/get?artist_name=%D1%82&track_name=song"
        http._set_response(exact_url, 404, "")

        -- Search with properly encoded UTF-8
        local search_body = "cyrillic_result"
        textutils._json_responses[search_body] = {
            {
                syncedLyrics = "[00:01.00]Found cyrillic",
                plainLyrics = "Found cyrillic",
            },
        }
        local search_url = "https://lrclib.net/api/search?q=%D1%82%20song"
        http._set_response(search_url, 200, search_body)

        local instance, _ = lrclib.setup({})
        local lines, err = lrclib.get_lyrics(instance, artist, title)

        expect(err).to_be_nil()
        expect(#lines).to_equal(1)
        expect(lines[1].text).to_equal("Found cyrillic")

        http._clear()
        textutils._json_responses = {}
    end)

    it("returns nil when no lyrics found anywhere", function()
        local exact_url = "https://lrclib.net/api/get?artist_name=Unknown&track_name=Nothing"
        http._set_response(exact_url, 404, "")

        local search_body = "empty_search"
        textutils._json_responses[search_body] = {}

        local search_url = "https://lrclib.net/api/search?q=Unknown%20Nothing"
        http._set_response(search_url, 200, search_body)

        local instance, _ = lrclib.setup({})
        local lines, err = lrclib.get_lyrics(instance, "Unknown", "Nothing")

        expect(lines).to_be_nil()
        expect(err).to_contain("No lyrics found")

        http._clear()
        textutils._json_responses = {}
    end)
end)

mocks.teardown()

local success = runner.summary()
os.exit(success and 0 or 1)
