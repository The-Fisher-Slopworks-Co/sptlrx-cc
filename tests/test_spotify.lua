package.path = "../?.lua;../providers/?.lua;" .. package.path

local runner = require("tests.runner")
local mocks = require("tests.mocks")

mocks.setup()

local describe, it, expect = runner.describe, runner.it, runner.expect

local spotify = require("providers.player.spotify")

describe("spotify provider", function()
    it("has required interface fields", function()
        expect(spotify.name).to_equal("spotify")
        expect(type(spotify.setup)).to_equal("function")
        expect(type(spotify.get_state)).to_equal("function")
    end)
end)

describe("spotify.setup", function()
    it("obtains access token on setup", function()
        local token_response = '{"access_token":"test_token","expires_in":3600}'
        http._set_response("https://accounts.spotify.com/api/token", 200, token_response)
        textutils._json_responses[token_response] = {
            access_token = "test_token",
            expires_in = 3600,
        }
        os._set_epoch(1000000)

        local config = {
            spotify = {
                client_id = "test_id",
                client_secret = "test_secret",
                refresh_token = "test_refresh",
            },
        }

        local instance, err = spotify.setup(config)
        expect(err).to_be_nil()
        expect(instance).to_be_truthy()

        http._clear()
        textutils._json_responses = {}
    end)

    it("returns error when token request fails", function()
        http._clear()

        local config = {
            spotify = {
                client_id = "test_id",
                client_secret = "test_secret",
                refresh_token = "test_refresh",
            },
        }

        local instance, err = spotify.setup(config)
        expect(instance).to_be_nil()
        expect(err).to_be_truthy()

        http._clear()
    end)
end)

describe("spotify.get_state", function()
    it("parses currently playing track", function()
        local instance = {
            access_token = "test_token",
            expires_at = 9999999999999,
            config = {
                spotify = {
                    client_id = "id",
                    client_secret = "sec",
                    refresh_token = "ref",
                },
            },
        }
        setmetatable(instance, { __index = spotify })

        local response_body = "playing_response"
        textutils._json_responses[response_body] = {
            is_playing = true,
            progress_ms = 42000,
            currently_playing_type = "track",
            item = {
                id = "track123",
                name = "Test Song",
                artists = { { name = "Test Artist" } },
            },
        }
        http._set_response("https://api.spotify.com/v1/me/player/currently-playing", 200, response_body)

        local state, err = spotify.get_state(instance)
        expect(err).to_be_nil()
        expect(state.track_id).to_equal("track123")
        expect(state.artist).to_equal("Test Artist")
        expect(state.title).to_equal("Test Song")
        expect(state.position_ms).to_equal(42000)
        expect(state.is_playing).to_be_truthy()

        http._clear()
        textutils._json_responses = {}
    end)

    it("returns nil for nothing playing (204)", function()
        local instance = {
            access_token = "test_token",
            expires_at = 9999999999999,
            config = {
                spotify = { client_id = "id", client_secret = "sec", refresh_token = "ref" },
            },
        }
        setmetatable(instance, { __index = spotify })

        http._set_response("https://api.spotify.com/v1/me/player/currently-playing", 204, "")

        local state, err = spotify.get_state(instance)
        expect(state).to_be_nil()
        expect(err).to_be_nil()

        http._clear()
    end)

    it("returns error for non-track content type", function()
        local instance = {
            access_token = "test_token",
            expires_at = 9999999999999,
            config = {
                spotify = { client_id = "id", client_secret = "sec", refresh_token = "ref" },
            },
        }
        setmetatable(instance, { __index = spotify })

        local response_body = "ad_response"
        textutils._json_responses[response_body] = {
            is_playing = true,
            currently_playing_type = "ad",
        }
        http._set_response("https://api.spotify.com/v1/me/player/currently-playing", 200, response_body)

        local state, err = spotify.get_state(instance)
        expect(state).to_be_nil()
        expect(err).to_contain("Unsupported content type")

        http._clear()
        textutils._json_responses = {}
    end)
end)

mocks.teardown()

local success = runner.summary()
os.exit(success and 0 or 1)
