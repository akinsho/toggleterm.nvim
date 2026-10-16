local api = vim.api
local fn = vim.fn
local utils = require("toggleterm.utils")
local config = require("toggleterm.config")

local M = {}

---Extracts file path, line number, and column number under cursor or from a string
---@param line string?
---@param col number?
---@return string? file, number? lnum, number? colnr
function M.get_file_under_cursor(line, col)
  line = line or api.nvim_get_current_line()
  if not col then
    local cursor = api.nvim_win_get_cursor(0)
    col = cursor[2] + 1
  end

  local left = col
  while left > 1 and not line:sub(left - 1, left - 1):match('[%s"\'`()%[%]<>"]') do
    left = left - 1
  end

  local right = col
  while right <= #line and not line:sub(right, right):match('[%s"\'`()%[%]<>"]') do
    right = right + 1
  end
  right = right - 1

  if left > right then return nil end

  local token = line:sub(left, right):gsub("[,;:.]+$", "")

  -- Matcher file:line:col | file:line | file
  local file, lnum, colnr = token:match("^(.-):(%d+):(%d+)$")
  if not file then file, lnum = token:match("^(.-):(%d+)$") end
  if not file then file = token end

  -- Format Python (ex: File "foo.py", line 42)
  if not lnum then
    local py_line = line:match("line%s+(%d+)")
    if py_line then lnum = py_line end
  end

  file = file:gsub('^["\']', ""):gsub('["\']$', "")
  if file == "" then return nil end

  -- Clean git diff prefixes a/ or b/ if original file exists
  if fn.filereadable(file) ~= 1 and file:match("^[ab]/") then
    local stripped = file:sub(3)
    if fn.filereadable(stripped) == 1 then file = stripped end
  end

  return fn.expand(file), tonumber(lnum), tonumber(colnr)
end

---Close or hide the active terminal if requested
local function close_terminal_if_needed()
  local terms = require("toggleterm.terminal")
  local termid = terms.get_focused_id and terms.get_focused_id()
  if termid then
    local current_tt = terms.get(termid)
    if current_tt and current_tt:is_open() then
      current_tt:close()
      return
    end
  end

  local cur_buf = api.nvim_get_current_buf()
  local cur_win = api.nvim_get_current_win()
  for _, t in pairs(terms.get_all()) do
    if (t.bufnr == cur_buf or t.window == cur_win) and t:is_open() then
      t:close()
      return
    end
  end

  if api.nvim_win_is_valid(cur_win) then
    if api.nvim_win_get_config(cur_win).relative ~= "" then
      api.nvim_win_close(cur_win, false)
      return
    end
  end

  vim.cmd("hide")
end

---Open file under cursor from terminal
---@param opts? { force_split?: boolean, use_picker?: boolean, close_terminal?: boolean, split_direction?: "horizontal" | "vertical" }
function M.open_file(opts)
  opts = opts or {}
  local file, lnum, colnr = M.get_file_under_cursor()
  if not file or file == "" then
    utils.notify("No valid file path detected under cursor", "warn")
    return
  end

  local conf = config.get().navigation or {}
  local should_close = vim.F.if_nil(opts.close_terminal, conf.close_terminal)

  -- 1. Save previous window (wincmd p)
  local prev_winnr = fn.winnr("#")
  local prev_winid = prev_winnr > 0 and fn.win_getid(prev_winnr) or nil

  -- 2. Close / hide terminal if requested
  if should_close then close_terminal_if_needed() end

  -- 3. Select target window
  local target_win = nil
  local use_picker = vim.F.if_nil(opts.use_picker, conf.use_picker)
  local ok_wp, picker = pcall(require, "window-picker")

  if use_picker and ok_wp then
    target_win = picker.pick_window({
      autoselect_one = true,
      include_current_win = true,
      filter_rules = {
        bo = {
          buftype = { "terminal", "quickfix", "nofile" },
          filetype = { "NvimTree", "neo-tree", "notify", "toggleterm" },
        },
      },
    })
  end

  if not target_win or not api.nvim_win_is_valid(target_win) then
    if prev_winid and api.nvim_win_is_valid(prev_winid) then
      target_win = prev_winid
    else
      target_win = api.nvim_get_current_win()
    end
  end

  api.nvim_set_current_win(target_win)

  -- 4. Open split if requested or if buffer is modified
  local current_buf = api.nvim_win_get_buf(target_win)
  local is_modified = vim.bo[current_buf].modified

  if opts.force_split or is_modified then
    local split_direction = opts.split_direction or conf.split_direction or "vertical"
    local split_cmd = split_direction == "horizontal" and "split" or "vsplit"
    vim.cmd(split_cmd)
  end

  -- 5. Open file
  vim.cmd.edit(fn.fnameescape(file))

  -- 6. Jump to line and col
  if lnum then
    local max_line = api.nvim_buf_line_count(0)
    local target_line = math.min(lnum, max_line)
    local target_col = math.max(0, (colnr or 1) - 1)
    pcall(api.nvim_win_set_cursor, 0, { target_line, target_col })
    vim.cmd("normal! zz")
  end
end

---Setup buffer-local navigation keymaps
---@param bufnr number
---@param nav_conf FileNavigationOpts?
function M.setup_terminal_mappings(bufnr, nav_conf)
  if not nav_conf or not nav_conf.enabled then return end

  if nav_conf.open_mapping then
    utils.key_map("n", nav_conf.open_mapping, function()
      M.open_file({ force_split = false, use_picker = nav_conf.use_picker })
    end, { buffer = bufnr, desc = "ToggleTerm: open file under cursor", silent = true })
  end

  if nav_conf.split_mapping then
    utils.key_map("n", nav_conf.split_mapping, function()
      M.open_file({
        force_split = true,
        use_picker = nav_conf.use_picker,
        split_direction = nav_conf.split_direction,
      })
    end, { buffer = bufnr, desc = "ToggleTerm: open file under cursor in split", silent = true })
  end

  if nav_conf.direct_mapping then
    utils.key_map("n", nav_conf.direct_mapping, function()
      M.open_file({ force_split = false, use_picker = false })
    end, { buffer = bufnr, desc = "ToggleTerm: open file directly in previous window", silent = true })
  end
end

return M
