-- Filesystem/path helpers for fnox-env.

local file = require("file")

local M = {}

function M.dirname(p)
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

function M.is_windows()
    return package and package.config and package.config:sub(1, 1) == "\\"
end

local function posix_shell_escape(s)
    -- POSIX-safe single-quote escaping: ' -> '"'"'
    if s == nil then
        return "''"
    end
    s = tostring(s)
    return "'" .. s:gsub("'", [['"'"']]) .. "'"
end

local function win_quote_arg(s)
    -- cmd.exe quoting for a single argument
    s = tostring(s)
    return '"' .. s:gsub('"', '""') .. '"'
end

function M.build_fnox_export_command(fnox_bin, profile)
    -- On Windows, do NOT quote the executable path because cmd.exec/cmd.exe can treat
    -- quote characters literally after internal escaping. Quote only arguments.
    if M.is_windows() then
        local cmdline = tostring(fnox_bin) .. " export --format json"
        if profile then
            cmdline = cmdline .. " --profile " .. win_quote_arg(profile)
        end
        return cmdline
    end

    local cmdline = posix_shell_escape(fnox_bin) .. " export --format json"
    if profile then
        cmdline = cmdline .. " --profile " .. posix_shell_escape(profile)
    end
    return cmdline
end

return M

