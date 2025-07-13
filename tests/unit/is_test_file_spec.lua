local adapter
local utils = require("tests.utils")

before_each(function()
  utils.setup_neotest({})
  adapter = require("neotest-cpp.adapter")
end)

describe("is_test_file", function()
  it("should return true for C++ test files", function()
    assert.is_true(adapter.is_test_file("/path/to/test_file.cpp"))
    assert.is_true(adapter.is_test_file("/path/to/file_test.cxx"))
    assert.is_true(adapter.is_test_file("/path/to/file_test.cc"))
  end)

  it("should return false for non-C++ files", function()
    assert.is_false(adapter.is_test_file("/path/to/file.c"))
    assert.is_false(adapter.is_test_file("/path/to/file.h"))
    assert.is_false(adapter.is_test_file("/path/to/file.hpp"))
    assert.is_false(adapter.is_test_file("/path/to/file.py"))
    assert.is_false(adapter.is_test_file("/path/to/file.txt"))
  end)
end)
