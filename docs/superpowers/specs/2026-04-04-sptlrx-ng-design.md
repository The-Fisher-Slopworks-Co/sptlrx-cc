# sptlrx-cc Design Spec

Modular Lua utility for CC:Tweaked that displays synchronized Spotify lyrics in karaoke style.

## Platform & Constraints

- **Runtime:** CC:Tweaked (Minecraft ComputerCraft fork)
- **Computer type:** Advanced Computer (16 colors)
- **Terminal size:** Dynamic via `term.getSize()`, responds to `term_resize`
- **HTTP:** CC:Tweaked `http.get()` / `http.post()` with headers
- **Timing:** `os.epoch("utc")` (milliseconds), `os.startTimer()`, `os.pullEvent()`
- **Launch:** Foreground, Ctrl+T to exit (`terminate` event)

## Architecture: Monolithic Core + Plugin Folders

```
sptlrx-cc/
├── sptlrx.lua              -- entry point
├── config.lua               -- user config (Lua table)
├── core/
│   ├── config_loader.lua    -- load & validate config, apply defaults
│   ├── sync.lua             -- sync engine: polling, interpolation, line index
│   ├── renderer.lua         -- karaoke-style terminal rendering
│   └── plugin_loader.lua    -- scan and load providers from folders
├── providers/
│   ├── player/
│   │   └── spotify.lua      -- Spotify Web API + auto-refresh
│   └── lyrics/
│       └── lrclib.lua       -- LRCLib.net provider
└── lib/
    └── lrc_parser.lua       -- [MM:SS.CC] parser → {time_ms, text} table
```

## Plugin System

Two provider types: **player** and **lyrics**. Each provider is a Lua file returning a table with required methods.

### Player Provider Interface

```lua
return {
    name = "spotify",
    setup = function(config)
        -- Initialize with config (tokens, URLs)
        -- Returns instance or nil, error
    end,
    get_state = function(self)
        -- Returns { track_id, artist, title, position_ms, is_playing }
        -- or nil, error
    end,
}
```

### Lyrics Provider Interface

```lua
return {
    name = "lrclib",
    setup = function(config)
        -- Returns instance or nil, error
    end,
    get_lyrics = function(self, artist, title)
        -- Returns { { time_ms = 0, text = "..." }, ... }
        -- or nil, error
    end,
}
```

### Plugin Loading

On startup, `plugin_loader` scans `providers/player/` and `providers/lyrics/`, calls `require` on each file, validates required fields (`name`, `setup`, `get_state`/`get_lyrics`). Active provider selected by `config.player` and `config.lyrics` values.

Adding a new provider: drop a file in the folder, set its `name` in config. No core changes.

If the provider specified in config is not found among loaded plugins, exit with error: "Provider '<name>' not found in providers/<type>/". If a plugin file fails to load or is missing required fields, skip it with a warning and continue loading others.

## Spotify Player

### Authentication

User obtains credentials via Spotify Developer Dashboard (create app, get client_id/client_secret, complete OAuth once in real browser for refresh_token). Config stores:

```lua
spotify = {
    client_id = "...",
    client_secret = "...",
    refresh_token = "...",
}
```

### Auto-refresh

1. On `setup()` — request `access_token` via `refresh_token` (POST `https://accounts.spotify.com/api/token`)
2. Store `access_token` and `expires_at` in memory (not persisted)
3. Before each `get_state()` — check `os.epoch("utc") >= expires_at - 60000`, refresh if needed
4. If refresh fails — return error "Token expired. Update refresh_token in config.lua"

### get_state() Polling

- GET `https://api.spotify.com/v1/me/player/currently-playing`
- Header: `Authorization: Bearer <access_token>`
- Parse via `textutils.unserializeJSON()`
- Extract: `is_playing`, `progress_ms`, `item.id`, `item.name`, `item.artists[1].name`
- Rate: 1 request per `update_interval` (default 2s) = 30 req/min, well under Spotify's ~180/min limit

## LRCLib Lyrics Provider

### get_lyrics() Flow

1. **Exact match:** GET `https://lrclib.net/api/get?artist_name=<artist>&track_name=<title>`
2. **Fallback search:** If not found — GET `https://lrclib.net/api/search?q=<artist> <title>`, take first result
3. Response has `syncedLyrics` (LRC format) and `plainLyrics` (plain text). Priority: synced.

### LRC Parser (`lib/lrc_parser.lua`)

Input: `"[00:17.12]Opening line\n[00:35.40]Second line"`

Output: `{ { time_ms = 17120, text = "Opening line" }, { time_ms = 35400, text = "Second line" } }`

Rules:
- Format `[MM:SS.CC]` — minutes, seconds, centiseconds (or milliseconds)
- 2 digits after dot: multiply by 10 (centiseconds → ms)
- 3 digits after dot: use as-is (ms)
- Lines without timestamp: skip
- Empty text after `]`: keep as empty string (pause between verses)

### Sync Detection

If only `plainLyrics` available (no timestamps): display statically, full text, no scrolling. Detection: second line has `time_ms == 0`.

## Sync Engine (`core/sync.lua`)

### Main Loop

```
Event-driven loop using os.startTimer + os.pullEvent:

1. Poll player:get_state() every update_interval (default 2000ms)
2. Between polls — interpolate position every timer_interval (default 200ms)
3. Determine current line index by position
4. If line changed — call renderer callback
```

### Position Interpolation

- After receiving `position_ms` from Spotify: store `os.epoch("utc")` as `last_poll_time`
- Between polls: `current_pos = position_ms + (os.epoch("utc") - last_poll_time)`
- If `is_playing == false`: position frozen

### Line Index Algorithm (`get_index`)

- Input: `position_ms`, `previous_index`, `lines[]`
- Search forward from `previous_index` (95% case: next line)
- If position went backward (seek): search backward
- Return index where `lines[i].time_ms <= position_ms < lines[i+1].time_ms`

### Track Change Detection

- Compare `track_id` with previous
- If changed: fetch new lyrics via `lyrics:get_lyrics()`, reset `index = 1`

### Timing in CC:Tweaked

- `os.epoch("utc")` for millisecond timestamps
- `os.startTimer(seconds)` for scheduling — no busy-wait
- Event-driven: `os.pullEvent("timer")` and `os.pullEvent("terminate")`

## Renderer (`core/renderer.lua`)

### Screen Layout

```
┌─────────────────────────────────┐
│                                 │
│   previous line (dim)           │
│   previous line (dim)           │
│   ▶ CURRENT LINE (bright) ◀    │  <- vertical center
│   next line (dim)               │
│   next line (dim)               │
│                                 │
└─────────────────────────────────┘
```

Full screen is lyrics only. No header, no status bar. Current line at vertical center. Lines before/after fill remaining space equally.

### Dynamic Sizing

- `term.getSize()` on start and on `term_resize` event
- Visible lines = terminal height
- Long lines: word-wrap, wrapped parts count as one logical line for scrolling

### Color Scheme (configurable)

- Current line: `colors.white`
- Before/after lines: `colors.gray`
- Background: `colors.black`

### Horizontal Alignment

Center-aligned (fixed, karaoke style).

### Rendering Strategy

- Full redraw on line change or terminal resize
- `term.clear()` → `term.setCursorPos()` + `term.setTextColor()` + `term.write()`
- Single-frame draw, no flicker on CC:Tweaked

## Configuration

`config.lua` — Lua table in project root:

```lua
return {
    player = "spotify",
    lyrics = "lrclib",

    spotify = {
        client_id = "",
        client_secret = "",
        refresh_token = "",
    },

    update_interval = 2000,
    timer_interval = 200,

    style = {
        current_color = colors.white,
        before_color = colors.gray,
        after_color = colors.gray,
        bg_color = colors.black,
    },
}
```

### Config Loader (`core/config_loader.lua`)

- `dofile("config.lua")` returns table
- Validate required fields: `player`, `spotify.client_id`, `spotify.client_secret`, `spotify.refresh_token`
- Missing optional fields filled with defaults
- On error: clear message ("Missing spotify.refresh_token in config.lua")

## Error Handling

### Network Errors

- HTTP request failed (timeout, no network): display "No connection, retrying..." on screen, retry at next `update_interval`
- Don't overwrite current lyrics — if already loaded, keep displaying them

### Spotify-specific

- Token expired and refresh failed: "Token expired. Update refresh_token in config.lua", exit
- Nothing playing: "Waiting for playback..."
- Ad / podcast (`currently_playing_type != "track"`): "Unsupported content type"

### Lyrics

- Track not found in LRCLib: "No lyrics found for Artist - Title"
- Unsynced lyrics (only `plainLyrics`): display statically, full text, no scroll
- Empty LRC lines: render as empty line (verse pause)

### Terminal

- `term_resize`: full redraw with new dimensions
- Ctrl+T: `terminate` event, clean exit

No exponential backoff or complex retry strategies. Simply retry at standard interval.

## Installation

1. Download/clone to CC:Tweaked computer folder
2. Edit `config.lua` with Spotify credentials
3. Run `sptlrx`
