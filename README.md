# sptlrx-cc

> This project is 100% AI-generated. Code, tests, docs, all of it. If that bothers you, feel free to move along.

Karaoke-style lyrics in your Minecraft terminal. Talks to Spotify to figure out what's playing, grabs lyrics from LRCLib, and scrolls them in time with the music.

Runs on CC:Tweaked Advanced Computers. Works fine on monitors too.

## What it looks like

```
        I've been searching for a trail to follow
        Take me back to the night we met

      > I don't know what I'm supposed to do <

        Haunted by the ghost of you
        Take me back to the night we met
```

The bright line in the middle is what's playing right now. Everything else is dimmed. It scrolls on its own.

## Getting started

### 1. Download

Drop the whole folder onto your CC:Tweaked computer:

```
/sptlrx-cc/
├── sptlrx.lua
├── config.lua
├── core/
├── providers/
└── lib/
```

### 2. Set up Spotify credentials

You'll need a Client ID, Client Secret, and a Refresh Token.

**Client ID and Secret:**

1. Create an app on the Spotify Developer Dashboard
2. Set redirect URI to `http://localhost:8888/callback`
3. Copy Client ID and Client Secret from app settings

**Refresh Token:**

This is a one-time thing. On your actual computer (not Minecraft), do an OAuth flow. You can use something like spotify-token-generator or just follow Spotify's Authorization Code Flow docs. The scopes you need are `user-read-currently-playing` and `user-read-playback-state`.

### 3. Edit config.lua

Paste your credentials in:

```lua
return {
    player = "spotify",
    lyrics = "lrclib",

    spotify = {
        client_id = "your_client_id_here",
        client_secret = "your_client_secret_here",
        refresh_token = "your_refresh_token_here",
    },
}
```

### 4. Run it

```
> sptlrx-cc/sptlrx
```

Play something on Spotify. Lyrics show up in a couple seconds. Ctrl+T to quit.

## Configuration

Everything is in `config.lua`:

```lua
return {
    player = "spotify",
    lyrics = "lrclib",

    spotify = {
        client_id = "",
        client_secret = "",
        refresh_token = "",
    },

    -- How often to check Spotify for track changes (ms)
    update_interval = 2000,

    -- How often to update the display between polls (ms)
    timer_interval = 200,

    -- Colors (any CC:Tweaked color constant works)
    style = {
        current_color = colors.white,
        before_color = colors.gray,
        after_color = colors.gray,
        bg_color = colors.black,
    },
}
```

## Custom providers

The player and lyrics sources are plugins. If you want to pull lyrics from somewhere else or use a different music player, you can write your own provider.

### Player provider

Make a file in `providers/player/`:

```lua
return {
    name = "my_player",
    setup = function(config)
        -- set up your connection here
        return instance, nil
    end,
    get_state = function(self)
        return {
            track_id = "unique_id",
            artist = "Artist Name",
            title = "Song Title",
            position_ms = 42000,
            is_playing = true,
        }, nil
    end,
}
```

Set `player = "my_player"` in config.

### Lyrics provider

Make a file in `providers/lyrics/`:

```lua
return {
    name = "my_source",
    setup = function(config)
        return instance, nil
    end,
    get_lyrics = function(self, artist, title)
        return {
            { time_ms = 0, text = "First line" },
            { time_ms = 5000, text = "Second line" },
        }, nil
    end,
}
```

Set `lyrics = "my_source"` in config.

## Project structure

```
sptlrx-cc/
├── sptlrx.lua              -- entry point
├── config.lua               -- your settings
├── core/
│   ├── config_loader.lua    -- loads and validates config
│   ├── sync.lua             -- timing and lyric sync logic
│   ├── renderer.lua         -- terminal drawing
│   └── plugin_loader.lua    -- finds provider plugins
├── providers/
│   ├── player/
│   │   └── spotify.lua      -- Spotify Web API
│   └── lyrics/
│       └── lrclib.lua       -- LRCLib.net
└── lib/
    └── lrc_parser.lua       -- LRC timestamp parser
```

## How it works

Every 2 seconds it asks Spotify what's playing and where in the track you are. Between those checks, it does its own timekeeping so the lyrics don't just jump every 2 seconds. New track? It goes to LRCLib for lyrics. The screen only redraws when the line changes, not on every tick.

Your refresh token takes care of re-auth, so you're not pasting a new token every hour.

## Troubleshooting

**"Token expired. Update refresh_token in config.lua"** -- Refresh token went bad. Get a new one through the OAuth flow.

**"No connection, retrying..."** -- Can't reach the internet. Make sure HTTP is on in the server config (`http.enabled = true` in `computercraft-server.toml`).

**"No lyrics found"** -- LRCLib just doesn't have this track. More common with obscure or brand-new music.

**Lyrics are out of sync** -- Lower `timer_interval` to 100 in config. Spotify's position reporting isn't perfect.

## Credits

Inspired by [sptlrx](https://github.com/raitonoberu/sptlrx) by raitonoberu.

## License

AGPL-3.0
