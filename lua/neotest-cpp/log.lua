---@return neotest.Logger
local function get_logger()
  return require("neotest.logging").new("neotest-cpp", { level = require("neotest-cpp.config").get().log_level })
end

return get_logger()
