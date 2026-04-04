local plugin_loader = {}

local REQUIRED_FIELDS = {
    player = { "name", "setup", "get_state" },
    lyrics = { "name", "setup", "get_lyrics" },
}

function plugin_loader.scan(dir_path, provider_type)
    local providers = {}
    local required = REQUIRED_FIELDS[provider_type]

    if not required then
        return providers
    end

    local files = fs.list(dir_path)

    -- Derive the base directory from the running program path
    local program = shell.getRunningProgram()
    local base_dir = program:match("^(.+)/") or ""

    for _, filename in ipairs(files) do
        local module_name = filename:match("^(.+)%.lua$")
        if module_name then
            -- Strip the base directory prefix to get a proper require path
            local rel_path = dir_path
            if base_dir ~= "" and dir_path:sub(1, #base_dir + 1) == base_dir .. "/" then
                rel_path = dir_path:sub(#base_dir + 2)
            end
            local require_path = rel_path:gsub("/", ".") .. "." .. module_name
            local ok, provider = pcall(require, require_path)

            if ok and type(provider) == "table" then
                local valid = true
                for _, field in ipairs(required) do
                    if provider[field] == nil then
                        valid = false
                        break
                    end
                end

                if valid then
                    table.insert(providers, provider)
                end
            end
        end
    end

    return providers
end

function plugin_loader.find(providers, name)
    for _, provider in ipairs(providers) do
        if provider.name == name then
            return provider
        end
    end
    return nil
end

return plugin_loader
