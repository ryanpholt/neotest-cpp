local helpers = require("tests.helpers")

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ "-u", "scripts/minimal_init.lua" })
      child.lua_func(function()
        require("tests.helpers").setup_neotest({})
      end)
    end,
    post_case = function()
      child.stop()
    end
  },
})

local get_results = function(res)
  return child.lua_func(function(mock_gtest_results)
    local json_content = vim.json.encode(mock_gtest_results)

    local temp_results_file = vim.fn.tempname()
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
    local adapter = require("neotest-cpp.adapter")
    local results = require("nio").tests.with_async_context(adapter.results, spec, result, {})

    os.remove(temp_results_file)

    return vim.inspect(results)
  end, res)
end

T["should parse passing test results"] = function()
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

  helpers.equality_sanitized(get_results(mock_gtest_results), expected)
end

return T
