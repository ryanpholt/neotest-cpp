local discover = require("neotest-cpp.framework.gtest.discover")
local exe = require("neotest-cpp.framework.exe")
local log = require("neotest-cpp.log")
local types = require("neotest.types")
local utils = require("neotest-cpp.utils")

local M = {}

local cached_tests_from_exe = {}

--- Check if a test parsed via treesitter exists on the executable
--- @param file string File path
--- @param tests_from_exe TestFile Test file data from executable
--- @param test_from_treesitter table Test parsed from treesitter
--- @return boolean True if test exists
local function test_exists_on_executable(file, tests_from_exe, test_from_treesitter)
  for _, suite in ipairs(tests_from_exe.suites) do
    for _, test in ipairs(suite.tests) do
      local testname_pattern = test_from_treesitter.name:gsub("%*", ".*")
      local testname_matches = string.match(test.name, "^" .. testname_pattern .. "$")
      local suitename_pattern = test_from_treesitter.suite:gsub("%*", ".*")
      local suitename_matches = string.match(suite.name, "^" .. suitename_pattern .. "$")
      if file == test_from_treesitter.file and suitename_matches and testname_matches then
        return true
      end
    end
  end
  return false
end

--- Starts file watchers on provided test executables to auto-refresh test list on rebuild.
--- @param executables Executable[] List of executable paths to watch.
local function start_exe_watchers(executables)
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
          log.trace("Executable", executable("was modified"))
          local new_tests = discover.tests_from_executable(executable)
          for key, val in pairs(new_tests) do
            cached_tests_from_exe[key] = val
          end
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

--- Gets the list of tests for a given file and initializes exe watchers if necessary.
--- @async
--- @param file_path string Path to the test file.
--- @return TestFile | nil
local function get_tests_from_executable(file_path)
  if cached_tests_from_exe[file_path] then
    return cached_tests_from_exe[file_path]
  end
  local config = require("neotest-cpp.config")
  local get_executables = function()
    local executable_path = config.get().executables.resolve(file_path)
    if executable_path then
      assert(exe.is_executable(executable_path))
      log.debug("Executable resolved from", file_path, ":", executable_path)
      return {
        exe.Executable:new(executable_path),
      }
    else
      local executables = exe.get_or_cached(config.get().executables.patterns)
      log.debug("Executables discovered via patterns:", executables)
      return executables
    end
  end
  local executables = get_executables()
  local tests = discover.tests_from_executables(executables)
  cached_tests_from_exe = vim.tbl_extend("force", cached_tests_from_exe, tests)
  start_exe_watchers(executables)
  local tests_in_file = cached_tests_from_exe[file_path]
  return tests_in_file
end

--- Remove tests that don't exist on the executable
--- @param tests table[] List of tests to filter
--- @param file string File path
--- @return table[] Existent tests
--- @return table[] Non-existent tests
local function remove_non_existent_tests(tests, file)
  -- selene: allow(undefined_variable)
  if _TEST then
    return tests, {}
  end
  local tests_from_exe = get_tests_from_executable(file)
  local existent_tests = {}
  local non_existent_tests = {}
  for _, test in ipairs(tests) do
    if tests_from_exe and test_exists_on_executable(file, tests_from_exe, test) then
      table.insert(existent_tests, test)
    else
      table.insert(non_existent_tests, test)
    end
  end
  return existent_tests, non_existent_tests
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

  local tests_from_exe = get_tests_from_executable(position.path)

  ---@diagnostic disable-next-line: undefined-field
  local executable = tests_from_exe and tests_from_exe.executable or exe.Executable:new(position.executable)

  if not executable.path then
    error("Executable for " .. position.path .. " not found")
  end

  local tests = tree_to_flat_test_list(tree)

  -- Remove tests which do not yet exist on the executable (likely because the user didn't rebuild yet).
  local existent_tests, non_existent_tests = remove_non_existent_tests(tests, position.path)

  if not vim.tbl_isempty(non_existent_tests) then
    vim.schedule(function()
      vim.notify("Some tests do not exist on the executable.", vim.log.levels.WARN, { title = "neotest-cpp" })
    end)
  end

  local test_filters = vim
    .iter(existent_tests)
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

  local context = { results_path = results_path, non_existent_tests = non_existent_tests }

  log.debug("GTest spec:", executable, arguments, context)

  return executable, arguments, context
end

return M
