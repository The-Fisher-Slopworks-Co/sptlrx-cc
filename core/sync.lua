local lrc_parser = require("lib.lrc_parser")

local sync = {}

function sync.get_index(position_ms, previous_index, lines)
    if #lines == 0 then return 1 end
    if #lines == 1 then return 1 end

    -- Search forward from previous_index
    if position_ms >= lines[previous_index].time_ms then
        for i = previous_index, #lines do
            local next_time = lines[i + 1] and lines[i + 1].time_ms or math.huge
            if position_ms >= lines[i].time_ms and position_ms < next_time then
                return i
            end
        end
        return #lines
    end

    -- Search backward (seek happened)
    for i = previous_index - 1, 1, -1 do
        local next_time = lines[i + 1] and lines[i + 1].time_ms or math.huge
        if position_ms >= lines[i].time_ms and position_ms < next_time then
            return i
        end
    end

    return 1
end

function sync.interpolate_position(state, last_poll_time)
    if not state.is_playing then
        return state.position_ms
    end
    local elapsed = os.epoch("utc") - last_poll_time
    return state.position_ms + elapsed
end

function sync.run(player, lyrics_provider, renderer, config)
    local current_state = nil
    local current_lines = nil
    local current_index = 1
    local current_track_id = nil
    local last_poll_time = 0
    local is_synced = false

    local update_timer = os.startTimer(0)
    local interp_timer = nil

    local update_interval = (config.update_interval or 2000) / 1000
    local timer_interval = (config.timer_interval or 200) / 1000

    while true do
        local event, param = os.pullEvent()

        if event == "terminate" then
            break
        elseif event == "term_resize" then
            if current_lines and current_index then
                renderer.draw(current_lines, current_index, config.style)
            end
        elseif event == "timer" then
            if param == update_timer then
                -- Poll player
                local state, err = player:get_state()
                if state then
                    current_state = state
                    last_poll_time = os.epoch("utc")

                    -- Track changed?
                    if state.track_id ~= current_track_id then
                        current_track_id = state.track_id
                        local lines, lerr = lyrics_provider:get_lyrics(state.artist, state.title)
                        if lines and #lines > 0 then
                            current_lines = lines
                            current_index = 1
                            is_synced = lrc_parser.is_synced(lines)
                            renderer.draw(current_lines, current_index, config.style)
                        else
                            current_lines = nil
                            renderer.show_message(lerr or ("No lyrics found for " .. state.artist .. " - " .. state.title))
                        end
                    end

                elseif err then
                    renderer.show_message(err)
                    if err:find("Token expired") then
                        break
                    end
                else
                    -- nil state, nil error (nothing playing / 204)
                    if current_lines == nil then
                        renderer.show_message("Waiting for playback...")
                    end
                end

                update_timer = os.startTimer(update_interval)
                if current_state and current_state.is_playing and current_lines and is_synced then
                    interp_timer = os.startTimer(timer_interval)
                end

            elseif param == interp_timer then
                if current_state and current_lines and current_state.is_playing and is_synced then
                    local pos = sync.interpolate_position(current_state, last_poll_time)
                    local new_index = sync.get_index(pos, current_index, current_lines)
                    if new_index ~= current_index then
                        current_index = new_index
                        renderer.draw(current_lines, current_index, config.style)
                    end
                    interp_timer = os.startTimer(timer_interval)
                end
            end
        end
    end
end

return sync
