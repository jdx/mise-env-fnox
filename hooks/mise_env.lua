local cmd = require("cmd")
local json = require("json")

local function strip_traceback(msg)
    if not msg then return "" end
    return (tostring(msg):gsub("\r?\n%s*stack traceback:.*$", ""))
end

local function shquote(s)
    return "'" .. tostring(s):gsub("'", [['\'']]) .. "'"
end

-- Detect a `timeout` binary once per activation. Returns the binary name
-- or nil if none is on PATH.
local _timeout_bin_cached = nil
local _timeout_bin_done = false
local function timeout_bin()
    if _timeout_bin_done then return _timeout_bin_cached end
    _timeout_bin_done = true
    for _, b in ipairs({"timeout", "gtimeout"}) do
        local f = io.popen("command -v " .. b .. " 2>/dev/null")
        if f then
            local out = f:read("*a") or ""
            f:close()
            if out:match("%S") then
                _timeout_bin_cached = b
                return b
            end
        end
    end
    return nil
end

-- Build a shell command, wrapped in `timeout` if available so a stalled
-- network call can't hang mise activation indefinitely.
local function build_command(fnox_bin, args, timeout_secs)
    local body = shquote(fnox_bin) .. " " .. args
    local tbin = timeout_bin()
    if tbin and timeout_secs then
        body = tbin .. " --preserve-status " .. timeout_secs .. " " .. body
    end
    return body
end

local function exec(command)
    local ok, output = pcall(function()
        return cmd.exec(command)
    end)
    return ok, output
end

local function run_json(command)
    local ok, output = exec(command)
    if not ok then
        error("[fnox] `" .. command .. "` failed: " .. tostring(output))
    end
    if not output or output == "" then
        return {}
    end
    local decode_ok, data = pcall(json.decode, output)
    if not decode_ok then
        error("[fnox] failed to parse JSON from `" .. command .. "`: " .. tostring(data))
    end
    return data
end

-- Run a fnox subcommand that emits JSON. Returns (data, err) where err is
-- non-nil only on failure (the warning has already been printed in that
-- case). Never throws.
local function fetch_json(label, fnox_bin, args, timeout_secs)
    local command = build_command(fnox_bin, args, timeout_secs)
    local ok, data = pcall(run_json, command)
    if ok then return data, nil end
    local msg = strip_traceback(tostring(data))
    print("[fnox] warning: " .. label .. " failed, continuing: " .. msg)
    return nil, msg
end

-- Merge a {key=value} map into env_vars, replacing any prior entry with
-- the same key. Warns on collision when source_label is set.
local function merge_creds(env_vars, seen, creds, source_label)
    for key, value in pairs(creds) do
        if seen[key] and source_label then
            print("[fnox] warning: " .. source_label
                .. " credential `" .. key .. "` overrides earlier value")
        end
        local replaced = false
        for i, entry in ipairs(env_vars) do
            if entry.key == key then
                env_vars[i] = {key = key, value = value}
                replaced = true
                break
            end
        end
        if not replaced then
            table.insert(env_vars, {key = key, value = value})
        end
        seen[key] = true
    end
end

local function get_config_files(fnox_bin)
    local command = build_command(fnox_bin, "config-files", 5)
    local ok, output = exec(command)
    if not ok then
        print("[fnox] warning: `" .. command .. "` failed: " .. strip_traceback(output))
        return nil
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

-- Strip lease metadata keys and keep only string values, then return a
-- plain {key=value} map suitable for merge_creds.
local function lease_creds(ldata)
    local out = {}
    for key, value in pairs(ldata) do
        if key ~= "backend" and key ~= "lease_id" and type(value) == "string" then
            out[key] = value
        end
    end
    return out
end

function PLUGIN:MiseEnv(ctx)
    local fnox_bin = ctx.options.fnox_bin or "fnox"
    local profile = ctx.options.profile
    -- opt-in: `leases = true` to run `fnox lease create --all` on activation.
    -- Off by default so users without [leases.*] backends don't see warnings.
    local leases_enabled = ctx.options.leases == true or ctx.options.leases == "true"
    local export_timeout = tonumber(ctx.options.export_timeout) or 15
    local lease_timeout = tonumber(ctx.options.lease_timeout) or 30

    local config_files = get_config_files(fnox_bin)
    if not config_files then
        -- config-files failed; return a non-cacheable empty result so mise
        -- proceeds and retries on the next activation
        return {cacheable = false, watch_files = {}, env = {}}
    end
    if #config_files == 0 then
        return {cacheable = true, watch_files = {}, env = {}}
    end

    local profile_args = ""
    if profile then
        profile_args = " --profile " .. shquote(profile)
    end

    local env_vars = {}
    local seen = {}
    local had_failure = false

    -- export secrets
    local edata, eerr = fetch_json("export", fnox_bin,
        "export --format json" .. profile_args, export_timeout)
    if edata then merge_creds(env_vars, seen, edata.secrets or {}, nil) end
    if eerr then had_failure = true end

    -- create leases (opt-in via `leases = true` plugin option)
    if leases_enabled then
        local ldata, lerr = fetch_json("lease creation", fnox_bin,
            "lease create --all --format json" .. profile_args, lease_timeout)
        if ldata then merge_creds(env_vars, seen, lease_creds(ldata), "lease") end
        if lerr then had_failure = true end
    end

    return {
        -- don't cache partial results so mise retries after a transient failure
        cacheable = not had_failure,
        watch_files = config_files,
        env = env_vars,
        redact = true
    }
end
