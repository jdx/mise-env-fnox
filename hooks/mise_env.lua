local cmd = require("cmd")
local json = require("json")
local file = require("file")

-- Minimal debug logging (stderr). Enable with MISE_DEBUG=1 or _.fnox-env={debug=true}
local function truthy(v)
    if v == nil then
        return false
    end
    if type(v) == "boolean" then
        return v
    end
    v = tostring(v):lower()
    return v == "1" or v == "true" or v == "yes" or v == "on"
end

local function debug_enabled(ctx)
    return truthy(os.getenv("MISE_DEBUG")) or (ctx and ctx.options and truthy(ctx.options.debug))
end

local function debug_log(ctx, msg)
    if not debug_enabled(ctx) then
        return
    end
    -- Match mise/vfox debug prefix style
    local line = "DEBUG [vfox:fnox-env] " .. tostring(msg) .. "\n"
    if io and io.stderr and io.stderr.write then
        io.stderr:write(line)
    else
        print(line)
    end
end

local function dirname(p)
    if not p or p == "" then
        return "."
    end
    p = p:gsub("/+$", "")
    local d = p:match("(.+)/[^/]*$") or ""
    if d == "" then
        return "/"
    end
    return d
end

local function shell_escape(s)
    -- POSIX-safe single-quote escaping: ' -> '"'"'
    if s == nil then
        return "''"
    end
    s = tostring(s)
    return "'" .. s:gsub("'", [['"'"']]) .. "'"
end

local function mise_which_fnox(ctx, cwd)
    local ok, out = pcall(function()
        return cmd.exec("mise which fnox", {
            cwd = cwd,
            env = {
                -- Avoid recursive env/plugin evaluation
                MISE_NO_ENV = "1",
                MISE_NO_HOOKS = "1",
            }
        })
    end)
    if not ok then
        return nil
    end
    out = tostring(out or ""):gsub("%s+$", "")
    if out == "" then
        return nil
    end
    return out
end

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

    local config_dir = dirname(config_path)
    debug_log(ctx, "fnox_config=" .. tostring(config_path))

    -- If fnox isn't global but is managed by mise, resolve it via `mise which fnox`.
    if ctx.options.fnox_bin == nil then
        local resolved = mise_which_fnox(ctx, config_dir)
        if resolved then
            fnox_bin = resolved
            debug_log(ctx, "fnox_bin=" .. tostring(resolved))
        else
            debug_log(ctx, "fnox_bin=fnox (PATH)")
        end
    end

    local command = shell_escape(fnox_bin) .. " export --format json"
    if profile then
        command = command .. " --profile " .. shell_escape(profile)
    end
    debug_log(ctx, "command=" .. command)

    local ok, output = pcall(function()
        return cmd.exec(command, {cwd = config_dir})
    end)

    if not ok then
        debug_log(ctx, "fnox exec failed: " .. tostring(output))
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
