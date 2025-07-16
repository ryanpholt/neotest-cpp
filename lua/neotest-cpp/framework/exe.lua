local M = {}

--- @class Executable
--- @field path string
--- @field cwd? string
--- @field env? table<string, string>
--- @field dap_template? table<string, any>
M.Executable = {}
M.Executable.__index = M.Executable

---Construct an Executable
function M.Executable:new(path)
  local exe = {}
  local cfg_exe = require("neotest-cpp.config").get().executables
  exe.path = vim.fs.abspath(path)
  exe.cwd = cfg_exe.cwd(path)
  exe.env = cfg_exe.env(path)
  exe.dap_template = cfg_exe.debug.dap_template(path)
  setmetatable(exe, M.Executable)
  return exe
end

--- @param file string
--- @return boolean
function M.is_executable(file)
  local stat = vim.uv.fs_stat(file)
  if stat and stat.type == "file" then
    local user_execute = tonumber("00100", 8)
    return bit.band(stat.mode, user_execute) == user_execute or false
  end
  return false
end

--- Find executable files matching glob patterns
--- @param glob_patterns string[] List of glob patterns to search
--- @return Executable[] List of absolute paths to executable files
local function get(glob_patterns)
  return vim
    .iter(glob_patterns)
    :map(function(glob_pattern)
      return vim.fn.glob(glob_pattern, false, true)
    end)
    :flatten()
    :filter(function(match)
      return M.is_executable(match)
    end)
    :map(function(match)
      return M.Executable:new(match)
    end)
    :totable()
end

--- @type Executable[]
local executables = {}

--- Get executables matching glob patterns
--- @param glob_patterns string[]
--- @return Executable[]
function M.get_or_cached(glob_patterns)
  if #executables > 0 then
    return executables
  end
  executables = get(glob_patterns)
  return executables
end

return M
