local helpers = require("tests.helpers")

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ "-u", "scripts/minimal_init.lua" })
      child.lua_func(function()
        require("tests.helpers").setup_neotest()
      end)
    end,
    post_case = function()
      child.stop()
    end,
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
      cwd = vim.fn.getcwd(),
    }

    local result = { output = "test output" }
    local adapter = require("neotest-cpp.adapter")
    local results = require("nio").tests.with_async_context(adapter.results, spec, result, {})

    os.remove(temp_results_file)

    return vim.inspect(results)
  end, res)
end

T["passed"] = function()
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

T["failed"] = function()
  local mock_gtest_results = {
    testsuites = {
      {
        name = "MathTest",
        testsuite = {
          {
            name = "AddFunction3",
            file = "test/test_mylib.cpp",
            line = 14,
            status = "RUN",
            result = "COMPLETED",
            timestamp = "2025-07-16T09:41:58Z",
            time = "0s",
            classname = "MyLibTest",
            failures = {
              {
                failure = "test/test_mylib.cpp:15\nExpected equality of these values:\n  add(2, 3)\n    Which is: 5\n  3\n",
                type = "",
              },
              {
                failure = "test/test_mylib.cpp:16\nExpected equality of these values:\n  add(-1, 1)\n    Which is: 0\n  4\n",
                type = "",
              },
            },
          },
        },
      },
    },
  }

  local expected = string.format(
    [[
    {
      ["%s/test/test_mylib.cpp::MathTest::AddFunction3"] = {
        errors = { {
            line = 14,
            message = "Expected equality of these values:\n  add(2, 3)\n    Which is: 5\n  3\n"
          }, {
            line = 15,
            message = "Expected equality of these values:\n  add(-1, 1)\n    Which is: 0\n  4\n"
          } },
        output = "test output",
        short = "\27[1mMathTest.AddFunction3 failed\27[0m\n\nExpected equality of these values:\n  add(2, 3)\n    Which is: 5\n  3\n\nExpected equality
  of these values:\n  add(-1, 1)\n    Which is: 0\n  4\n",
        status = "failed"
      }
    }
  ]],
    vim.fn.getcwd()
  )

  helpers.equality_sanitized(get_results(mock_gtest_results), expected)
end

T["passed parameterized"] = function()
  local mock_gtest_results = {
    testsuites = {
      {
        name = "MathTest",
        testsuite = {
          {
            name = "CheckEvenNumbers/0",
            value_param = "2",
            file = "test/test_mylib.cpp",
            line = 65,
            status = "RUN",
            result = "COMPLETED",
            timestamp = "2025-07-16T09:41:58Z",
            time = "0s",
            classname = "EvenNumbersTests/MyTest2",
          },
          {
            name = "CheckEvenNumbers/1",
            value_param = "4",
            file = "test/test_mylib.cpp",
            line = 65,
            status = "RUN",
            result = "COMPLETED",
            timestamp = "2025-07-16T09:41:58Z",
            time = "0s",
            classname = "EvenNumbersTests/MyTest2",
          },
        },
      },
    },
  }

  local expected = string.format(
    [[
    {
      ["%s/test/test_mylib.cpp::MathTest::CheckEvenNumbers/*"] = {
        errors = {},
        output = "test output",
        short = "\27[1mMathTest.CheckEvenNumbers/0 passed\27[0m\n\n\27[1mMathTest.CheckEvenNumbers/1 passed\27[0m\n",
        status = "passed"
      }
    }
  ]],
    vim.fn.getcwd()
  )

  helpers.equality_sanitized(get_results(mock_gtest_results), expected)
end

T["failed parameterized"] = function()
  local mock_gtest_results = {
    testsuites = {
      {
        name = "MathTest",
        testsuite = {
          {
            name = "CheckEvenNumbers/0",
            value_param = "5",
            file = "test/test_mylib.cpp",
            line = 65,
            status = "RUN",
            result = "COMPLETED",
            timestamp = "2025-07-16T09:41:58Z",
            time = "0s",
            classname = "OddNumbersTest/MyTest2",
            failures = {
              {
                failure = "test/test_mylib.cpp:67\nExpected equality of these values:\n  n % 2\n    Which is: 1\n  0\n",
                type = "",
              },
            },
          },
          {
            name = "CheckEvenNumbers/1",
            value_param = "7",
            file = "test/test_mylib.cpp",
            line = 65,
            status = "RUN",
            result = "COMPLETED",
            timestamp = "2025-07-16T09:41:58Z",
            time = "0s",
            classname = "OddNumbersTest/MyTest2",
          },
        },
      },
    },
  }

  local expected = string.format(
    [[
      {
      ["%s/test/test_mylib.cpp::MathTest::CheckEvenNumbers/*"] = {
        errors = { {
            line = 66,
            message = "Expected equality of these values:\n  n %% 2\n    Which is: 1\n  0\n"
          } },
        output = "test output",
        short = "\27[1mMathTest.CheckEvenNumbers/0 failed\27[0m\n\nExpected equality of these values:\n  n %% 2\n    Which is: 1\n  0\n\n\27[1mMathTest.CheckEvenNumbers/1 passed\27[0m\n",
        status = "failed"
      }
    }
  ]],
    vim.fn.getcwd()
  )

  helpers.equality_sanitized(get_results(mock_gtest_results), expected)
end

T["exception"] = function()
  local mock_gtest_results = {
    testsuites = {
      {
        name = "MathTest",
        testsuite = {
          {
            name = "AddFunction3",
            file = "test/test_mylib.cpp",
            line = 14,
            status = "RUN",
            result = "COMPLETED",
            timestamp = "2025-07-16T09:41:58Z",
            time = "0s",
            classname = "MyLibTest",
            failures = {
              {
                failure = 'unknown file\nC++ exception with description "std::exception" thrown in the test body.\n',
                type = "",
              },
            },
          },
        },
      },
    },
  }

  local expected = string.format(
    [[
      {
    ["%s/test/test_mylib.cpp::MathTest::AddFunction3"] = {
      errors = { {
          message = 'C++ exception with description "std::exception" thrown in the test body.\n'
        } },
      output = "test output",
      short = '\27[1mMathTest.AddFunction3 failed\27[0m\n\nC++ exception with description "std::exception" thrown in the test body.\n',
      status = "failed"
    }
  }
  ]],
    vim.fn.getcwd()
  )

  helpers.equality_sanitized(get_results(mock_gtest_results), expected)
end

return T
