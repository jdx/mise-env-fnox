local plugin_dir = assert(arg[1], "plugin directory argument is required")

local calls = {}
local responses = {}

package.preload.cmd = function()
    return {
        exec = function(command)
            table.insert(calls, command)
            local response = assert(responses[command], "unexpected command: " .. command)
            if response.ok then
                return response.output
            end
            error(response.output)
        end,
    }
end

package.preload.json = function()
    return {
        decode = function()
            return { secrets = { TOKEN = "secret" } }
        end,
    }
end

PLUGIN = {}
assert(loadfile(plugin_dir .. "/hooks/mise_env.lua"))()
RUNTIME = { osType = "linux" }

local function reset(next_responses)
    calls = {}
    responses = next_responses
end

reset({
    ["'fnox' config-files"] = {
        ok = false,
        output = "runtime error: Command failed with status exit status: 127: sh: fnox: command not found",
    },
    ["mise which fnox"] = { ok = true, output = "/mise/installs/fnox 1.0.0/bin/fnox\n" },
    ["'/mise/installs/fnox 1.0.0/bin/fnox' config-files"] = { ok = true, output = "/project/fnox.toml\n" },
    ["'/mise/installs/fnox 1.0.0/bin/fnox' export --format json"] = { ok = true, output = "{}" },
})
local result = PLUGIN:MiseEnv({ options = {} })
assert(calls[2] == "mise which fnox", "missing fnox should resolve through mise")
assert(calls[4] == "'/mise/installs/fnox 1.0.0/bin/fnox' export --format json", "resolved binary should be quoted for export")
assert(result.env[1].key == "TOKEN", "resolved fnox output should be used")

reset({
    ["'fnox' config-files"] = { ok = false, output = "authentication failed" },
})
result = PLUGIN:MiseEnv({ options = {} })
assert(#calls == 1 and calls[1] == "'fnox' config-files", "authentication failures must not be retried as missing binaries")
assert(#result.env == 0, "failed config discovery should retain the empty environment result")

reset({
    ["'/custom/fnox' config-files"] = { ok = true, output = "/project/fnox.toml\n" },
    ["'/custom/fnox' export --format json"] = { ok = true, output = "{}" },
})
result = PLUGIN:MiseEnv({ options = { fnox_bin = "/custom/fnox" } })
assert(#calls == 2 and calls[1] == "'/custom/fnox' config-files", "explicit fnox_bin must take precedence")
assert(result.env[1].key == "TOKEN", "explicit fnox_bin should export")

RUNTIME = { osType = "windows" }
reset({
    ['"fnox" config-files'] = {
        ok = false,
        output = "exit status: 1: 'fnox' is not recognized as an internal or external command",
    },
    ["mise which fnox"] = { ok = true, output = "C:\\mise installs\\fnox\\fnox.exe\r\n" },
    ['"C:\\mise installs\\fnox\\fnox.exe" config-files'] = { ok = true, output = "C:\\project\\fnox.toml\r\n" },
    ['"C:\\mise installs\\fnox\\fnox.exe" export --format json'] = { ok = true, output = "{}" },
})
result = PLUGIN:MiseEnv({ options = {} })
assert(calls[2] == "mise which fnox", "Windows command-not-found should resolve through mise")
assert(
    calls[4] == '"C:\\mise installs\\fnox\\fnox.exe" export --format json',
    "Windows resolved executable should be quoted for export"
)
assert(result.env[1].key == "TOKEN", "Windows resolved fnox output should be used")
