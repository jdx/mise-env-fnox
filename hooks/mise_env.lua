local cmd = require("cmd")
local json = require("json")

local function command_not_found(err)
    local message = tostring(err):lower()
    return message:find("command not found", 1, true) ~= nil or message:find("exit status: 127", 1, true) ~= nil
end

local function fnox_command(fnox_bin, args)
    return "'" .. fnox_bin:gsub("'", "'\\''") .. "' " .. args
end

local function get_config_files(fnox_bin)
    local ok, output = pcall(function()
        return cmd.exec(fnox_command(fnox_bin, "config-files"))
    end)

    -- During a first mise install the selected fnox tool may not have reached PATH
    -- when this hook runs. Only resolve through mise for that precise failure: other
    -- fnox failures (including authentication failures) retain their normal warning.
    if not ok and fnox_bin == "fnox" and command_not_found(output) then
        local initial_error = output
        local resolved_ok, resolved_bin = pcall(function()
            return cmd.exec("mise which fnox")
        end)
        if resolved_ok and resolved_bin and resolved_bin ~= "" then
            fnox_bin = resolved_bin:match("^%s*(.-)%s*$")
            ok, output = pcall(function()
                return cmd.exec(fnox_command(fnox_bin, "config-files"))
            end)
        else
            output = initial_error
        end
    end

    if not ok then
        print("[fnox] warning: `" .. fnox_bin .. " config-files` failed: " .. tostring(output))
        return {}, fnox_bin
    end
    if not output or output == "" then
        return {}, fnox_bin
    end
    local files = {}
    for line in output:gmatch("[^\n]+") do
        table.insert(files, line)
    end
    return files, fnox_bin
end

function PLUGIN:MiseEnv(ctx)
    local fnox_bin = ctx.options.fnox_bin or "fnox"
    local profile = ctx.options.profile

    local config_files
    config_files, fnox_bin = get_config_files(fnox_bin)
    if #config_files == 0 then
        return {cacheable = true, watch_files = {}, env = {}}
    end

    local command = fnox_command(fnox_bin, "export --format json")
    if profile then
        command = command .. " --profile " .. profile
    end

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
