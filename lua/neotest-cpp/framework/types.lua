--- @class Test
--- @field name string
--- @field start_row number
--- @field start_col number
--- @field end_row number
--- @field end_col number
local Test = {}
Test.__index = Test

--- Creates a new Test instance
--- @param name string
--- @param start_row number
--- @param start_col number?
--- @param end_row number?
--- @param end_col number?
--- @return Test
function Test:new(name, start_row, start_col, end_row, end_col)
  local test = {
    name = name,
    start_row = start_row,
    start_col = start_col ~= nil and start_col or 0,
    end_row = end_row ~= nil and end_row or start_row,
    end_col = end_col ~= nil and end_col or 0,
  }
  setmetatable(test, self)
  return test
end

--- @class TestSuite
--- @field name string
--- @field tests Test[]
local TestSuite = {}
TestSuite.__index = TestSuite

--- Creates a new TestSuite instance
--- @param name string
--- @return TestSuite
function TestSuite:new(name)
  local suite = {
    name = name,
    tests = {},
  }
  setmetatable(suite, self)
  return suite
end

--- @class TestFile
--- @field executable Executable
--- @field suites TestSuite[]
local TestFile = {}
TestFile.__index = TestFile

--- Creates a new TestFile instance
--- @param executable Executable?
--- @return TestFile
function TestFile:new(executable)
  local file = {
    executable = executable,
    suites = {},
  }
  setmetatable(file, self)
  return file
end

return {
  Test = Test,
  TestSuite = TestSuite,
  TestFile = TestFile,
}
