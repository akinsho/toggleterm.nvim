local M = {}

local fn = vim.fn
local fmt = string.format
local levels = vim.log.levels

function M.is_nightly()
  local v = vim.version()
  return v.minor >= 8
end

---@alias error_types 'error' | 'info' | 'warn'
---Inform a user about something
---@param msg string
---@param level error_types
function M.notify(msg, level)
  local err = level:upper()
  level = level and levels[err] or levels.INFO
  vim.schedule(function() vim.notify(msg, level, { title = "Toggleterm" }) end)
end

---@private
---Helper function to derive the current git directory path
---@return string|nil
function M.git_dir()
  local gitdir = fn.system(fmt("git -C %s rev-parse --show-toplevel", fn.expand("%:p:h")))
  local isgitdir = fn.matchstr(gitdir, "^fatal:.*") == ""
  if not isgitdir then return end
  return vim.trim(gitdir)
end

---@param str string|nil
---@return boolean
function M.str_is_empty(str) return str == nil or str == "" end

---@param tbl table
---@return table
function M.tbl_filter_empty(tbl)
  return vim.tbl_filter(
    ---@param str string|nil
    function(str) return not M.str_is_empty(str) end,
    tbl
  )
end

--- Concats a table ignoring empty entries
---@param tbl table
---@param sep string
function M.concat_without_empty(tbl, sep) return table.concat(M.tbl_filter_empty(tbl), sep) end

return M
