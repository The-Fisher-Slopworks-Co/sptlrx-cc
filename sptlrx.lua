-- sptlrx-cc: Synchronized Spotify lyrics for CC:Tweaked

-- Resolve base directory from running program path
local program_path = shell.getRunningProgram()
local base_dir = program_path:match("(.+)/[^/]+$") or ""
if base_dir ~= "" then
    base_dir = base_dir .. "/"
end

-- Set up require paths
package.path = base_dir .. "?.lua;" .. base_dir .. "?/init.lua;" .. package.path

local config_loader = require("core.config_loader")
local plugin_loader = require("core.plugin_loader")
local sync = require("core.sync")
local renderer = require("core.renderer")

-- Load config
local raw_config = dofile(base_dir .. "config.lua")
local config, err = config_loader.load(raw_config)
if not config then
    printError("Config error: " .. err)
    return
end

-- Discover providers
local player_dir = base_dir .. "providers/player"
local lyrics_dir = base_dir .. "providers/lyrics"

local player_providers = plugin_loader.scan(player_dir, "player")
local lyrics_providers = plugin_loader.scan(lyrics_dir, "lyrics")

-- Find active providers
local player_plugin = plugin_loader.find(player_providers, config.player)
if not player_plugin then
    printError("Provider '" .. config.player .. "' not found in providers/player/")
    return
end

local lyrics_plugin = plugin_loader.find(lyrics_providers, config.lyrics)
if not lyrics_plugin then
    printError("Provider '" .. config.lyrics .. "' not found in providers/lyrics/")
    return
end

-- Initialize providers
local player, perr = player_plugin.setup(config)
if not player then
    printError("Player setup failed: " .. (perr or "unknown error"))
    return
end

local lyrics_provider, lerr = lyrics_plugin.setup(config)
if not lyrics_provider then
    printError("Lyrics provider setup failed: " .. (lerr or "unknown error"))
    return
end

-- Set up text filter (transliteration for Cyrillic support)
renderer.text_filter = require("lib.translit")

-- Initialize renderer and run
renderer.init()
sync.run(player, lyrics_provider, renderer, config)

-- Clean exit
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)
