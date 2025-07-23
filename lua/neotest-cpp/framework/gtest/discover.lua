local log = require("neotest-cpp.log")
local nio = require("nio")
local test_types = require("neotest-cpp.framework.types")
local utils = require("neotest-cpp.utils")

local Test = test_types.Test
local TestSuite = test_types.TestSuite
local TestFile = test_types.TestFile

local M = {}

--- Build treesitter query to match any prefix ending with TEST, TEST_F, or TEST_P
--- The query is not very strict as it allows custom macros that wrap the typical
--- gtest macros. For example, this query should match
---   (.*)TEST_(_F|P)?\(MySuite, MyTest(,.*)\)
--- @return vim.treesitter.Query
local function build_test_query()
  local query_string = [[
  ((function_definition
    declarator: (
      function_declarator
        declarator: (identifier) @test.kind
      parameters: (
        parameter_list
          . (comment)*
          . (parameter_declaration type: (type_identifier) !declarator) @suite.name
          . (comment)*
          . (parameter_declaration type: (type_identifier) !declarator) @test.name
          . (comment)*
        )
      )
      !type
  )
  (#match? @test.kind ".*TEST(_F|_P)?$"))
  @test.definition

  ((call_expression
    function: (identifier) @test.kind
    arguments: (argument_list
      . (comment)*
      . (identifier) @suite.name
      . (comment)*
      . (identifier) @test.name
      . (_)*
    )
  )
  (#match? @test.kind ".*TEST(_F|_P)?$"))
  @test.definition
]]

  return vim.treesitter.query.parse("cpp", query_string)
end

local test_query = build_test_query()

--- Parse C++ file using treesitter to extract test information
--- @param file string Path to the C++ test file
--- @return table Test structure with suites and tests
local function run_treesitter(file)
  local future = nio.control.future()
  vim.schedule(function()
    future.set(vim.fn.bufnr(file, false))
  end)
  local bufnr = future.wait()
  local ok, result = pcall(vim.treesitter.get_parser, bufnr, "cpp")
  assert(ok, "Could not get parser")

  ---@diagnostic disable-next-line: need-check-nil
  local tree = result:parse()[1]
  local root = tree:root()

  local suites = {}
  for _, match, _ in test_query:iter_matches(root, bufnr) do
    local data = {}
    for id, nodes in pairs(match) do
      local capture_name = test_query.captures[id]
      for _, node in ipairs(nodes) do
        if capture_name == "test.definition" then
          data["range"] = { node:range() }
        else
          local text = vim.treesitter.get_node_text(node, bufnr)
          data[capture_name] = text
        end
      end
    end

    local suite_name = data["suite.name"]
    local is_parameterized = data["test.kind"]:match("TEST_P$")
    if is_parameterized then
      -- For parameterized tests, create suite names with instantiation prefixes
      suite_name = "*/" .. suite_name
      data["test.name"] = data["test.name"] .. "/*"
      data["suite.name"] = suite_name
    end
    if not suites[suite_name] then
      table.insert(suites, suite_name)
      suites[suite_name] = {}
    end
    table.insert(suites[suite_name], data)
  end
  return suites
end

--- Gets all tests in file using treesitter
--- @async
--- @param file string
--- @return TestFile
function M.tests_from_treesitter(file)
  local suites = run_treesitter(file)
  local tests = TestFile:new()
  for _, suite_name in ipairs(suites) do
    local suite = TestSuite:new(suite_name)
    table.insert(tests.suites, suite)
    for _, data in ipairs(suites[suite_name]) do
      local test_name = data["test.name"]
      local range = data["range"]
      local test = Test:new(test_name, unpack(range))
      table.insert(suite.tests, test)
    end
  end
  log.debug("Discovered tests via treesitter for", file, ":", tests)
  return tests
end

--- Runs --gtest_list_tests --gtest_output=json and returns decoded json
--- @async
--- @param executable Executable
--- @return table|nil # Test list JSON on success, or nil on failure.
--- @return nil|string # Error message on failure, or nil on success.
local function run_gtest_list(executable)
  local test_list_file = require("neotest-cpp.utils").tempname()
  local future = nio.control.future()
  local ok, res = pcall(function()
    local opts = { timeout = 10000, cwd = executable.cwd }
    vim.system(
      { executable.path, "--gtest_list_tests", "--gtest_output=json:" .. test_list_file },
      opts,
      function(result)
        future.set(result)
      end
    )
  end)
  if not ok then
    return nil, string.format("Failed to list tests from executable '%s': %s", executable.path, res)
  end
  res = future.wait()
  if res.code ~= 0 then
    return nil,
      string.format("Failed to list tests from executable '%s': %s (code: %d)", executable, res.stderr, res.code)
  end
  local json = require("neotest.lib").files.read(test_list_file)
  return vim.json.decode(json)
end

--- Gets tests from an executable
--- @async
--- @param executable Executable
--- @return table<string, TestFile>
function M.tests_from_executable(executable)
  ---@type table<string, TestFile>
  local tests = {}
  local content, error = run_gtest_list(executable)
  if not content then
    log.warn("Failed to list tests from executable", executable, ":", error)
    return {}
  end
  for _, testsuite in ipairs(content.testsuites or {}) do
    local suite = TestSuite:new(testsuite.name)
    for _, test in ipairs(testsuite.testsuite) do
      table.insert(suite.tests, Test:new(test.name, test.line - 1))
      local file = utils.normalize_path(test.file, executable.cwd)
      if not tests[file] then
        tests[file] = TestFile:new(executable)
      end
      if not vim.tbl_contains(tests[file].suites, suite) then
        table.insert(tests[file].suites, suite)
      end
    end
  end
  log.debug("Discovered tests from executable", executable, ":", tests)
  return tests
end

--- Gets all tests from multiple executables
--- @async
--- @param executables Executable[]
--- @return table<string, TestFile>
function M.tests_from_executables(executables)
  return vim.iter(executables):fold({}, function(tests, executable)
    return vim.tbl_extend("force", tests, M.tests_from_executable(executable))
  end)
end

return M
