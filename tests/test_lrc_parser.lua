package.path = "../?.lua;../lib/?.lua;" .. package.path

local runner = require("tests.runner")
local describe, it, expect = runner.describe, runner.it, runner.expect

local lrc_parser = require("lib.lrc_parser")

describe("lrc_parser.parse", function()
    it("parses standard LRC lines with centiseconds", function()
        local input = "[00:17.12]Opening line\n[00:35.40]Second line"
        local result = lrc_parser.parse(input)
        expect(#result).to_equal(2)
        expect(result[1].time_ms).to_equal(17120)
        expect(result[1].text).to_equal("Opening line")
        expect(result[2].time_ms).to_equal(35400)
        expect(result[2].text).to_equal("Second line")
    end)

    it("parses milliseconds (3 digits after dot)", function()
        local input = "[01:05.123]Three digit ms"
        local result = lrc_parser.parse(input)
        expect(#result).to_equal(1)
        expect(result[1].time_ms).to_equal(65123)
        expect(result[1].text).to_equal("Three digit ms")
    end)

    it("skips lines without timestamps", function()
        local input = "[00:10.00]Valid line\nNo timestamp here\n[00:20.00]Another valid"
        local result = lrc_parser.parse(input)
        expect(#result).to_equal(2)
        expect(result[1].text).to_equal("Valid line")
        expect(result[2].text).to_equal("Another valid")
    end)

    it("keeps empty text as empty string (pause)", function()
        local input = "[00:10.00]\n[00:20.00]After pause"
        local result = lrc_parser.parse(input)
        expect(#result).to_equal(2)
        expect(result[1].text).to_equal("")
        expect(result[1].time_ms).to_equal(10000)
    end)

    it("returns empty table for empty input", function()
        local result = lrc_parser.parse("")
        expect(#result).to_equal(0)
    end)

    it("returns empty table for nil input", function()
        local result = lrc_parser.parse(nil)
        expect(#result).to_equal(0)
    end)

    it("handles minutes > 9", function()
        local input = "[12:30.50]Late in the song"
        local result = lrc_parser.parse(input)
        expect(result[1].time_ms).to_equal(750500)
    end)
end)

describe("lrc_parser.is_synced", function()
    it("returns true when second line has nonzero timestamp", function()
        local lines = {
            { time_ms = 0, text = "First" },
            { time_ms = 5000, text = "Second" },
        }
        expect(lrc_parser.is_synced(lines)).to_be_truthy()
    end)

    it("returns false when second line has zero timestamp", function()
        local lines = {
            { time_ms = 0, text = "First" },
            { time_ms = 0, text = "Second" },
        }
        expect(lrc_parser.is_synced(lines)).to_be_falsy()
    end)

    it("returns false for single line", function()
        local lines = { { time_ms = 0, text = "Only" } }
        expect(lrc_parser.is_synced(lines)).to_be_falsy()
    end)

    it("returns false for empty table", function()
        expect(lrc_parser.is_synced({})).to_be_falsy()
    end)
end)

local success = runner.summary()
os.exit(success and 0 or 1)
