local neotest = require("neotest")
local nio = require("nio")
require("tests.utils")

local function wait_for(func)
  local i = 0
  while true do
    local ret = func()
    if ret then
      return ret
    else
      vim.wait(50)
    end
    i = i + 1
    assert.is_true(i < 50, "test is probably infinite looping")
  end
end

describe("neotest-cpp end-to-end integration", function()
  local test_project_dir = "tests/integration/cpp"
  local gtest_versions = { "1.12.0", "1.13.0", "1.15.2", "1.16.0" }

  for _, version in ipairs(gtest_versions) do
    describe("GoogleTest " .. version, function()
      setup(function()
        vim.system({ "xmake", "config", "--gtest_version=" .. version, "-y" }, { cwd = test_project_dir }):wait()
        vim.system({ "xmake", "--rebuild", "--yes" }, { cwd = test_project_dir }):wait()
      end)

      local test_file
      local buf

      before_each(function()
        require("neotest").setup({
          adapters = {
            require("neotest-cpp"),
          },
        })
        test_file = vim.fs.joinpath(test_project_dir, "test", "test_mylib.cpp")
        buf = vim.api.nvim_create_buf(false, false)
        vim.api.nvim_buf_set_name(buf, test_file)
        vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_command("edit " .. test_file)
      end)

      after_each(function()
        for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
          vim.api.nvim_buf_delete(buffer, { force = true })
        end
      end)

      it("runs a single test and captures output", function()
        nio.tests.with_async_context(function()
          wait_for(function()
            local ok = pcall(neotest.run.run, vim.fn.expand("%"))
            return ok
          end)
          neotest.output_panel.open()
        end)

        local output_buf = wait_for(function()
          return vim.iter(vim.api.nvim_list_bufs()):find(function(buffer)
            if vim.api.nvim_buf_is_valid(buffer) then
              local buf_name = vim.api.nvim_buf_get_name(buffer)
              return buf_name:match("Neotest Output Panel")
            end
            return nil
          end)
        end)

        local output_text = wait_for(function()
          local output_lines = vim.api.nvim_buf_get_lines(output_buf, 0, -1, false)
          local text = vim.fn.join(output_lines, "\n")
          return #vim.trim(text) > 0 and text or nil
        end)

        assert.is_truthy(string.match(output_text, "%[ DISABLED %] MyLibTest.DISABLED_AddFunction5"))
        assert.is_truthy(string.match(output_text, "%[  SKIPPED %] MyLibTest.AddFunction6"))
        assert.is_truthy(string.match(output_text, "%[==========%] 13 tests from 3 test suites ran."))
        assert.is_truthy(string.match(output_text, "%[  PASSED  %] 6 tests."))
        assert.is_truthy(string.match(output_text, "%[  FAILED  %] MyLibTest.AddFunction2"))
        assert.is_truthy(string.match(output_text, "%[  FAILED  %] MyLibTest.AddFunction3"))
        assert.is_truthy(string.match(output_text, "%[  FAILED  %] MyFixture.ValueEqualsZero"))
        assert.is_truthy(
          string.match(output_text, "%[  FAILED  %] EvenNumbersTests/MyParameterizedTest.CheckEvenNumbers2/0")
        )
        assert.is_truthy(
          string.match(output_text, "%[  FAILED  %] EvenNumbersTests/MyParameterizedTest.CheckEvenNumbers2/1")
        )
        assert.is_truthy(
          string.match(output_text, "%[  FAILED  %] EvenNumbersTests/MyParameterizedTest.CheckEvenNumbers2/2")
        )

        local adapter_ids = neotest.state.adapter_ids()
        assert(#adapter_ids == 1)

        local status = neotest.state.status_counts(adapter_ids[1])
        assert.same_ignoring_whitespace(
          vim.inspect(status),
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

        local diags = vim.diagnostic.get(buf)
        for _, diag in ipairs(diags) do
          diag.namespace = nil
          diag.severity = nil
          diag.bufnr = nil
          -- Normalize message by trimming trailing whitespace/newlines
          if diag.message then
            diag.message = vim.trim(diag.message)
          end
        end
        assert.same_ignoring_whitespace(
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
      end)
    end)
  end
end)
