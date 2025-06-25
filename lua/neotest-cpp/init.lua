---@class neotest-cpp: neotest-cpp.adapter
local M = {}

---@param opts? neotest-cpp.Config
function M.setup(opts)
  require("neotest-cpp.config").setup(opts)
end

return setmetatable(M, {
  __call = function()
    return M
  end,
  __index = function(_, k)
    return require("neotest-cpp.adapter")[k]
  end,
})
