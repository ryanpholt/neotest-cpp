local M = {}

-- Add extra expectations
M.expect = vim.deepcopy(MiniTest.expect)

M.expect.match = MiniTest.new_expectation(
  'string matching',
  function(str, pattern) return str:find(pattern) ~= nil end,
  function(str, pattern) return string.format('Pattern: %s\nObserved string: %s', vim.inspect(pattern), str) end
)

M.expect.no_match = MiniTest.new_expectation(
  'no string matching',
  function(str, pattern) return str:find(pattern) == nil end,
  function(str, pattern) return string.format('Pattern: %s\nObserved string: %s', vim.inspect(pattern), str) end
)

local function scrub_temp_paths(path)
  local temp_base = vim.fn.tempname():match("^(.*/nvim%.[^/]*/)")
  if temp_base then
    return path:gsub(temp_base .. '[^",%s]*', "/tmp/neotest-cpp-results")
  end
  return path
end

M.equality_sanitized = require("mini.test").new_expectation(
  "strings same ignoring whitespace",
  function(actual, expected)
    local actual_scrubbed = scrub_temp_paths(actual)
    local expected_scrubbed = scrub_temp_paths(expected)

    local actual_clean = actual_scrubbed:gsub("%s", "")
    local expected_clean = expected_scrubbed:gsub("%s", "")

    return expected_clean == actual_clean
  end,
  function(actual, expected)
    local actual_scrubbed = scrub_temp_paths(actual)
    local expected_scrubbed = scrub_temp_paths(expected)

    return string.format("Expected:\n%s\nActual:\n%s", expected_scrubbed, actual_scrubbed)
  end
)

function M.setup_neotest(neotest_cpp_config)
  require("neotest-cpp").setup(neotest_cpp_config)
  ---@diagnostic disable
  require("neotest").setup({
    adapters = {
      require("neotest-cpp"),
    },
    discovery = {
      enabled = false,
    },
    log_level = vim.log.levels.TRACE,
  })
end

return M
