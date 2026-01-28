local cmd = require("cmd")
local json = require("json")
local file = require("file")

local log = require("fnox_env_log")
local fs = require("fnox_env_fs")
local mise = require("fnox_env_mise")

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

    -- Debug: show which quoting branch is active
    log.log(ctx, "platform=" .. (fs.is_windows() and "windows" or "posix"))

    local config_path = find_fnox_config()
    if not config_path then
        return {cacheable = true, watch_files = {}, env = {}}
    end

    local config_dir = fs.dirname(config_path)
    log.log(ctx, "fnox_config=" .. tostring(config_path))

    -- If fnox isn't global but is managed by mise, resolve it via `mise which fnox`.
    if ctx.options.fnox_bin == nil then
        local resolved = mise.which_fnox(config_dir)
        if resolved then
            fnox_bin = resolved
            log.log(ctx, "fnox_bin=" .. tostring(resolved))
        else
            log.log(ctx, "fnox_bin=fnox (PATH)")
        end
    end

    local command = fs.build_fnox_export_command(fnox_bin, profile)
    log.log(ctx, "command=" .. command)

    local ok, output = pcall(function()
        return cmd.exec(command, {cwd = config_dir})
    end)

    if not ok then
        log.log(ctx, "fnox exec failed: " .. tostring(output))
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
