local lrc_parser = {}

function lrc_parser.parse(input)
    if not input or input == "" then
        return {}
    end

    local lines = {}

    for line in (input .. "\n"):gmatch("(.-)\n") do
        local mins, secs, frac, text = line:match("^%[(%d+):(%d+)%.(%d+)%](.*)")
        if mins then
            local time_ms = tonumber(mins) * 60000 + tonumber(secs) * 1000
            if #frac == 2 then
                time_ms = time_ms + tonumber(frac) * 10
            elseif #frac == 3 then
                time_ms = time_ms + tonumber(frac)
            end
            table.insert(lines, { time_ms = time_ms, text = text })
        end
    end

    return lines
end

function lrc_parser.is_synced(lines)
    return #lines > 1 and lines[2].time_ms ~= 0
end

return lrc_parser
