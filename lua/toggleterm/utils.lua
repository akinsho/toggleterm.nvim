local M = {}

local api = vim.api
local fn = vim.fn
local fmt = string.format
local levels = vim.log.levels

---Print a message to vim's commandline
---@param msg string
---@param hl string
function M.echomsg(msg, hl)
  hl = hl or "Title"
  api.nvim_echo({ { msg, hl } }, true, {})
end

---Inform a user about something
---@param msg string
---@param level 'error' | 'info' | 'warn'
function M.notify(msg, level)
  level = level and levels[level:upper()] or levels.INFO
  vim.notify(fmt("[toggleterm]: %s", msg), level)
end

---@private
---Helper function to derive the current git directory path
---@return string|nil
function M.git_dir()
  local gitdir = fn.system(fmt("git -C %s rev-parse --show-toplevel", fn.expand("%:p:h")))
  local isgitdir = fn.matchstr(gitdir, "^fatal:.*") == ""
  if not isgitdir then
    return
  end
  return vim.trim(gitdir)
end

return M
