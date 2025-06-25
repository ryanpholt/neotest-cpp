local M = {}

local nio = require("nio")

local last_mtime = {}

--- Check if file modification time has changed
--- @param path string File path to check
--- @return boolean True if modification time changed
function M.check_mtime(path)
  local stat = vim.uv.fs_stat(path)
  if not stat then
    return false
  end

  local current_mtime = stat.mtime.sec
  if last_mtime[path] ~= current_mtime then
    last_mtime[path] = current_mtime
    return true
  end
  return false
end

--- Watch a file for changes
--- @param path string File path to watch
--- @param on_event function Callback for file change events
--- @param on_error fun(err: any, unwatch_cb: function) Callback for errors
--- @return uv.uv_fs_event_t UV handle for the file watcher
function M.file_watch(path, on_event, on_error)
  local filename = vim.fs.basename(path)
  local dir = vim.fs.dirname(path)

  local handle = vim.uv.new_fs_event()
  assert(handle)

  local flags = {
    watch_entry = false,
    stat = false,
    recursive = false,
  }

  local unwatch_cb = function()
    vim.uv.fs_event_stop(handle)
  end

  local event_cb = function(err, changed_filename, events)
    if err then
      on_error(err, unwatch_cb)
    else
      if changed_filename == filename then
        if not M.check_mtime(path) then
          -- Only watch for file modifications -- not file access
          return
        end
        on_event(filename, events, unwatch_cb)
      end
    end
  end

  -- Initialize current modification time
  M.check_mtime(path)

  -- attach handler
  vim.uv.fs_event_start(handle, dir, flags, event_cb)

  return handle
end

--- Normalize file path relative to working directory
--- @param path string File path to normalize
--- @param cwd string? Working directory
--- @return string Normalized absolute path
function M.normalize_path(path, cwd)
  -- Resolve file path relative to the working directory used to run the executable
  if cwd and not vim.startswith(path, "/") then
    path = vim.fs.normalize(vim.fs.joinpath(cwd, path))
  end
  return vim.fs.abspath(path)
end

--- @return string tempname
function M.tempname()
  local future = nio.control.future()
  vim.schedule(function()
    local test_list_file = vim.fn.tempname()
    future.set(test_list_file)
  end)
  return future:wait()
end

return M
