package.path = "../?.lua;../core/?.lua;" .. package.path

local runner = require("tests.runner")
local mocks = require("tests.mocks")

mocks.setup()

local describe, it, expect = runner.describe, runner.it, runner.expect

local renderer = require("core.renderer")

describe("renderer.word_wrap", function()
    it("returns line as-is when it fits", function()
        local result = renderer.word_wrap("Hello world", 51)
        expect(#result).to_equal(1)
        expect(result[1]).to_equal("Hello world")
    end)

    it("wraps long line at word boundary", function()
        local result = renderer.word_wrap("This is a very long line that should wrap", 20)
        expect(#result).to_equal(3)
        expect(result[1]).to_equal("This is a very long")
        expect(result[2]).to_equal("line that should")
        expect(result[3]).to_equal("wrap")
    end)

    it("handles single word longer than width", function()
        local result = renderer.word_wrap("Supercalifragilistic", 10)
        expect(#result).to_equal(2)
        expect(result[1]).to_equal("Supercalif")
        expect(result[2]).to_equal("ragilistic")
    end)

    it("handles empty string", function()
        local result = renderer.word_wrap("", 51)
        expect(#result).to_equal(1)
        expect(result[1]).to_equal("")
    end)
end)

describe("renderer.compute_layout", function()
    it("centers current line vertically", function()
        local lines = {}
        for i = 1, 10 do
            table.insert(lines, { time_ms = i * 1000, text = "Line " .. i })
        end

        local layout = renderer.compute_layout(lines, 5, 51, 7)
        -- Center row = ceil(7/2) = 4
        expect(layout.center_row).to_equal(4)
        expect(#layout.visible).to_equal(7)
        expect(layout.visible[4].text).to_equal("Line 5")
        expect(layout.visible[4].is_current).to_be_truthy()
    end)

    it("handles fewer lyrics than screen height", function()
        local lines = {
            { time_ms = 0, text = "Only line" },
        }
        local layout = renderer.compute_layout(lines, 1, 51, 7)
        expect(layout.visible[layout.center_row].text).to_equal("Only line")
        expect(layout.visible[layout.center_row].is_current).to_be_truthy()
    end)

    it("applies word wrap to long lines", function()
        local lines = {
            { time_ms = 0, text = "Short" },
            { time_ms = 5000, text = "This line is way too long to fit in twenty chars" },
            { time_ms = 10000, text = "Short again" },
        }
        local layout = renderer.compute_layout(lines, 2, 20, 9)
        local current_count = 0
        for _, v in ipairs(layout.visible) do
            if v.is_current then current_count = current_count + 1 end
        end
        expect(current_count >= 1).to_be_truthy()
    end)
end)

describe("renderer.center_text", function()
    it("centers text in given width", function()
        local result = renderer.center_text("Hello", 11)
        expect(result).to_equal("   Hello   ")
    end)

    it("returns text as-is if wider than width", function()
        local result = renderer.center_text("Hello World!", 5)
        expect(result).to_equal("Hello World!")
    end)
end)

mocks.teardown()

local success = runner.summary()
os.exit(success and 0 or 1)
