local M = {}

local constants = require("toggleterm.constants")

local fn = vim.fn
local fmt = string.format
local api = vim.api

local persistent = {}
local origin_window

function M.save_window_size()
  -- Save the size of the split before it is hidden
  persistent.width = vim.fn.winwidth(0)
  persistent.height = vim.fn.winheight(0)
end

--- Get the size of the split. Order of priority is as follows:
--- 1. The size argument is a valid number > 0
--- 2. There is persistent width/height information from prev open state
--- 3. Default/base case perference size
---
--- If `preferences.persist_size = false` then option `2` in the
--- list is skipped.
--- @param size number
function M.get_size(size)
  local config = require("toggleterm.config").get()
  local valid_size = size ~= nil and size > 0
  if not config.persist_size then
    return valid_size and size or config.size
  end

  local psize = config.direction == "horizontal" and persistent.height or persistent.width
  return valid_size and size or psize or config.size
end

--- Add terminal buffer specific options
--- @param term Terminal
local function set_opts(term)
  if term:is_split() then
    vim.wo[term.window].winfixheight = true
  end
  vim.bo[term.bufnr].buflisted = false
  vim.bo[term.bufnr].filetype = constants.term_ft
  api.nvim_buf_set_var(term.bufnr, "toggle_number", term.id)
end

function M.set_origin_window()
  origin_window = api.nvim_get_current_win()
end

function M.get_origin_window()
  return origin_window
end

function M.update_origin_window(term_window)
  local curr_win = api.nvim_get_current_win()
  if term_window ~= curr_win then
    origin_window = curr_win
  end
end

--- @param win_id number
function M.find_window(win_id)
  return fn.win_gotoid(win_id) > 0
end
--- Find the first open terminal window
--- by iterating all windows and matching the
--- containing buffers filetype with the passed in
--- comparator function or the default which matches
--- the filetype
--- @param comparator function
function M.find_open_windows(comparator)
  comparator = comparator or function(buf)
      return vim.bo[buf].filetype == constants.term_ft
    end
  local wins = api.nvim_list_wins()
  local is_open = false
  local term_wins = {}
  for _, win in pairs(wins) do
    local buf = api.nvim_win_get_buf(win)
    if comparator(buf) then
      is_open = true
      table.insert(term_wins, win)
    end
  end
  return is_open, term_wins
end

--- @param size number
--- @param term Terminal
function M.open_split(size, term)
  size = M.get_size(size)

  local has_open, win_ids = M.find_open_windows()
  local commands =
    term.direction == "horizontal" and
    {
      "vsplit",
      "split",
      "wincmd J"
    } or
    {
      "split",
      "vsplit",
      "wincmd L"
    }

  if has_open then
    -- we need to be in the terminal window most recently opened
    -- in order to split to the right of it
    api.nvim_set_current_win(win_ids[#win_ids])
    vim.cmd(commands[1])
    vim.cmd(fmt("keepalt buffer %d", term.bufnr))
    vim.wo.winfixheight = true
  else
    vim.cmd(size .. commands[2])
    -- move horizontal split to the bottom
    vim.cmd(commands[3])
  end
  term:resize(size)
  set_opts(term)
end

function M.open_tab()
  vim.cmd("tabnew")
end

function M.open_window(bufnr)
  vim.cmd(fmt("buffer! %d", bufnr))
end

return M
