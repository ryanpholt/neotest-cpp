local M = {}

function M.setup_neotest(child, pattern_or_resolve_)
  child.lua_func(function(pattern_or_resolve)
    local patterns = nil
    local resolve = nil
    if pattern_or_resolve == "pattern" then
      patterns = { "tests/functional/cpp/build/**" }
    else
      resolve = function(test_file)
        local filename = vim.fn.fnamemodify(test_file, ":t")
        local exe_name = string.gsub(filename, "%.cpp", "")
        assert(exe_name, "No executable mapping found for test file: " .. filename)
        local results = vim.fn.glob("tests/functional/cpp/build/**/" .. exe_name, false, true)
        assert(#results == 1, "Expected exactly 1 executable for " .. exe_name .. ", found " .. #results)
        return results[1]
      end
    end
    require("tests.helpers").setup_neotest({
      executables = {
        patterns = patterns,
        resolve = resolve,
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
  end, pattern_or_resolve_)
end

local function open_buf(child, test_file)
  local buf = child.api.nvim_create_buf(false, false)
  child.api.nvim_buf_set_name(buf, test_file)
  child.api.nvim_set_current_buf(buf)
  child.api.nvim_command("edit " .. test_file)
  return buf
end

function M.run_and_get_status(child, test_file)
  open_buf(child, test_file)
  return child.lua_func(function()
    local neotest = require("neotest")
    neotest.run.run(vim.fn.expand("%"))
    neotest.output_panel.open()
    return wait_for(function()
      local adapter_ids = neotest.state.adapter_ids()
      if #adapter_ids == 0 then
        return nil
      end
      local status = neotest.state.status_counts(adapter_ids[1])
      if
        not status
        or status["running"] ~= 0
        or (status["failed"] + status["passed"] + status["skipped"]) ~= status["total"]
      then
        return nil
      end
      return vim.inspect(status)
    end)
  end)
end

function M.run_and_get_output_panel_contents(child, test_file)
  open_buf(child, test_file)
  return child.lua_func(function()
    local neotest = require("neotest")
    neotest.run.run(vim.fn.expand("%"))
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
end

function M.run_and_get_diagnostics(child, test_file)
  local buf_ = open_buf(child, test_file)
  return child.lua_func(function(buf)
    local neotest = require("neotest")
    neotest.run.run(vim.fn.expand("%"))
    neotest.output_panel.open()
    return wait_for(function()
      local diags = vim.diagnostic.get(buf)
      if vim.tbl_isempty(diags) then
        return nil
      end
      for _, diag in ipairs(diags) do
        diag.namespace = nil
        diag.severity = nil
        diag.bufnr = nil
        -- Normalize message by trimming trailing whitespace/newlines
        if diag.message then
          diag.message = vim.trim(diag.message)
        end
      end
      return vim.inspect(diags)
    end)
  end, buf_)
end

return setmetatable(M, {
  __index = function(_, k)
    return require("tests.helpers")[k]
  end,
})
