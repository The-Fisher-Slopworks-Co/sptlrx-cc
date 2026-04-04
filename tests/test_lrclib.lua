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

describe("lrclib._latin1_to_utf8", function()
    it("passes ASCII through unchanged", function()
        expect(lrclib._latin1_to_utf8("Hello")).to_equal("Hello")
    end)

    it("converts Latin-1 byte 0xF1 (ñ) to UTF-8 C3 B1", function()
        local latin1 = string.char(0xF1) -- ñ as single Latin-1 byte
        local utf8 = lrclib._latin1_to_utf8(latin1)
        expect(utf8).to_equal(string.char(0xC3, 0xB1))
    end)

    it("converts Latin-1 byte 0xE9 (é) to UTF-8 C3 A9", function()
        local latin1 = string.char(0xE9)
        local utf8 = lrclib._latin1_to_utf8(latin1)
        expect(utf8).to_equal(string.char(0xC3, 0xA9))
    end)

    it("handles mixed ASCII and Latin-1", function()
        -- "Señorita" with ñ as Latin-1 byte 0xF1
        local latin1 = "Se" .. string.char(0xF1) .. "orita"
        local utf8 = lrclib._latin1_to_utf8(latin1)
        expect(utf8).to_equal("Se" .. string.char(0xC3, 0xB1) .. "orita")
    end)
end)

describe("lrclib._strip_non_ascii", function()
    it("passes ASCII through unchanged", function()
        expect(lrclib._strip_non_ascii("Hello World")).to_equal("Hello World")
    end)

    it("strips non-ASCII bytes", function()
        local s = "D" .. string.char(0xE9) .. "j" .. string.char(0xE0) .. " Vu"
        expect(lrclib._strip_non_ascii(s)).to_equal("Dj Vu")
    end)

    it("collapses multiple spaces", function()
        local s = "A" .. string.char(0xE9, 0xE8) .. "B"
        expect(lrclib._strip_non_ascii(s)).to_equal("AB")
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

    it("falls back to ASCII-stripped search for non-ASCII names", function()
        -- Exact match with latin1→utf8 encoded URL fails
        local exact_url = "https://lrclib.net/api/get?artist_name=Se%C3%B1orita&track_name=Song"
        http._set_response(exact_url, 404, "")

        -- UTF-8 search also fails
        local utf8_search_url = "https://lrclib.net/api/search?q=Se%C3%B1orita%20Song"
        http._set_response(utf8_search_url, 200, "empty1")
        textutils._json_responses["empty1"] = {}

        -- ASCII-stripped search succeeds
        local stripped_search_body = "stripped_result"
        textutils._json_responses[stripped_search_body] = {
            {
                syncedLyrics = "[00:01.00]Found via stripped",
                plainLyrics = "Found via stripped",
            },
        }
        local stripped_search_url = "https://lrclib.net/api/search?q=Seorita%20Song"
        http._set_response(stripped_search_url, 200, stripped_search_body)

        -- Artist name with Latin-1 ñ (byte 0xF1)
        local artist = "Se" .. string.char(0xF1) .. "orita"
        local instance, _ = lrclib.setup({})
        local lines, err = lrclib.get_lyrics(instance, artist, "Song")

        expect(err).to_be_nil()
        expect(#lines).to_equal(1)
        expect(lines[1].text).to_equal("Found via stripped")

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
