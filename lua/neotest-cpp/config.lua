local M = {}

--- @class neotest-cpp.Config.Executable.Debug
--- @field dap_template fun(executable: string): table<string, any>? Template for dap config

--- @class neotest-cpp.Config.Executable
--- @field patterns string[] Glob patterns to match test executables.
--- @field resolve fun(file: string): string? Directly resolve executable for a test file
--- @field cwd fun(executable: string): string? The working directory for the executable
--- @field env fun(executable: string): table<string, string>? Environment variables for the executable
--- @field debug neotest-cpp.Config.Executable.Debug

--- @class neotest-cpp.Config
--- @field executables neotest-cpp.Config.Executable
--- @field log_level vim.log.levels
M.defaults = {
  executables = {
    -- Glob patterns for discovery of executables
    patterns = { "{build,Build,BUILD,out,Out,OUT}/**/*{test,Test,TEST}*" },

    --- Directly resolve the executable for a test file.
    --- This can significantly speed up executable discovery in large
    --- monorepos. This can be used instead of or in addition to
    --- `executables.patterns`.
    resolve = function(_)
      return nil
    end,

    cwd = function(_)
      return nil
    end,

    env = function(_)
      return nil
    end,

    debug = {
      dap_template = function(executable)
        local adapters = vim.tbl_keys(require("dap").adapters)

        -- Check whether the user has configured any of the following adapters.
        local mac_adapters = { "lldb", "codelldb", "cppdbg" }
        local linux_adapters = vim.list_extend({ "gdb" }, mac_adapters)
        local windows_adapters = { "cppdbg" }

        local get_adapter = function(platform_adapters)
          return vim.iter(platform_adapters):find(function(platform_adapter)
            return vim.iter(adapters):find(platform_adapter)
          end)
        end

        local adapter = nil
        local sys = vim.uv.os_uname().sysname
        if sys == "Darwin" then
          adapter = get_adapter(mac_adapters)
        elseif sys == "Linux" then
          adapter = get_adapter(linux_adapters)
        elseif sys == "Windows_NT" then
          adapter = get_adapter(windows_adapters)
        end

        if adapter then
          return {
            name = "Debug with neotest-cpp",
            type = adapter,
            request = "launch",
            program = executable,
            args = "${arguments}",
            cwd = "${cwd}",
            env = "${env}",
          }
        end
        return nil
      end,
    },
  },
  log_level = vim.log.levels.INFO,
}

local config = {}

--- Setup neotest-cpp configuration
--- @param opts neotest-cpp.Config? Configuration options
function M.setup(opts)
  --- @type neotest-cpp.Config
  config = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

--- @return neotest-cpp.Config
function M.get()
  return config
end

return M
