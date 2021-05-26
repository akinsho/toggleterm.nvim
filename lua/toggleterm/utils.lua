local M = {}

local api = vim.api
local fn = vim.fn
local fmt = string.format

---Print a message to vim's commandline
---@param msg string
---@param hl string
function M.echomsg(msg, hl)
  hl = hl or "Title"
  api.nvim_echo({ { msg, hl } }, true, {})
end

--- Source: https://teukka.tech/luanvim.html
--- @param definitions table<string,table>
function M.create_augroups(definitions)
  for group_name, definition in pairs(definitions) do
    vim.cmd("augroup " .. group_name)
    vim.cmd("autocmd!")
    for _, def in pairs(definition) do
      local command = table.concat(vim.tbl_flatten({ "autocmd", def }), " ")
      vim.cmd(command)
    end
    vim.cmd("augroup END")
  end
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
