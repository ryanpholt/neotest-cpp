local helpers = require("tests.helpers")

local eq = MiniTest.expect.equality

local test_project_dir = "tests/integration/cpp"

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_once = function()
      local gtest_versions = { "1.12.0", "1.13.0", "1.15.2", "1.16.0" }
      local version = gtest_versions[4]
      vim.system({ "xmake", "config", "--gtest_version=" .. version, "-y" }, { cwd = test_project_dir }):wait()
      vim.system({ "xmake", "--rebuild", "--yes" }, { cwd = test_project_dir }):wait()
    end,
    pre_case = function()
      child.restart({ "-u", "scripts/minimal_init.lua" })
      child.lua_func(function()
        require("tests.helpers").setup_neotest({
          executables = {
            patterns = { "tests/integration/cpp/build/**" },
            cwd = function(_)
              return "tests/integration/cpp"
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
          local i = 0
          while true do
            local ret = func()
            if ret then
              return ret
            else
              vim.wait(50)
            end
            i = i + 1
            assert(i < 50, "test is probably infinite looping")
          end
        end
      end)
    end,
    post_case = function()
      child.stop()
    end,
  },
})

T["neotest-cpp end-to-end integration"] = function()
  local test_file = child.fs.joinpath(test_project_dir, "test", "test_mylib.cpp")
  local buf = child.api.nvim_create_buf(false, false)
  child.api.nvim_buf_set_name(buf, test_file)
  child.api.nvim_set_current_buf(buf)
  child.api.nvim_command("edit " .. test_file)

  child.lua_func(function()
    require("neotest").run.run(vim.fn.expand("%"))
  end)

  local output_text = child.lua_func(function()
    local neotest = require("neotest")
    neotest.output_panel.open()
    local output_buf = wait_for(function()
      return vim.iter(vim.api.nvim_list_bufs()):find(function(buffer)
        if vim.api.nvim_buf_is_valid(buffer) then
          local buf_name = vim.api.nvim_buf_get_name(buffer)
          return buf_name:match("Neotest Output Panel")
        end
        return nil
      end)
    end)

    return wait_for(function()
      local output_lines = vim.api.nvim_buf_get_lines(output_buf, 0, -1, false)
      local text = vim.fn.join(output_lines, "\n")
      return #vim.trim(text) > 0 and text or nil
    end)
  end)

  helpers.expect.match(output_text, "%[ DISABLED %] MyLibTest.DISABLED_AddFunction5")
  helpers.expect.match(output_text, "%[  SKIPPED %] MyLibTest.AddFunction6")
  helpers.expect.match(output_text, "%[==========%] 13 tests from 3 test suites ran.")
  helpers.expect.match(output_text, "%[  PASSED  %] 6 tests.")
  helpers.expect.match(output_text, "%[  FAILED  %] MyLibTest.AddFunction2")
  helpers.expect.match(output_text, "%[  FAILED  %] MyLibTest.AddFunction3")
  helpers.expect.match(output_text, "%[  FAILED  %] MyFixture.ValueEqualsZero")
  helpers.expect.match(output_text, "%[  FAILED  %] EvenNumbersTests/MyParameterizedTest.CheckEvenNumbers2/0")
  helpers.expect.match(output_text, "%[  FAILED  %] EvenNumbersTests/MyParameterizedTest.CheckEvenNumbers2/1")
  helpers.expect.match(output_text, "%[  FAILED  %] EvenNumbersTests/MyParameterizedTest.CheckEvenNumbers2/2")

  local status = child.lua_func(function()
    local neotest = require("neotest")
    local adapter_ids = neotest.state.adapter_ids()
    assert(#adapter_ids == 1)
    return vim.inspect(neotest.state.status_counts(adapter_ids[1]))
  end)

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

  local diags = child.diagnostic.get(buf)
  for _, diag in ipairs(diags) do
    diag.namespace = nil
    diag.severity = nil
    diag.bufnr = nil
    -- Normalize message by trimming trailing whitespace/newlines
    if diag.message then
      diag.message = vim.trim(diag.message)
    end
  end

  helpers.equality_sanitized(
    vim.inspect(diags),
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

return T
