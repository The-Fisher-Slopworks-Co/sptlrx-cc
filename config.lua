-- sptlrx-ng configuration
-- Edit this file with your Spotify credentials and preferences.

return {
    -- Active providers
    player = "spotify",
    lyrics = "lrclib",

    -- Spotify credentials
    -- Get these from https://developer.spotify.com/dashboard
    -- You need to complete OAuth once in a browser to get refresh_token
    spotify = {
        client_id = "",
        client_secret = "",
        refresh_token = "",
    },

    -- Timing (milliseconds)
    update_interval = 2000,   -- how often to poll the player
    timer_interval = 200,     -- position interpolation frequency

    -- Display style (Advanced Computer colors)
    style = {
        current_color = colors.white,
        before_color = colors.gray,
        after_color = colors.gray,
        bg_color = colors.black,
    },
}
