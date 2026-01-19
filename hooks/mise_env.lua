local cmd = require("cmd")
local json = require("json")
local file = require("file")

local function find_fnox_config()
    local cwd = os.getenv("PWD") or "."
    local path = cwd
    while path ~= "/" and path ~= "" do
        local config = path .. "/fnox.toml"
        if file.exists(config) then
            return config
        end
        path = path:match("(.+)/[^/]*$") or ""
    end
    return nil
end

function PLUGIN:MiseEnv(ctx)
    local fnox_bin = ctx.options.fnox_bin or "fnox"
    local profile = ctx.options.profile

    local config_path = find_fnox_config()
    if not config_path then
        return {cacheable = true, watch_files = {}, env = {}}
    end

    local command = fnox_bin .. " export --format json"
    if profile then
        command = command .. " --profile " .. profile
    end

    local ok, output = pcall(function()
        return cmd.exec(command)
    end)

    if not ok then
        return {cacheable = true, watch_files = {config_path}, env = {}}
    end

    local data = json.decode(output)
    local secrets = data.secrets or {}

    local env_vars = {}
    for key, value in pairs(secrets) do
        table.insert(env_vars, {key = key, value = value})
    end

    return {
        cacheable = true,
        watch_files = {config_path},
        env = env_vars
    }
end
