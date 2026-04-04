local renderer = {}

function renderer.word_wrap(text, width)
    if text == "" then return { "" } end
    if #text <= width then return { text } end

    local lines = {}
    local remaining = text

    while #remaining > 0 do
        if #remaining <= width then
            table.insert(lines, remaining)
            break
        end

        local break_at = nil
        for i = width, 1, -1 do
            if remaining:sub(i, i) == " " then
                break_at = i
                break
            end
        end

        if break_at then
            table.insert(lines, remaining:sub(1, break_at - 1))
            remaining = remaining:sub(break_at + 1)
        else
            table.insert(lines, remaining:sub(1, width))
            remaining = remaining:sub(width + 1)
        end
    end

    return lines
end

function renderer.center_text(text, width)
    if #text >= width then return text end
    local pad = width - #text
    local left = math.floor(pad / 2)
    local right = pad - left
    return string.rep(" ", left) .. text .. string.rep(" ", right)
end

function renderer.compute_layout(lines, current_index, screen_width, screen_height)
    local display = {}
    for i, line in ipairs(lines) do
        local wrapped = renderer.word_wrap(line.text, screen_width)
        for _, wline in ipairs(wrapped) do
            table.insert(display, {
                text = wline,
                is_current = (i == current_index),
                source_index = i,
            })
        end
    end

    local current_display_start = 1
    for i, d in ipairs(display) do
        if d.is_current then
            current_display_start = i
            break
        end
    end

    local center_row = math.ceil(screen_height / 2)
    local start_display = current_display_start - (center_row - 1)
    local visible = {}

    for row = 1, screen_height do
        local di = start_display + row - 1
        if di >= 1 and di <= #display then
            visible[row] = display[di]
        else
            visible[row] = { text = "", is_current = false, source_index = 0 }
        end
    end

    return {
        visible = visible,
        center_row = center_row,
    }
end

function renderer.draw(lines, current_index, style)
    local width, height = term.getSize()
    term.setBackgroundColor(style.bg_color)
    term.clear()

    local layout = renderer.compute_layout(lines, current_index, width, height)

    for row = 1, height do
        local entry = layout.visible[row]
        if entry then
            if entry.is_current then
                term.setTextColor(style.current_color)
            elseif entry.source_index > 0 and entry.source_index < current_index then
                term.setTextColor(style.before_color)
            else
                term.setTextColor(style.after_color)
            end

            local centered = renderer.center_text(entry.text, width)
            term.setCursorPos(1, row)
            term.write(centered)
        end
    end
end

function renderer.show_message(msg)
    local width, height = term.getSize()
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setTextColor(colors.yellow)
    local centered = renderer.center_text(msg, width)
    term.setCursorPos(1, math.ceil(height / 2))
    term.write(centered)
end

function renderer.init()
    term.setBackgroundColor(colors.black)
    term.clear()
end

return renderer
