local discover = require("neotest-cpp.framework.gtest.discover")
local results = require("neotest-cpp.framework.gtest.results")
local spec = require("neotest-cpp.framework.gtest.spec")

local M = {
  discover = discover,
  results = results,
  spec = spec,
}

--- Create a unique test ID from file path, suite name, and test name
--- @param file_path string Path to the test file
--- @param suite_name string? Name of the test suite
--- @param test_name string? Name of the test case
--- @return string Unique test identifier
function M.make_id(file_path, suite_name, test_name)
  local id = file_path
  if suite_name then
    id = id .. "::" .. suite_name
  end
  if test_name then
    id = id .. "::" .. test_name
  end
  return id
end

return M
