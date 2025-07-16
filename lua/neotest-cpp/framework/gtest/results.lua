local lib = require("neotest.lib")
local log = require("neotest-cpp.log")
local types = require("neotest.types")
local utils = require("neotest-cpp.utils")

local M = {}

--- Extract error message and line number from test output
--- @param message string Test failure message
--- @return string Error message
--- @return number Line number
local function extract_error_msg_and_line(message)
  local newline = message:find("\n")
  assert(newline)
  local linenum = message:sub(1, newline - 1):match(".*:(%d+)$")
  assert(linenum)
  local number = tonumber(linenum)
  assert(number)
  return message:sub(newline + 1), number
end

---@param gtest_failures table[]
---@return table[]
local function extract_errors(gtest_failures)
  return vim
    .iter(gtest_failures or {})
    :map(function(failure)
      local msg, line = extract_error_msg_and_line(failure.failure)
      return {
        message = msg,
        line = line - 1,
      }
    end)
    :totable()
end

---@param gtest_status string
---@param errors table[]
---@return string
local function determine_status(gtest_status, gtest_result, errors)
  local status = types.ResultStatus
  if not vim.tbl_isempty(errors) then
    return status.failed
  end
  if gtest_status == "NOTRUN" or gtest_result == "SKIPPED" then
    return status.skipped
  end
  assert(gtest_result == "COMPLETED")
  return status.passed
end

---@param existing_status string
---@param other_status string
---@return string
local function merge_status(existing_status, other_status)
  local either_is = function(status)
    return existing_status == status or other_status == status
  end
  local status = types.ResultStatus
  if either_is(status.failed) then
    return status.failed
  end
  if either_is(status.skipped) then
    return status.skipped
  end
  return status.passed
end

---@param suitename string
---@param testname string
---@param status string
---@param errors table[]
---@return string
local function make_error_summary(suitename, testname, status, errors)
  local error_summary = {}
  table.insert(error_summary, string.format("\27[1m%s.%s %s\27[0m\n", suitename, testname, status))
  for _, error in ipairs(errors) do
    table.insert(error_summary, error.message)
  end
  return vim.iter(error_summary):join("\n")
end

---@param file string
---@param cwd string
---@param suitename string
---@param testname string
---@return string
local function normalize_and_make_id(file, cwd, suitename, testname)
  local normalized_file = utils.normalize_path(file, cwd)
  local new_suitename = suitename:gsub("^.*/", "*/")
  local new_testname = testname:gsub("/[^/]*$", "/*")
  return require("neotest-cpp.framework").make_id(normalized_file, new_suitename, new_testname)
end

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@return table<string, neotest.Result>
function M.results(spec, result)
  local results = {}
  local read, json = pcall(lib.files.read, spec.context.results_path)
  if not read then
    return {}
  end
  local decoded, contents = pcall(vim.json.decode, json)
  if not decoded then
    return {}
  end

  for _, testsuite in ipairs(contents.testsuites) do
    local suitename = testsuite.name
    for _, test in ipairs(testsuite.testsuite) do
      local testname = test.name
      local id = normalize_and_make_id(test.file, spec.cwd, suitename, testname)
      local errors = extract_errors(test.failures)
      local status = determine_status(test.status, test.result, errors)
      local error_summary = make_error_summary(suitename, testname, status, errors)

      if results[id] then
        local res = results[id]
        res["status"] = merge_status(res["status"], status)
        res["errors"] = vim.tbl_extend("force", res["errors"], errors)
        res["short"] = string.format("%s\n%s", res["short"], error_summary)
      else
        results[id] = {
          status = status,
          output = result.output,
          errors = errors,
          short = error_summary,
        }
      end
    end
  end
  log.debug("GTest results:", results)
  return results
end

return M
