# neotest-cpp

Neotest-cpp is a Neovim plugin that allows you to run and debug [GoogleTest](https://github.com/google/googletest) tests directly within Neovim.
It is implemented as a [neotest](https://github.com/nvim-neotest/neotest) adapter and provides:

* A smooth, out-of-the-box experience for most users
* Scalability for large monorepos with hundreds or thousands of test executables
* Fine-grained configuration options on a per-executable basis


## Features

* Supports all [neotest usage](https://github.com/nvim-neotest/neotest#usage) 
* Supports `TEST`, `TEST_F` and `TEST_P` GoogleTest macros (discovered via treesitter)
* DAP support for all adapters (`lldb-dap`, `codelldb`, `gdb`, etc..)
* Automatic discovery of the executable for a test file

## Requirements

* Neovim v0.11.0 or greater
* GoogleTest v1.12.0 or greater

## Installation

### lazy.nvim

```lua
return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      { 
        "ryanpholt/neotest-cpp",
        opts = {}
      },
    },
    config = function()
      require("neotest").setup({
        adapters = {
          require("neotest-cpp")
        },
      })
    end,
  },
}
```

For debugging, you will also need [nvim-dap](https://github.com/mfussenegger/nvim-dap).

## Configuration

The adapter comes with the following defaults:

```lua
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
--- @field is_test_file fun(file_path: string): boolean
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
  is_test_file = function(file_path)
    return vim.endswith(file_path, ".cpp")
      or vim.endswith(file_path, ".cxx")
      or vim.endswith(file_path, ".cc")
      or vim.endswith(file_path, ".c++")
  end,
  log_level = vim.log.levels.INFO,
}
```

The most important configuration is the `executables` field which tells the adapter how to find and run your test
executables.

For debugging, we try to find a C++ adapter that you have already configured (see 
`defaults.executables.debug.dap_template` above). If that doesn't work for you, then you can configure it to return
your own `dap_template` of the form:

```lua
{
  name = "Debug with neotest-cpp",
  type = adapter,
  request = "launch",
  program = executable,
  args = "${arguments}",
  cwd = "${cwd}",
  env = "${env}",
}
```

Notice that inside of the `dap_template` you can use the following "variables":

* `${cwd}` and `${env}` variables resolve to the working directory and environment variables already configured for that 
executable.
* `${arguments}` variable resolves to the test filters for a given run of the executable.

### Working in a monorepo?

You almost certainly want to disable "test discovery" in neotest itself (not in this adapter):

```lua
discovery = {
  enabled = false
}
```

Otherwise, neotest will walk the directory tree trying to discover test files but that does not scale to monorepos
with millions of files.

The `executables.resolve` option lets you implement a function to tell the adapter which test executable to
use for tests in a file. This is important if your repo has a large number of executables, because, otherwise, the 
adapter has to enumerate the tests in each executable to figure it out. This can cause the first test run to be very 
slow.

Lastly, remember that you can configure things like environment variables and working directories on a per-executable
basis. That may be helpful in monorepos with many sub-projects.
