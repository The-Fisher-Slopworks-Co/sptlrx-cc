package.path = "../?.lua;../core/?.lua;" .. package.path

local runner = require("tests.runner")
local mocks = require("tests.mocks")

mocks.setup()

local describe, it, expect = runner.describe, runner.it, runner.expect

local sync = require("core.sync")

describe("sync.get_index", function()
    local lines = {
        { time_ms = 0,     text = "Line 1" },
        { time_ms = 5000,  text = "Line 2" },
        { time_ms = 10000, text = "Line 3" },
        { time_ms = 15000, text = "Line 4" },
        { time_ms = 20000, text = "Line 5" },
    }

    it("returns 1 when position is before first line", function()
        expect(sync.get_index(0, 1, lines)).to_equal(1)
    end)

    it("returns correct index for normal forward progression", function()
        expect(sync.get_index(5000, 1, lines)).to_equal(2)
        expect(sync.get_index(7500, 2, lines)).to_equal(2)
        expect(sync.get_index(10000, 2, lines)).to_equal(3)
    end)

    it("returns last index when position is past last line", function()
        expect(sync.get_index(25000, 4, lines)).to_equal(5)
    end)

    it("handles seek backward", function()
        expect(sync.get_index(3000, 4, lines)).to_equal(1)
    end)

    it("handles exact timestamp match", function()
        expect(sync.get_index(15000, 1, lines)).to_equal(4)
    end)

    it("returns 1 for single-line lyrics", function()
        local single = { { time_ms = 0, text = "Only line" } }
        expect(sync.get_index(5000, 1, single)).to_equal(1)
    end)
end)

describe("sync.interpolate_position", function()
    it("advances position when playing", function()
        local state = {
            position_ms = 5000,
            is_playing = true,
        }
        os._set_epoch(1000000)
        local last_poll_time = 1000000

        os._set_epoch(1000500) -- 500ms later
        local pos = sync.interpolate_position(state, last_poll_time)
        expect(pos).to_equal(5500)
    end)

    it("freezes position when paused", function()
        local state = {
            position_ms = 5000,
            is_playing = false,
        }
        os._set_epoch(1000000)
        local last_poll_time = 1000000

        os._set_epoch(1002000) -- 2 seconds later
        local pos = sync.interpolate_position(state, last_poll_time)
        expect(pos).to_equal(5000)
    end)
end)

mocks.teardown()

local success = runner.summary()
os.exit(success and 0 or 1)
