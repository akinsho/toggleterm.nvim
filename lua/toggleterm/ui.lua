local M = {}

local constants = require("toggleterm.constants")
local utils = require("toggleterm.utils")

local fn = vim.fn
local fmt = string.format
local api = vim.api

local origin_window
local persistent = {}

--- Save the size of a split window before it is hidden
--- @param direction string
--- @param window number
function M.save_window_size(direction, window)
  if direction == "horizontal" then
    persistent.horizontal = api.nvim_win_get_height(window)
  elseif direction == "vertical" then
    persistent.vertical = api.nvim_win_get_width(window)
  end
end

--- Explicitly set the persistent size of a direction
--- @param direction string
--- @param size number
function M.save_direction_size(direction, size)
  persistent[direction] = size
end

--- @param direction string
--- @return boolean
function M.has_saved_size(direction)
  return persistent[direction] ~= nil
end

--- Get the size of the split. Order of priority is as follows:
--- 1. The size argument is a valid number > 0
--- 2. There is persistent width/height information from prev open state
--- 3. Default/base case config size
---
--- If `config.persist_size = false` then option `2` in the
--- list is skipped.
--- @param size number
--- @param direction string
function M.get_size(size, direction)
  local config = require("toggleterm.config").get()
  local valid_size = size ~= nil and size > 0
  if not config.persist_size then
    return valid_size and size or config.size
  end
  return valid_size and size or persistent[direction] or config.size
end

--- Add terminal buffer specific options
--- @param win number
--- @param buf number
--- @param term Terminal
function M.set_options(win, buf, term)
  if term:is_split() then
    if term.direction == "horizontal" then
      vim.wo[win].winfixheight = true
    else
      vim.wo[win].winfixwidth = true
    end
  end
  vim.bo[buf].buflisted = false
  vim.bo[buf].filetype = constants.term_ft

  if require("toggleterm.config").get("hide_numbers") then
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
  end
  api.nvim_buf_set_var(buf, "toggle_number", term.id)
end

---apply highlights to a terminal
---@param term Terminal
function M.hl_term(term)
  local highlights
  local config = require("toggleterm.config")
  if term and term:is_float() or M.is_float() then
    local opts = term and term.float_opts or config.get("float_opts") or {}
    highlights = {
      fmt("NormalFloat:%s", opts.highlights.background),
      fmt("FloatBorder:%s", opts.highlights.border),
    }
  elseif config.get("shade_terminals") then
    highlights = {
      "Normal:DarkenedPanel",
      "EndOfBuffer:DarkenedPanel",
      "VertSplit:DarkenedPanel",
      "StatusLine:DarkenedStatusline",
      "StatusLineNC:DarkenedStatuslineNC",
      "SignColumn:DarkenedPanel",
    }
  end
  if highlights then
    vim.cmd("setlocal winhighlight=" .. table.concat(highlights, ","))
  end
end

---Create a terminal buffer with the correct buffer/window options
---then set it to current window
---@param term Terminal
---@return number, number
local function create_term_buf_if_needed(term)
  local valid_win = term.window and api.nvim_win_is_valid(term.window)
  local window = valid_win and term.window or api.nvim_get_current_win()
  -- If the buffer doesn't exist create a new one
  local valid_buf = term.bufnr and api.nvim_buf_is_valid(term.bufnr)
  local bufnr = valid_buf and term.bufnr or api.nvim_create_buf(false, false)

  M.set_options(window, bufnr, term)
  -- If the buffer didn't previously exist then assign it the window
  if not valid_buf then
    api.nvim_set_current_buf(bufnr)
    api.nvim_win_set_buf(window, bufnr)
  end
  term.window, term.bufnr = window, bufnr
end

function M.delete_buf(term)
  if api.nvim_buf_is_valid(term.bufnr) then
    api.nvim_buf_delete(term.bufnr, { force = true })
  end
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

function M.scroll_to_bottom()
  vim.cmd("normal! G")
end

function M.goto_previous()
  vim.cmd("wincmd p")
end

function M.stopinsert()
  vim.cmd("stopinsert!")
end

--- @param win_id number
--- @return boolean
function M.try_open(win_id)
  return fn.win_gotoid(win_id) > 0
end

--- Find the first open terminal window
--- by iterating all windows and matching the
--- containing buffers filetype with the passed in
--- comparator function or the default which matches
--- the filetype
--- @param comparator function
function M.find_open_windows(comparator)
  comparator = comparator
    or function(buf)
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

---Switch to the given buffer without changing the alternate
---@param buf number
function M.switch_buf(buf)
  -- don't change the alternate buffer so that <c-^><c-^> does nothing in the terminal split
  local cur_buf = api.nvim_get_current_buf()
  if cur_buf ~= buf then
    vim.cmd(fmt("keepalt buffer %d", buf))
  end
end

local split_commands = {
  horizontal = {
    existing = "rightbelow vsplit",
    new = "botright split",
    resize = "resize",
  },
  vertical = {
    existing = "rightbelow split",
    new = "botright vsplit",
    resize = "vertical resize",
  },
}

---Guess whether or not the window is a horizontal or vertical split
---this only works if either of the two are full size
function M.guess_direction()
  -- current window is full height vertical split
  -- NOTE: add one for tabline and one for status
  local ui_lines = (vim.o.tabline ~= "" and 1 or 0) + (vim.o.laststatus ~= 0 and 1 or 0)
  if api.nvim_win_get_height(0) + vim.o.cmdheight + ui_lines == vim.o.lines then
    return "vertical"
  end
  -- current window is full width horizontal split
  if api.nvim_win_get_width(0) == vim.o.columns then
    return "horizontal"
  end
  return nil
end

--- @private
--- @param size number|function
--- @param term Terminal
--- @return number?
function M._resolve_size(size, term)
  if not size then
    return
  elseif type(size) == "number" then
    return size
  elseif term and type(size) == "function" then
    return size(term)
  end
  utils.echomsg(string.format('The input %s is not of type "number" or "function".', size), "Error")
end

--- @param size number
--- @param term Terminal
function M.open_split(size, term)
  local has_open, win_ids = M.find_open_windows()
  local commands = split_commands[term.direction]
  local persist_size = require("toggleterm.config").get("persist_size")

  if has_open then
    -- we need to be in the terminal window most recently opened
    -- in order to split it
    local split_win = win_ids[#win_ids]
    if persist_size then
      M.save_window_size(term.direction, split_win)
    end
    api.nvim_set_current_win(split_win)
    vim.cmd(commands.existing)
  else
    vim.cmd(commands.new)
  end

  M.resize_split(term, size)
  create_term_buf_if_needed(term)
end

function M.open_window(term)
  create_term_buf_if_needed(term)
end

--- @param term Terminal
function M.open_tab(term)
  vim.cmd("tabnew")
  create_term_buf_if_needed(term)
end

---Close terminal window
---@param term Terminal
local function close_split(term)
  if api.nvim_win_is_valid(term.window) then
    local persist_size = require("toggleterm.config").get("persist_size")
    if persist_size then
      M.save_window_size(term.direction, term.window)
    end
    api.nvim_win_close(term.window, true)
  end
  if api.nvim_win_is_valid(origin_window) then
    api.nvim_set_current_win(origin_window)
  else
    origin_window = nil
  end
end

local function close_window()
  vim.cmd("keepalt b#")
end

local curved = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }

---Open a floating window
---@param term Terminal
function M.open_float(term)
  local opts = term.float_opts or {}
  local valid_buf = term.bufnr and api.nvim_buf_is_valid(term.bufnr)
  local buf = valid_buf and term.bufnr or api.nvim_create_buf(false, false)
  local width = M._resolve_size(opts.width, term)
    or math.ceil(math.min(vim.o.columns, math.max(80, vim.o.columns - 20)))
  local height = M._resolve_size(opts.height, term)
    or math.ceil(math.min(vim.o.lines, math.max(20, vim.o.lines - 10)))

  local border = opts.border == "curved" and curved or opts.border or "single"
  local win = api.nvim_open_win(buf, true, {
    row = (opts.row or math.ceil(vim.o.lines - height) / 2) - 1,
    col = (opts.col or math.ceil(vim.o.columns - width) / 2) - 1,
    relative = opts.relative or "editor",
    style = "minimal",
    width = width,
    height = height,
    border = border,
  })

  term.window, term.bufnr = win, buf

  if opts.winblend then
    vim.wo[win].winblend = opts.winblend
  end
  M.set_options(term.window, term.bufnr, term)
end

---Close given terminal's ui
---@param term Terminal
function M.close(term)
  if term:is_split() then
    close_split(term)
  elseif term.direction == "window" then
    close_window()
  else
    if api.nvim_win_is_valid(term.window) then
      api.nvim_win_close(term.window, true)
    end
  end
end

---Resize a split window
---@param term Terminal
---@param size number
function M.resize_split(term, size)
  size = M._resolve_size(M.get_size(size, term.direction), term)
  if require("toggleterm.config").get("persist_size") then
    M.save_direction_size(term.direction, size)
  end
  vim.cmd(split_commands[term.direction].resize .. " " .. size)
end

---Determine if a window is a float
---@param window number
function M.is_float(window)
  return fn.win_gettype(window) == "popup"
end

--- @param bufnr number
function M.find_windows_by_bufnr(bufnr)
  return fn.win_findbuf(bufnr)
end

---Return whether or not the terminal passed in has an open window
---@param term Terminal
---@return boolean
function M.term_has_open_win(term)
  if not term.window then
    return false
  end
  local open_wins = api.nvim_tabpage_list_wins(api.nvim_get_current_tabpage())
  return vim.tbl_contains(open_wins, term.window)
end

return M
