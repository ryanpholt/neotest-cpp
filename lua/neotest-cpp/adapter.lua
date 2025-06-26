local framework = require("neotest-cpp.framework")
local log = require("neotest-cpp.log")
local types = require("neotest.types")

---@class neotest-cpp.adapter
local M = { name = "neotest-cpp" }

---Find the project root directory given a current directory to work from.
---Should no root be found, the adapter can still be used in a non-project context if a test file matches.
---@async
---@param dir string @Directory to treat as cwd
---@return string | nil @Absolute root dir of test suite
M.root = function(dir)
  return vim.fs.root(
    dir,
    { ".git", "compile_commands.json", ".clangd", ".clang-format", ".clang-tidy", "compile_flags.txt", "build" }
  )
end

---Filter directories when searching for test files
---@async
---@param _name string Name of directory
---@param _rel_path string Path to directory, relative to root
---@param _root string Root directory of project
---@return boolean
---@diagnostic disable-next-line: unused-local
M.filter_dir = function(_name, _rel_path, _root)
  return true
end

---@async
---@param file_path string
---@return boolean
M.is_test_file = function(file_path)
  return vim.endswith(file_path, ".cpp")
    or vim.endswith(file_path, ".cxx")
    or vim.endswith(file_path, ".cc")
    or vim.endswith(file_path, ".c++")
end

---Given a file path, parse all the tests within it.
---@async
---@param file_path string Absolute file path
---@return neotest.Tree | nil
M.discover_positions = function(file_path)
  log.trace("Discovering positions for", file_path)
  local tests = framework.discover.tests_from_treesitter(file_path)
  ---@type neotest.Position[]
  local file_positions = {
    {
      id = framework.make_id(file_path),
      name = vim.fn.fnamemodify(file_path, ":t"),
      type = types.PositionType.file,
      path = file_path,
      range = { 0, 0, 0, 0 },
    },
  }
  for _, suite in ipairs(tests.suites) do
    ---@type neotest.Position[]
    local suite_positions = {}
    local min_row, max_row = 0, 0
    for i, test in ipairs(suite.tests) do
      if i == 1 then
        min_row = test.start_row
      end
      max_row = math.max(max_row, test.end_row)
      table.insert(suite_positions, {
        id = framework.make_id(file_path, suite.name, test.name),
        name = test.name,
        type = types.PositionType.test,
        path = file_path,
        range = { test.start_row, test.start_col, test.end_row, test.end_col },
        suite = suite.name,
      })
    end
    table.insert(suite_positions, 1, {
      id = framework.make_id(file_path, suite.name),
      name = suite.name,
      type = types.PositionType.namespace,
      path = file_path,
      range = { min_row, 0, max_row, 0 },
    })
    table.insert(file_positions, suite_positions)
  end
  return require("neotest.types.tree").from_list(file_positions, function(x)
    return x.id
  end)
end

---@param arguments string[]
---@param executable Executable
---@return table<string, any>
local function make_dap_config(arguments, executable)
  local dap_template = vim.deepcopy(executable.dap_template)
  assert(dap_template, "Missing dap template")
  local resolvers = {
    ["${arguments}"] = function()
      return arguments
    end,
    ["${cwd}"] = function()
      return executable.cwd
    end,
    ["${env}"] = function()
      return executable.env
    end,
  }
  for key, value in pairs(dap_template) do
    if resolvers[value] then
      dap_template[key] = resolvers[value]()
    end
  end
  return dap_template
end

---@param args neotest.RunArgs
---@return nil | neotest.RunSpec | neotest.RunSpec[]
M.build_spec = function(args)
  log.trace("Building spec for", args)
  local executable, arguments, context = framework.spec.build(args)
  if not executable or not arguments then
    return nil
  end

  local command = {
    executable.path,
    unpack(arguments),
  }
  local cmd = {
    command = command,
    cwd = executable.cwd,
    env = executable.env,
    context = context,
    strategy = args.strategy == "dap" and make_dap_config(arguments, executable) or nil,
  }
  return cmd
end

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param _ neotest.Tree
---@return table<string, neotest.Result>
M.results = function(spec, result, _)
  log.trace("Building results for", spec, result)
  return framework.results.results(spec, result)
end

return M
