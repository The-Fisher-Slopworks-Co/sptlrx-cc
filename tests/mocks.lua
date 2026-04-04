local mocks = {}

function mocks.setup()
    _G.colors = {
        white = 1, orange = 2, magenta = 4, lightBlue = 8,
        yellow = 16, lime = 32, pink = 64, gray = 128,
        lightGray = 256, cyan = 512, purple = 1024, blue = 2048,
        brown = 4096, green = 8192, red = 16384, black = 32768,
    }

    local term_state = {
        width = 51, height = 19, cursor_x = 1, cursor_y = 1,
        text_color = colors.white, bg_color = colors.black, lines = {},
    }

    _G.term = {
        getSize = function() return term_state.width, term_state.height end,
        setCursorPos = function(x, y) term_state.cursor_x = x; term_state.cursor_y = y end,
        setTextColor = function(c) term_state.text_color = c end,
        setBackgroundColor = function(c) term_state.bg_color = c end,
        write = function(text)
            term_state.lines[term_state.cursor_y] = text
        end,
        clear = function() term_state.lines = {} end,
        _state = term_state,
        _set_size = function(w, h) term_state.width = w; term_state.height = h end,
    }

    _G.textutils = {
        unserializeJSON = function(str)
            if type(str) == "table" then return str end
            if textutils._json_responses and textutils._json_responses[str] then
                return textutils._json_responses[str]
            end
            return nil
        end,
        urlEncode = function(str)
            return str:gsub("([^%w%-_.~])", function(c)
                return string.format("%%%02X", string.byte(c))
            end)
        end,
        _json_responses = {},
    }

    local http_responses = {}
    _G.http = {
        get = function(url, headers)
            local resp = http_responses[url]
            if not resp then return nil, "Not found" end
            return {
                readAll = function() return resp.body end,
                getResponseCode = function() return resp.code end,
                close = function() end,
            }
        end,
        post = function(url, body, headers)
            local resp = http_responses[url]
            if not resp then return nil, "Not found" end
            return {
                readAll = function() return resp.body end,
                getResponseCode = function() return resp.code end,
                close = function() end,
            }
        end,
        _set_response = function(url, code, body)
            http_responses[url] = { code = code, body = body }
        end,
        _clear = function() http_responses = {} end,
    }

    local fs_entries = {}
    _G.fs = {
        list = function(path) return fs_entries[path] or {} end,
        exists = function(path) return fs_entries[path] ~= nil end,
        isDir = function(path) return type(fs_entries[path]) == "table" end,
        _set = function(path, entries) fs_entries[path] = entries end,
        _clear = function() fs_entries = {} end,
    }

    local epoch_value = 1000000
    local timer_id = 0
    local event_queue = {}
    local original_os = _G.os or {}
    _G.os = setmetatable({
        epoch = function(t)
            if t == "utc" then return epoch_value end
            return original_os.time and original_os.time() or 0
        end,
        startTimer = function(seconds)
            timer_id = timer_id + 1
            return timer_id
        end,
        pullEvent = function(filter)
            if #event_queue > 0 then
                local evt = table.remove(event_queue, 1)
                if filter == nil or evt[1] == filter then
                    return unpack(evt)
                end
            end
            return "timer", timer_id
        end,
        _set_epoch = function(v) epoch_value = v end,
        _advance_epoch = function(ms) epoch_value = epoch_value + ms end,
        _push_event = function(evt) table.insert(event_queue, evt) end,
        _clear_events = function() event_queue = {} end,
    }, { __index = original_os })

    _G.shell = {
        getRunningProgram = function() return "sptlrx-cc/sptlrx.lua" end,
        _program = "sptlrx-cc/sptlrx.lua",
    }

    _G.printError = function(msg) print("ERROR: " .. tostring(msg)) end
end

function mocks.teardown()
    _G.colors = nil
    _G.term = nil
    _G.textutils = nil
    _G.http = nil
    _G.fs = nil
    _G.shell = nil
    _G.printError = nil
end

return mocks
