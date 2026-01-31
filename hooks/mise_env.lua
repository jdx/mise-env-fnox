local cmd = require("cmd")
local json = require("json")

local function get_config_files(fnox_bin)
    local ok, output = pcall(function()
        return cmd.exec(fnox_bin .. " config-files")
    end)
    if not ok or not output or output == "" then
        return {}
    end
    local files = {}
    for line in output:gmatch("[^\n]+") do
        table.insert(files, line)
    end
    return files
end

function PLUGIN:MiseEnv(ctx)
    local fnox_bin = ctx.options.fnox_bin or "fnox"
    local profile = ctx.options.profile

    local config_files = get_config_files(fnox_bin)
    if #config_files == 0 then
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
        return {cacheable = true, watch_files = config_files, env = {}}
    end

    local data = json.decode(output)
    local secrets = data.secrets or {}

    local env_vars = {}
    for key, value in pairs(secrets) do
        table.insert(env_vars, {key = key, value = value})
    end

    return {
        cacheable = true,
        watch_files = config_files,
        env = env_vars
    }
end
