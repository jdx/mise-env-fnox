-- mise integration helpers for fnox-env.

local cmd = require("cmd")

local M = {}

function M.which_fnox(cwd)
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

return M

