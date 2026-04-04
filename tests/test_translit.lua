package.path = "../?.lua;../lib/?.lua;" .. package.path

local runner = require("tests.runner")
local describe, it, expect = runner.describe, runner.it, runner.expect

local translit = require("lib.translit")

describe("translit", function()
    it("passes ASCII through unchanged", function()
        expect(translit("Hello world")).to_equal("Hello world")
    end)

    it("transliterates lowercase Cyrillic", function()
        -- "привет" in UTF-8
        local input = string.char(
            0xD0, 0xBF, -- п
            0xD1, 0x80, -- р
            0xD0, 0xB8, -- и
            0xD0, 0xB2, -- в
            0xD0, 0xB5, -- е
            0xD1, 0x82  -- т
        )
        expect(translit(input)).to_equal("privet")
    end)

    it("transliterates uppercase Cyrillic", function()
        -- "ТЕСТ" in UTF-8
        local input = string.char(
            0xD0, 0xA2, -- Т
            0xD0, 0x95, -- Е
            0xD0, 0xA1, -- С
            0xD0, 0xA2  -- Т
        )
        expect(translit(input)).to_equal("TEST")
    end)

    it("handles mixed ASCII and Cyrillic", function()
        -- "ok тест" in UTF-8
        local input = "ok " .. string.char(
            0xD1, 0x82, -- т
            0xD0, 0xB5, -- е
            0xD1, 0x81, -- с
            0xD1, 0x82  -- т
        )
        expect(translit(input)).to_equal("ok test")
    end)

    it("transliterates multi-char mappings", function()
        -- "ж ч ш щ" in UTF-8
        local zh = string.char(0xD0, 0xB6)
        local ch = string.char(0xD1, 0x87)
        local sh = string.char(0xD1, 0x88)
        local sch = string.char(0xD1, 0x89)
        local input = zh .. " " .. ch .. " " .. sh .. " " .. sch
        expect(translit(input)).to_equal("zh ch sh sch")
    end)

    it("drops hard and soft signs", function()
        -- "объём" = о б ъ ё м
        local input = string.char(
            0xD0, 0xBE, -- о
            0xD0, 0xB1, -- б
            0xD1, 0x8A, -- ъ
            0xD1, 0x91, -- ё
            0xD0, 0xBC  -- м
        )
        expect(translit(input)).to_equal("obyom")
    end)

    it("handles yo (ё/Ё)", function()
        local yo_lower = string.char(0xD1, 0x91)
        local yo_upper = string.char(0xD0, 0x81)
        expect(translit(yo_lower)).to_equal("yo")
        expect(translit(yo_upper)).to_equal("Yo")
    end)

    it("returns empty string for empty input", function()
        expect(translit("")).to_equal("")
    end)

    it("preserves numbers and punctuation", function()
        expect(translit("123!?")).to_equal("123!?")
    end)
end)

local success = runner.summary()
os.exit(success and 0 or 1)
