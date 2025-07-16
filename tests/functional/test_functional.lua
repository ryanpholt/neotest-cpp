local helpers = require("tests.functional.helpers")

local test_project_dir = "tests/functional/cpp"

local T = MiniTest.new_set()

local gtest_versions = { "1.12.0", "1.13.0", "1.15.2", "1.16.0" }

for _, version in ipairs(gtest_versions) do
  local child = MiniTest.new_child_neovim()

  T[version] = MiniTest.new_set({
    hooks = {
      pre_once = function()
        vim.system({ "xmake", "config", "--gtest_version=" .. version, "-y" }, { cwd = test_project_dir }):wait()
        vim.system({ "xmake", "--rebuild", "--yes" }, { cwd = test_project_dir }):wait()
      end,
      pre_case = function()
        child.restart({ "-u", "scripts/minimal_init.lua" })
        child.lua_func(function()
          require("tests.helpers").setup_neotest({
            executables = {
              patterns = { "tests/functional/cpp/build/**" },
              cwd = function(_)
                return "tests/functional/cpp"
              end,
            },
            gtest = {
              test_prefixes = {
                "RH_",
                "XY_",
              },
            },
            log_level = vim.log.levels.TRACE,
          })
          function _G.wait_for(func)
            local ret
            local wrapper = function()
              ret = func()
              return ret ~= nil
            end
            vim.wait(2000, wrapper, 50)
            return ret
          end
        end)
      end,
      post_case = function()
        child.stop()
      end,
    },
  })

  T[version]["status"] = function()
    local test_file = child.fs.joinpath(test_project_dir, "test", "test_mylib.cpp")

    local status = helpers.run_and_get_status(child, test_file)

    helpers.equality_sanitized(
      status,
      [[
  {
    failed = 4,
    passed = 4,
    running = 0,
    skipped = 2,
    total = 10
  }
      ]]
    )
  end

  T[version]["diagnostics"] = function()
    local test_file = child.fs.joinpath(test_project_dir, "test", "test_mylib.cpp")

    local diagnostics = helpers.run_and_get_diagnostics(child, test_file)

    helpers.equality_sanitized(
      diagnostics,
      [[
  { {
      col = 4,
      end_col = 4,
      end_lnum = 9,
      lnum = 9,
      message = "Expected equality of these values:\n  add(2, 3)\n    Which is: 5\n  3",
      source = "neotest"
    }, {
      col = 4,
      end_col = 4,
      end_lnum = 10,
      lnum = 10,
      message = "Expected equality of these values:\n  add(-1, 1)\n    Which is: 0\n  4",
      source = "neotest"
    }, {
      col = 4,
      end_col = 4,
      end_lnum = 14,
      lnum = 14,
      message = "Expected equality of these values:\n  add(2, 3)\n    Which is: 5\n  3",
      source = "neotest"
    }, {
      col = 4,
      end_col = 4,
      end_lnum = 15,
      lnum = 15,
      message = "Expected equality of these values:\n  add(-1, 1)\n    Which is: 0\n  4",
      source = "neotest"
    }, {
      col = 2,
      end_col = 2,
      end_lnum = 48,
      lnum = 48,
      message = "Expected equality of these values:\n  value\n    Which is: 42\n  0",
      source = "neotest"
    }, {
      col = 2,
      end_col = 2,
      end_lnum = 65,
      lnum = 65,
      message = "Expected equality of these values:\n  n % 2\n    Which is: 0\n  1",
      source = "neotest"
    } }
  ]]
    )
  end

  T[version]["output panel"] = function()
    local test_file = child.fs.joinpath(test_project_dir, "test", "test_mylib.cpp")

    local output = helpers.run_and_get_output_panel_contents(child, test_file)

    helpers.expect.match(output, "%[ DISABLED %] MyLibTest.DISABLED_AddFunction5")
    helpers.expect.match(output, "%[  SKIPPED %] MyLibTest.AddFunction6")
    helpers.expect.match(output, "%[==========%] 13 tests from 3 test suites ran.")
    helpers.expect.match(output, "%[  PASSED  %] 6 tests.")
    helpers.expect.match(output, "%[  FAILED  %] MyLibTest.AddFunction2")
    helpers.expect.match(output, "%[  FAILED  %] MyLibTest.AddFunction3")
    helpers.expect.match(output, "%[  FAILED  %] MyFixture.ValueEqualsZero")
    helpers.expect.match(output, "%[  FAILED  %] EvenNumbersTests/MyParameterizedTest.CheckEvenNumbers2/0")
    helpers.expect.match(output, "%[  FAILED  %] EvenNumbersTests/MyParameterizedTest.CheckEvenNumbers2/1")
    helpers.expect.match(output, "%[  FAILED  %] EvenNumbersTests/MyParameterizedTest.CheckEvenNumbers2/2")
  end
end

return T
