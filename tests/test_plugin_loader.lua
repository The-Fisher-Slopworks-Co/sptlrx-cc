package.path = "../?.lua;../core/?.lua;" .. package.path

local runner = require("tests.runner")
local mocks = require("tests.mocks")

mocks.setup()

local describe, it, expect = runner.describe, runner.it, runner.expect

local plugin_loader = require("core.plugin_loader")

describe("plugin_loader.scan", function()
    it("loads a valid player provider", function()
        local fake_provider = {
            name = "test_player",
            setup = function(config) return { name = "test_player" }, nil end,
            get_state = function(self) return { track_id = "1" }, nil end,
        }
        package.loaded["providers.player.test_player"] = fake_provider
        fs._set("sptlrx-cc/providers/player", { "test_player.lua" })

        local providers = plugin_loader.scan("sptlrx-cc/providers/player", "player")
        expect(#providers).to_equal(1)
        expect(providers[1].name).to_equal("test_player")

        package.loaded["providers.player.test_player"] = nil
        fs._clear()
    end)

    it("skips provider missing required field (name)", function()
        local bad_provider = {
            setup = function(config) return {}, nil end,
            get_state = function(self) return {}, nil end,
        }
        package.loaded["providers.player.bad"] = bad_provider
        fs._set("sptlrx-cc/providers/player", { "bad.lua" })

        local providers = plugin_loader.scan("sptlrx-cc/providers/player", "player")
        expect(#providers).to_equal(0)

        package.loaded["providers.player.bad"] = nil
        fs._clear()
    end)

    it("skips provider missing get_state for player type", function()
        local bad_provider = {
            name = "no_state",
            setup = function(config) return {}, nil end,
        }
        package.loaded["providers.player.no_state"] = bad_provider
        fs._set("sptlrx-cc/providers/player", { "no_state.lua" })

        local providers = plugin_loader.scan("sptlrx-cc/providers/player", "player")
        expect(#providers).to_equal(0)

        package.loaded["providers.player.no_state"] = nil
        fs._clear()
    end)

    it("skips provider missing get_lyrics for lyrics type", function()
        local bad_provider = {
            name = "no_lyrics",
            setup = function(config) return {}, nil end,
        }
        package.loaded["providers.lyrics.no_lyrics"] = bad_provider
        fs._set("sptlrx-cc/providers/lyrics", { "no_lyrics.lua" })

        local providers = plugin_loader.scan("sptlrx-cc/providers/lyrics", "lyrics")
        expect(#providers).to_equal(0)

        package.loaded["providers.lyrics.no_lyrics"] = nil
        fs._clear()
    end)
end)

describe("plugin_loader.find", function()
    it("finds provider by name", function()
        local providers = {
            { name = "alpha" },
            { name = "beta" },
        }
        local found = plugin_loader.find(providers, "beta")
        expect(found).to_be_truthy()
        expect(found.name).to_equal("beta")
    end)

    it("returns nil when provider not found", function()
        local providers = { { name = "alpha" } }
        local found = plugin_loader.find(providers, "missing")
        expect(found).to_be_nil()
    end)
end)

mocks.teardown()

local success = runner.summary()
os.exit(success and 0 or 1)
