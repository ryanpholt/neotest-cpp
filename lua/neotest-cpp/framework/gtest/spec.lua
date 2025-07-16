local discover = require("neotest-cpp.framework.gtest.discover")
local exe = require("neotest-cpp.framework.exe")
local log = require("neotest-cpp.log")
local types = require("neotest.types")
local utils = require("neotest-cpp.utils")

local M = {}

local cached_tests_from_exe = {}

--- @param executable Executable
local function update_cached_tests(executable)
  local new_tests = discover.tests_from_executable(executable)
  for key, val in pairs(new_tests) do
    cached_tests_from_exe[key] = val
  end
end

--- Starts file watchers on provided test executables to auto-refresh test list on rebuild.
--- @param executables Executable[] List of executable paths to watch.
--- @param on_modified fun(executable: Executable)
local function watch_exe_for_modifications(executables, on_modified)
  for _, executable in ipairs(executables) do
    local defer = nil
    local on_event = function()
      if defer then
        return
      end
      local debounce_ms = 100
      defer = vim.defer_fn(function()
        require("nio").run(function()
          defer = nil
          on_modified(executable)
          log.trace("Executable", executable, "was modified")
        end)
      end, debounce_ms)
    end
    local on_error = function()
      vim.schedule(function()
        vim.notify_once("Failed to watch " .. executable)
      end)
    end
    utils.file_watch(executable.path, on_event, on_error)
  end
end

--- @param file_path string
--- @return Executable[]
local function get_executables(file_path)
  local config = require("neotest-cpp.config")
  local future = require("nio").control.future()
  vim.schedule(function()
    future.set(config.get().executables.resolve(file_path))
  end)
  local executable_path = future:wait()
  if executable_path then
    if not exe.is_executable(executable_path) then
      log.error("Executable resolved from", file_path, ":", executable_path, "is not executable")
    else
      log.debug("Executable resolved from", file_path, ":", executable_path)
    end
    return {
      exe.Executable:new(executable_path),
    }
  else
    local executables = exe.get_or_cached(config.get().executables.patterns)
    log.debug("Executables discovered via patterns:", executables)
    return executables
  end
end

--- Gets the list of tests for a given file
--- @async
--- @param file_path string Path to the test file.
--- @return TestFile | nil
local function get_tests_from_executable(file_path)
  if cached_tests_from_exe[file_path] then
    return cached_tests_from_exe[file_path]
  end
  local executables = get_executables(file_path)
  local tests = discover.tests_from_executables(executables)
  cached_tests_from_exe = vim.tbl_extend("force", cached_tests_from_exe, tests)
  local tests_in_file = cached_tests_from_exe[file_path]
  return tests_in_file
end

--- Convert a neotest.Tree into a flat list of tests
--- @param tree neotest.Tree Test tree structure
--- @return table[] List of test objects
local function tree_to_flat_test_list(tree)
  local tests = {}
  for _, pos in tree:iter() do
    if pos.type == types.PositionType.test then
      ---@diagnostic disable-next-line: undefined-field
      table.insert(tests, { file = pos.path, suite = pos.suite, name = pos.name })
    end
  end
  return tests
end

local function is_supported_position(position)
  -- TODO: Support directories -- we need to partition the tests based on the executables they belong to
  local supported_positions = { types.PositionType.test, types.PositionType.namespace, types.PositionType.file }
  return vim.tbl_contains(supported_positions, position.type)
end

---@param args neotest.RunArgs
---@return Executable?, string[]?, string[]?
function M.build(args)
  local tree = args and args.tree
  if not tree then
    return nil
  end
  local position = tree:data()
  if not is_supported_position(position) then
    return nil
  end

  local executables = get_executables(position.path)
  watch_exe_for_modifications(executables, update_cached_tests)
  local tests_from_exe = get_tests_from_executable(position.path)

  ---@diagnostic disable-next-line: undefined-field The field `position.executable` is used for testing
  local executable = tests_from_exe and tests_from_exe.executable or exe.Executable:new(position.executable)

  if not executable.path then
    local relpath = vim.fs.relpath(vim.fn.getcwd(), position.path)
    error("Executable for " .. relpath .. " not found")
  end

  local tests = tree_to_flat_test_list(tree)

  local test_filters = vim
    .iter(tests)
    :map(function(test)
      return test.suite .. "." .. test.name
    end)
    :totable()

  local results_path = require("neotest-cpp.utils").tempname()

  local arguments = {
    "--gtest_filter=" .. table.concat(test_filters, ":"),
    "--gtest_output=json:" .. results_path,
  }
  if args.strategy == "dap" then
    table.insert(arguments, "--gtest_color=no")
    table.insert(arguments, "--gtest_break_on_failure")
  end

  local context = { results_path = results_path }

  log.debug("GTest spec:", executable, arguments, context)

  return executable, arguments, context
end

return M
