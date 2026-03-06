local cmd = require("cmd")
local json = require("json")

--- Shell-escape a string using single quotes.
--- This is safe for sh -c since single quotes prevent all shell interpretation.
local function shell_quote(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

--- Build base command parts with fnox binary and optional config path.
local function fnox_cmd_parts(fnox_bin, config)
    local parts = {shell_quote(fnox_bin)}
    if config then
        table.insert(parts, "--config")
        table.insert(parts, shell_quote(config))
    end
    return parts
end

local function get_config_files(fnox_bin, config)
    local cmd_parts = fnox_cmd_parts(fnox_bin, config)
    table.insert(cmd_parts, "config-files")
    local config_files_cmd = table.concat(cmd_parts, " ")
    local ok, output = pcall(function()
        return cmd.exec(config_files_cmd)
    end)
    if not ok then
        print("[fnox] warning: `" .. config_files_cmd .. "` failed: " .. tostring(output))
        return {}
    end
    if not output or output == "" then
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
    local config = ctx.options.config

    local config_files = get_config_files(fnox_bin, config)
    if #config_files == 0 then
        return {cacheable = true, watch_files = {}, env = {}}
    end

    local command_parts = fnox_cmd_parts(fnox_bin, config)
    table.insert(command_parts, "export")
    table.insert(command_parts, "--format")
    table.insert(command_parts, "json")
    if profile then
        table.insert(command_parts, "--profile")
        table.insert(command_parts, shell_quote(profile))
    end
    local command = table.concat(command_parts, " ")

    local ok, output = pcall(function()
        return cmd.exec(command)
    end)

    if not ok then
        print("[fnox] warning: `" .. command .. "` failed: " .. tostring(output))
        return {cacheable = true, watch_files = config_files, env = {}}
    end

    local decode_ok, data = pcall(json.decode, output)
    if not decode_ok then
        print("[fnox] warning: failed to parse JSON from `" .. command .. "`: " .. tostring(data))
        return {cacheable = true, watch_files = config_files, env = {}}
    end

    local secrets = data.secrets or {}

    local env_vars = {}
    for key, value in pairs(secrets) do
        table.insert(env_vars, {key = key, value = value})
    end

    return {
        cacheable = true,
        watch_files = config_files,
        env = env_vars,
        redact = true
    }
end
