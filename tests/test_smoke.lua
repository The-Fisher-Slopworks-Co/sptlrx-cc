package.path = "../?.lua;../lib/?.lua;../core/?.lua;" .. package.path

local runner = require("tests.runner")
local mocks = require("tests.mocks")

mocks.setup()

local describe, it, expect = runner.describe, runner.it, runner.expect

describe("test runner", function()
    it("passes truthy assertions", function()
        expect(true).to_be_truthy()
    end)
    it("passes equality assertions", function()
        expect(42).to_equal(42)
    end)
    it("passes deep equality", function()
        expect({ a = 1, b = 2 }).to_deep_equal({ a = 1, b = 2 })
    end)
    it("passes nil assertions", function()
        expect(nil).to_be_nil()
    end)
end)

describe("mocks", function()
    it("provides colors", function()
        expect(colors.white).to_equal(1)
        expect(colors.black).to_equal(32768)
    end)
    it("provides term.getSize", function()
        local w, h = term.getSize()
        expect(w).to_equal(51)
        expect(h).to_equal(19)
    end)
    it("provides os.epoch", function()
        local t = os.epoch("utc")
        expect(t).to_equal(1000000)
    end)
end)

mocks.teardown()

local success = runner.summary()
os.exit(success and 0 or 1)
