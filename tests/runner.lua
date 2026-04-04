local runner = {}

local results = { passed = 0, failed = 0, errors = {} }
local current_describe = ""

function runner.describe(name, fn)
    current_describe = name
    fn()
    current_describe = ""
end

function runner.it(name, fn)
    local full_name = current_describe .. " > " .. name
    local ok, err = pcall(fn)
    if ok then
        results.passed = results.passed + 1
        print("  PASS: " .. full_name)
    else
        results.failed = results.failed + 1
        table.insert(results.errors, { name = full_name, err = err })
        print("  FAIL: " .. full_name)
        print("        " .. tostring(err))
    end
end

function runner.expect(value)
    return {
        to_equal = function(expected)
            if value ~= expected then
                error("Expected " .. tostring(expected) .. ", got " .. tostring(value), 2)
            end
        end,
        to_be_nil = function()
            if value ~= nil then
                error("Expected nil, got " .. tostring(value), 2)
            end
        end,
        to_be_truthy = function()
            if not value then
                error("Expected truthy, got " .. tostring(value), 2)
            end
        end,
        to_be_falsy = function()
            if value then
                error("Expected falsy, got " .. tostring(value), 2)
            end
        end,
        to_deep_equal = function(expected)
            local function deep_eq(a, b)
                if type(a) ~= type(b) then return false end
                if type(a) ~= "table" then return a == b end
                for k, v in pairs(a) do
                    if not deep_eq(v, b[k]) then return false end
                end
                for k, v in pairs(b) do
                    if not deep_eq(v, a[k]) then return false end
                end
                return true
            end
            if not deep_eq(value, expected) then
                error("Deep equality failed", 2)
            end
        end,
        to_contain = function(substring)
            if type(value) ~= "string" or not value:find(substring, 1, true) then
                error("Expected '" .. tostring(value) .. "' to contain '" .. tostring(substring) .. "'", 2)
            end
        end,
        to_throw = function()
            if type(value) ~= "function" then
                error("to_throw expects a function", 2)
            end
            local ok, _ = pcall(value)
            if ok then
                error("Expected function to throw, but it did not", 2)
            end
        end,
    }
end

function runner.summary()
    print("")
    print("Results: " .. results.passed .. " passed, " .. results.failed .. " failed")
    if #results.errors > 0 then
        print("")
        print("Failures:")
        for _, e in ipairs(results.errors) do
            print("  " .. e.name)
            print("    " .. e.err)
        end
    end
    return results.failed == 0
end

function runner.reset()
    results = { passed = 0, failed = 0, errors = {} }
end

return runner
