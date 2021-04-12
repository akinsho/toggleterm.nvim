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
--- 3. Default/base case config size
---
--- If `config.persist_size = false` then option `2` in the
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
--- @param win number
--- @param buf number
--- @param term Terminal
local function set_opts(win, buf, term)
  if term:is_split() then
    vim.wo[win].winfixheight = true
  end
  vim.bo[buf].buflisted = false
  vim.bo[buf].filetype = constants.term_ft
  api.nvim_buf_set_var(buf, "toggle_number", term.id)
end

---Create a terminal buffer with the correct buffer/window options
---@param term Terminal
---@return number, number
function M.create_buffer(term)
  local window = api.nvim_get_current_win()
  local bufnr = api.nvim_create_buf(false, false)
  set_opts(window, bufnr, term)
  api.nvim_set_current_buf(bufnr)
  return window, bufnr
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

local split_commands = {
  horizontal = {
    existing = "vsplit",
    new = "split",
    position = "wincmd J",
    resize = "resize"
  },
  vertical = {
    existing = "split",
    new = "vsplit",
    position = "wincmd L",
    resize = "vertical resize"
  }
}

--- @param size number
--- @param term Terminal
function M.open_split(size, term)
  local has_open, win_ids = M.find_open_windows()
  local commands = split_commands[term.direction]

  size = M.get_size(size)
  if has_open then
    -- we need to be in the terminal window most recently opened
    -- in order to split to the right of it
    api.nvim_set_current_win(win_ids[#win_ids])
    vim.cmd(commands.existing)
  else
    vim.cmd(size .. commands.new)
    -- move horizontal split to the bottom
    vim.cmd(commands.position)
  end
  ---TODO should the resize happen here
  M.resize_split(term, size)
end

function M.open_tab()
  vim.cmd("tabnew")
end

function M.open_window(term)
  term.window, term.bufnr = M.create_buffer(term)
  -- vim.cmd(fmt("buffer! %d", term.bufnr))
end

local function close_split()
  M.save_window_size()
  vim.cmd("hide")
  if api.nvim_win_is_valid(origin_window) then
    api.nvim_set_current_win(origin_window)
  else
    origin_window = nil
  end
end

local function close_window()
  vim.cmd("b#")
end

---Close given terminal's ui
---@param term Terminal
function M.close(term)
  if term:is_split() then
    close_split()
  elseif term.direction == "window" then
    close_window()
  else
    error(fmt("Not implemented close function for %s", term.direction))
  end
end

---Resize a split window
---@param term Terminal
---@param size number
function M.resize_split(term, size)
  if term:is_split() then
    size = size or M.get_size()
    vim.cmd(split_commands[term.direction].resize .. " " .. size)
  end
end

return M
