local nio = require("nio")
local utils = require("tests.utils")

describe("results", function()
  local temp_results_file
  local adapter

  before_each(function()
    utils.setup_neotest({})
    adapter = require("neotest-cpp.adapter")
  end)

  local function get_results(mock_gtest_results)
    local json_content = vim.json.encode(mock_gtest_results)

    local file = io.open(temp_results_file, "w")
    assert(file)
    file:write(json_content)
    file:close()

    local spec = {
      context = {
        results_path = temp_results_file,
        non_existent_tests = {},
      },
    }

    local result = { output = "test output" }
    local results = nio.tests.with_async_context(adapter.results, spec, result, {})

    return vim.inspect(results)
  end

  before_each(function()
    temp_results_file = vim.fn.tempname()
  end)

  after_each(function()
    if temp_results_file then
      os.remove(temp_results_file)
    end
  end)

  it("should parse passing test results", function()
    local mock_gtest_results = {
      testsuites = {
        {
          name = "MathTest",
          testsuite = {
            {
              name = "Addition",
              status = "RUN",
              result = "COMPLETED",
              file = "/path/to/test.cpp",
              line = 5,
              failures = {},
            },
          },
        },
      },
    }

    local expected = [[
    {
      ["/path/to/test.cpp::MathTest::Addition"] = {
        errors = {},
        output = "test output",
        short = "\27[1mMathTest.Addition passed\27[0m\n",
        status = "passed"
      }
    }
    ]]

    assert.same_ignoring_whitespace(get_results(mock_gtest_results), expected)
  end)
end)
