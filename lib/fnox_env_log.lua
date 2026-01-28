-- Lightweight debug logging helpers for fnox-env.

local M = {}

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

function M.enabled(ctx)
    return truthy(os.getenv("MISE_DEBUG")) or (ctx and ctx.options and truthy(ctx.options.debug))
end

function M.log(ctx, msg)
    if not M.enabled(ctx) then
        return
    end
    local line = "DEBUG [vfox:fnox-env] " .. tostring(msg) .. "\n"
    if io and io.stderr and io.stderr.write then
        io.stderr:write(line)
    else
        print(line)
    end
end

return M

