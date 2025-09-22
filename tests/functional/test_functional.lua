local helpers = require("tests.functional.helpers")

local test_project_dir = "tests/functional/cpp"

local T = MiniTest.new_set()

local gtest_versions = { "1.12.0", "1.13.0", "1.15.2", "1.16.0" }

local child = MiniTest.new_child_neovim()

for _, version in ipairs(gtest_versions) do
  T[version] = MiniTest.new_set({
    hooks = {
      pre_once = function()
        vim.system({ "xmake", "config", "--gtest_version=" .. version, "-y" }, { cwd = test_project_dir }):wait()
        vim.system({ "xmake", "--rebuild", "--yes" }, { cwd = test_project_dir }):wait()
      end,
      pre_case = function()
        child.restart({ "-u", "scripts/minimal_init.lua" })
        child.lua_func(function()
          function _G.wait_for(func)
            local ret
            local wrapper = function()
              ret = func()
              return ret ~= nil
            end
            vim.wait(2000, wrapper, 100)
            return ret
          end
        end)
      end,
      post_case = function()
        child.stop()
      end,
    },
    parametrize = {
      { "pattern" },
      { "resolve" },
    },
    n_retry = 5,
  })

  T[version]["TEST - basic tests"] = function(pattern_or_resolve)
    helpers.setup_neotest(child, pattern_or_resolve)
    local test_file = child.fs.joinpath(test_project_dir, "test", "test_basic.cpp")

    local status = helpers.run_and_get_status(child, test_file)

    helpers.equality_sanitized(
      status,
      [[
  {
    failed = 2,
    passed = 2,
    running = 0,
    skipped = 0,
    total = 4
  }
      ]]
    )
  end

  T[version]["TEST - basic tests diagnostics"] = function(pattern_or_resolve)
    helpers.setup_neotest(child, pattern_or_resolve)
    local test_file = child.fs.joinpath(test_project_dir, "test", "test_basic.cpp")

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
    } }
  ]]
    )
  end

  T[version]["TEST - basic tests output panel"] = function(pattern_or_resolve)
    helpers.setup_neotest(child, pattern_or_resolve)
    local test_file = child.fs.joinpath(test_project_dir, "test", "test_basic.cpp")

    local output = helpers.run_and_get_output_panel_contents(child, test_file)

    helpers.expect.match(output, "%[       OK %] MyLibTest%.AddFunction")
    helpers.expect.match(output, "%[  FAILED  %] MyLibTest%.AddFunction2")
    helpers.expect.match(output, "%[  FAILED  %] MyLibTest%.AddFunction3")
    helpers.expect.match(output, "%[       OK %] MyLibTest%.AddFunction4")
  end

  T[version]["TEST_F - fixture tests"] = function(pattern_or_resolve)
    helpers.setup_neotest(child, pattern_or_resolve)
    local test_file = child.fs.joinpath(test_project_dir, "test", "test_fixture.cpp")

    local status = helpers.run_and_get_status(child, test_file)

    helpers.equality_sanitized(
      status,
      [[
  {
    failed = 1,
    passed = 1,
    running = 0,
    skipped = 0,
    total = 2
  }
      ]]
    )
  end

  T[version]["TEST_F - fixture tests diagnostics"] = function(pattern_or_resolve)
    helpers.setup_neotest(child, pattern_or_resolve)
    local test_file = child.fs.joinpath(test_project_dir, "test", "test_fixture.cpp")

    local diagnostics = helpers.run_and_get_diagnostics(child, test_file)

    helpers.equality_sanitized(
      diagnostics,
      [[
  { {
      col = 2,
      end_col = 2,
      end_lnum = 19,
      lnum = 19,
      message = "Expected equality of these values:\n  value\n    Which is: 42\n  0",
      source = "neotest"
    } }
  ]]
    )
  end

  T[version]["TEST_F - fixture tests output panel"] = function(pattern_or_resolve)
    helpers.setup_neotest(child, pattern_or_resolve)
    local test_file = child.fs.joinpath(test_project_dir, "test", "test_fixture.cpp")

    local output = helpers.run_and_get_output_panel_contents(child, test_file)

    helpers.expect.match(output, "%[       OK %] MyFixture%.ValueEqualsFortyTwo")
    helpers.expect.match(output, "%[  FAILED  %] MyFixture%.ValueEqualsZero")
  end

  T[version]["TEST_P - parameterized tests"] = function(pattern_or_resolve)
    helpers.setup_neotest(child, pattern_or_resolve)
    local test_file = child.fs.joinpath(test_project_dir, "test", "test_parameterized.cpp")

    local status = helpers.run_and_get_status(child, test_file)

    helpers.equality_sanitized(
      status,
      [[
  {
    failed = 1,
    passed = 1,
    running = 0,
    skipped = 0,
    total = 2
  }
      ]]
    )
  end

  T[version]["TEST_P - parameterized tests diagnostics"] = function(pattern_or_resolve)
    helpers.setup_neotest(child, pattern_or_resolve)
    local test_file = child.fs.joinpath(test_project_dir, "test", "test_parameterized.cpp")

    local diagnostics = helpers.run_and_get_diagnostics(child, test_file)

    helpers.equality_sanitized(
      diagnostics,
      [[
  { {
      col = 2,
      end_col = 2,
      end_lnum = 14,
      lnum = 14,
      message = "Expected equality of these values:\n  n % 2\n    Which is: 0\n  1",
      source = "neotest"
    } }
  ]]
    )
  end

  T[version]["TEST_P - parameterized tests output panel"] = function(pattern_or_resolve)
    helpers.setup_neotest(child, pattern_or_resolve)
    local test_file = child.fs.joinpath(test_project_dir, "test", "test_parameterized.cpp")

    local output = helpers.run_and_get_output_panel_contents(child, test_file)

    helpers.expect.match(output, "%[       OK %] EvenNumbersTests/MyParameterizedTest%.CheckEvenNumbers/0")
    helpers.expect.match(output, "%[       OK %] EvenNumbersTests/MyParameterizedTest%.CheckEvenNumbers/1")
    helpers.expect.match(output, "%[       OK %] EvenNumbersTests/MyParameterizedTest%.CheckEvenNumbers/2")
    helpers.expect.match(output, "%[  FAILED  %] EvenNumbersTests/MyParameterizedTest%.CheckEvenNumbers2/0")
    helpers.expect.match(output, "%[  FAILED  %] EvenNumbersTests/MyParameterizedTest%.CheckEvenNumbers2/1")
    helpers.expect.match(output, "%[  FAILED  %] EvenNumbersTests/MyParameterizedTest%.CheckEvenNumbers2/2")
  end

  T[version]["DISABLED tests"] = function(pattern_or_resolve)
    helpers.setup_neotest(child, pattern_or_resolve)
    local test_file = child.fs.joinpath(test_project_dir, "test", "test_disabled.cpp")

    local status = helpers.run_and_get_status(child, test_file)

    helpers.equality_sanitized(
      status,
      [[
  {
    failed = 0,
    passed = 0,
    running = 0,
    skipped = 1,
    total = 1
  }
      ]]
    )
  end

  T[version]["DISABLED tests output panel"] = function(pattern_or_resolve)
    helpers.setup_neotest(child, pattern_or_resolve)
    local test_file = child.fs.joinpath(test_project_dir, "test", "test_disabled.cpp")

    local output = helpers.run_and_get_output_panel_contents(child, test_file)

    helpers.expect.match(output, "0 tests from 0 test suites ran")
    helpers.expect.match(output, "YOU HAVE 1 DISABLED TEST")
  end

  T[version]["SKIPPED tests"] = function(pattern_or_resolve)
    helpers.setup_neotest(child, pattern_or_resolve)
    local test_file = child.fs.joinpath(test_project_dir, "test", "test_skipped.cpp")

    local status = helpers.run_and_get_status(child, test_file)

    helpers.equality_sanitized(
      status,
      [[
  {
    failed = 0,
    passed = 0,
    running = 0,
    skipped = 1,
    total = 1
  }
      ]]
    )
  end

  T[version]["SKIPPED tests output panel"] = function(pattern_or_resolve)
    helpers.setup_neotest(child, pattern_or_resolve)
    local test_file = child.fs.joinpath(test_project_dir, "test", "test_skipped.cpp")

    local output = helpers.run_and_get_output_panel_contents(child, test_file)

    helpers.expect.match(output, "%[  SKIPPED %] MyLibTest%.AddFunction6")
  end

  T[version]["exception tests diagnostics"] = function(pattern_or_resolve)
    helpers.setup_neotest(child, pattern_or_resolve)
    local test_file = child.fs.joinpath(test_project_dir, "test", "test_throw.cpp")

    local diagnostics = helpers.run_and_get_diagnostics(child, test_file)

    helpers.equality_sanitized(
      diagnostics,
      [[
        { {
          col = 0,
          end_col = 0,
          end_lnum = 3,
          lnum = 3,
          message = 'C++ exception with description "std::exception" thrown in the test body.',
          source = "neotest"
        } }
    ]]
    )
  end
end

return T
