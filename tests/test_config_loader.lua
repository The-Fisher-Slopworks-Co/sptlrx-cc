package.path = "../?.lua;../core/?.lua;" .. package.path

local runner = require("tests.runner")
local mocks = require("tests.mocks")

mocks.setup()

local describe, it, expect = runner.describe, runner.it, runner.expect

local config_loader = require("core.config_loader")

describe("config_loader.load", function()
    it("loads a valid config and applies defaults", function()
        local raw = {
            player = "spotify",
            lyrics = "lrclib",
            spotify = {
                client_id = "id123",
                client_secret = "sec456",
                refresh_token = "ref789",
            },
        }
        local cfg, err = config_loader.load(raw)
        expect(err).to_be_nil()
        expect(cfg.player).to_equal("spotify")
        expect(cfg.lyrics).to_equal("lrclib")
        expect(cfg.update_interval).to_equal(2000)
        expect(cfg.timer_interval).to_equal(200)
        expect(cfg.style.current_color).to_equal(colors.white)
        expect(cfg.style.before_color).to_equal(colors.gray)
        expect(cfg.style.after_color).to_equal(colors.gray)
        expect(cfg.style.bg_color).to_equal(colors.black)
    end)

    it("preserves user-specified optional values", function()
        local raw = {
            player = "spotify",
            lyrics = "lrclib",
            spotify = {
                client_id = "id",
                client_secret = "sec",
                refresh_token = "ref",
            },
            update_interval = 5000,
            timer_interval = 100,
            style = {
                current_color = colors.yellow,
                before_color = colors.lightGray,
                after_color = colors.lightGray,
                bg_color = colors.blue,
            },
        }
        local cfg, err = config_loader.load(raw)
        expect(err).to_be_nil()
        expect(cfg.update_interval).to_equal(5000)
        expect(cfg.style.current_color).to_equal(colors.yellow)
    end)

    it("returns error when player is missing", function()
        local raw = { lyrics = "lrclib", spotify = { client_id = "a", client_secret = "b", refresh_token = "c" } }
        local cfg, err = config_loader.load(raw)
        expect(cfg).to_be_nil()
        expect(err).to_contain("player")
    end)

    it("returns error when spotify.client_id is missing", function()
        local raw = { player = "spotify", lyrics = "lrclib", spotify = { client_secret = "b", refresh_token = "c" } }
        local cfg, err = config_loader.load(raw)
        expect(cfg).to_be_nil()
        expect(err).to_contain("spotify.client_id")
    end)

    it("returns error when spotify.client_secret is missing", function()
        local raw = { player = "spotify", lyrics = "lrclib", spotify = { client_id = "a", refresh_token = "c" } }
        local cfg, err = config_loader.load(raw)
        expect(cfg).to_be_nil()
        expect(err).to_contain("spotify.client_secret")
    end)

    it("returns error when spotify.refresh_token is missing", function()
        local raw = { player = "spotify", lyrics = "lrclib", spotify = { client_id = "a", client_secret = "b" } }
        local cfg, err = config_loader.load(raw)
        expect(cfg).to_be_nil()
        expect(err).to_contain("spotify.refresh_token")
    end)

    it("returns error when spotify table is missing entirely", function()
        local raw = { player = "spotify", lyrics = "lrclib" }
        local cfg, err = config_loader.load(raw)
        expect(cfg).to_be_nil()
        expect(err).to_contain("spotify")
    end)

    it("returns error when spotify.client_id is empty string", function()
        local raw = { player = "spotify", lyrics = "lrclib", spotify = { client_id = "", client_secret = "b", refresh_token = "c" } }
        local cfg, err = config_loader.load(raw)
        expect(cfg).to_be_nil()
        expect(err).to_contain("spotify.client_id")
    end)

    it("defaults lyrics to lrclib when missing", function()
        local raw = {
            player = "spotify",
            spotify = { client_id = "a", client_secret = "b", refresh_token = "c" },
        }
        local cfg, err = config_loader.load(raw)
        expect(err).to_be_nil()
        expect(cfg.lyrics).to_equal("lrclib")
    end)
end)

mocks.teardown()

local success = runner.summary()
os.exit(success and 0 or 1)
