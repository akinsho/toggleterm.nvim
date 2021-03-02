local api = vim.api
local fn = vim.fn
local colors = require("toggleterm/colors")
-----------------------------------------------------------
-- Export
-----------------------------------------------------------
local M = {
  __set_highlights = colors.set_highlights
}

-----------------------------------------------------------
-- Constants
-----------------------------------------------------------
local term_ft = "toggleterm"
-- -30 is a magic number based on manual testing of what looks good
local SHADING_AMOUNT = -30

local preferences = {
  size = 12,
  shade_filetypes = {},
  shade_terminals = true,
  start_in_insert = true,
  persist_size = true,
  direction = "horizontal",
  shading_factor = nil
}

-----------------------------------------------------------
-- State
-----------------------------------------------------------
local terminals = {}
local persistent = {}
local origin_win

function M.save_window_size()
  -- Save the size of the split before it is hidden
  persistent.width = vim.fn.winwidth(0)
  persistent.height = vim.fn.winheight(0)
end

--- Get the size of the split. Order of priority is as follows:
---   1. The size argument is a valid number > 0
---   2. There is persistent width/height information from prev open state
---   3. Default/base case perference size
---
--- If `preferences.persist_size = false` then option `2` in the
--- list is skipped.
--- @param size number
local function get_size(size)
  local valid_size = size ~= nil and size > 0
  if not preferences.persist_size then
    return valid_size and size or preferences.size
  end

  local psize = preferences.direction == "horizontal" and persistent.height or persistent.width
  return valid_size and size or psize or preferences.size
end

local function create_term()
  local no_of_terms = #terminals
  local next_num = no_of_terms == 0 and 1 or no_of_terms + 1
  return {
    window = -1,
    job_id = -1,
    bufnr = -1,
    dir = fn.getcwd(),
    number = next_num
  }
end

local function parse_args(args)
  local result = {}
  if args then
    local parts = vim.split(args, " ")
    for _, part in pairs(parts) do
      local arg = vim.split(part, "=")
      if #arg > 1 then
        result[arg[1]] = arg[2]
      end
    end
  end
  return result
end

--- Source: https://teukka.tech/luanvim.html
--- @param definitions table<string,table>
local function create_augroups(definitions)
  for group_name, definition in pairs(definitions) do
    vim.cmd("augroup " .. group_name)
    vim.cmd("autocmd!")
    for _, def in pairs(definition) do
      local command = table.concat(vim.tbl_flatten {"autocmd", def}, " ")
      vim.cmd(command)
    end
    vim.cmd("augroup END")
  end
end

--- @param win_id number
local function find_window(win_id)
  return fn.win_gotoid(win_id) > 0
end

--- get existing terminal or create an empty term table
--- @param num number
local function find_term(num)
  return terminals[num] or create_term()
end

--- get the toggle term number from
--- the name e.g. term://~/.dotfiles//3371887:/usr/bin/zsh;#toggleterm#1
--- the number in this case is 1
--- @param name string
local function get_number_from_name(name)
  local parts = vim.split(name, "#")
  local num = tonumber(parts[#parts])
  return num
end

--- Find the first open terminal window
--- by iterating all windows and matching the
--- containing buffers filetype with the passed in
--- comparator function or the default which matches
--- the filetype
--- @param comparator function
local function find_open_windows(comparator)
  comparator = comparator or function(buf)
      return vim.bo[buf].filetype == term_ft
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

--- Add terminal buffer specific options
--- @param num number
--- @param bufnr number
--- @param win_id number
local function set_opts(num, bufnr, win_id)
  vim.wo[win_id].winfixheight = true
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].filetype = term_ft
  api.nvim_buf_set_var(bufnr, "toggle_number", num)
end

local function resize(size)
  local cmd = preferences.direction == "vertical" and "vertical resize" or "resize"

  vim.cmd(cmd .. " " .. size)
end

--- @param size number
local function open_split(size)
  size = get_size(size)

  local has_open, win_ids = find_open_windows()
  local commands =
    preferences.direction == "horizontal" and
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
    fn.win_gotoid(win_ids[#win_ids])
    vim.cmd(commands[1])
  else
    vim.cmd(size .. commands[2])
    -- move horizontal split to the bottom
    vim.cmd(commands[3])
  end
  resize(size)
end

--- @param bufnr number
local function setup_buffer_mappings(bufnr)
  local mapping = preferences.open_mapping
  if mapping then
    api.nvim_buf_set_keymap(
      bufnr,
      "t",
      mapping,
      '<C-\\><C-n>:exe v:count1 . "ToggleTerm"<CR>',
      {
        silent = true,
        noremap = true
      }
    )
  end
end

local function setup_global_mappings()
  local mapping = preferences.open_mapping
  -- v:count1 defaults the count to 1 but if a count is passed in uses that instead
  -- <c-u> allows passing along the count
  api.nvim_set_keymap(
    "n",
    mapping,
    ':<c-u>exe v:count1 . "ToggleTerm"<CR>',
    {
      silent = true,
      noremap = true
    }
  )
  api.nvim_set_keymap(
    "i",
    mapping,
    '<Esc>:<c-u>exe v:count1 . "ToggleTerm"<CR>',
    {
      silent = true,
      noremap = true
    }
  )
end

local function update_origin_win(term_window)
  local curr_win = api.nvim_get_current_win()
  if term_window ~= curr_win then
    origin_win = curr_win
  end
end

--- @param bufnr number
local function find_windows_by_bufnr(bufnr)
  return fn.win_findbuf(bufnr)
end

--Create a new terminal or close beginning from the last opened
---@param _ number
---@param size number
---@param directory string
local function smart_toggle(_, size, directory)
  local already_open = find_open_windows()
  if not already_open then
    M.open(1, size, directory)
  else
    local target = #terminals
    -- count backwards from the end of the list
    for i = #terminals, 1, -1 do
      local term = terminals[i]
      if not term then
        vim.cmd(string.format('echomsg "Term does not exist %s"', vim.inspect(term)))
        break
      end
      local wins = find_windows_by_bufnr(term.bufnr)
      if #wins > 0 then
        target = i
        break
      end
    end
    M.close(target)
  end
end

--- @param num number
--- @param size number
local function toggle_nth_term(num, size, directory)
  local term = find_term(num)

  update_origin_win(term.window)

  if find_window(term.window) then
    M.close(num)
  else
    M.open(num, size, directory)
  end
end

function M.close_last_window()
  local buf = api.nvim_get_current_buf()
  local only_one_window = fn.winnr("$") == 1
  if only_one_window and vim.bo[buf].filetype == term_ft then
    -- Reset the window id so there are no hanging
    -- references to the terminal window
    for _, term in pairs(terminals) do
      if term.bufnr == buf then
        term.window = -1
        break
      end
    end
    -- FIXME switching causes the buffer
    -- switched to to have no highlighting
    -- no idea why
    vim.cmd("keepalt bnext")
  end
end

function M.on_term_open()
  local title = fn.bufname()
  local num = get_number_from_name(title)
  if not terminals[num] then
    local term = create_term()
    term.bufnr = fn.bufnr()
    term.window = fn.win_getid()
    term.job_id = vim.b.terminal_job_id
    terminals[num] = term

    resize(get_size())
    set_opts(num, term.bufnr, term.window)
  end
end

--- Remove the in memory reference to the no longer open terminal
--- @param num string
function M.delete(num)
  if terminals[num] then
    terminals[num] = nil
  end
end

--- @param num number
--- @param size number
function M.open(num, size, directory)
  directory = directory and vim.fn.expand(directory) or fn.getcwd()
  vim.validate {
    num = {num, "number"},
    size = {size, "number", true},
    directory = {directory, "string", true}
  }

  local term = find_term(num)
  origin_win = api.nvim_get_current_win()

  if vim.fn.bufexists(term.bufnr) == 0 then
    open_split(size)
    term.window = fn.win_getid()
    term.bufnr = api.nvim_create_buf(false, false)

    api.nvim_set_current_buf(term.bufnr)
    api.nvim_win_set_buf(term.window, term.bufnr)

    local name = vim.o.shell .. ";#" .. term_ft .. "#" .. num
    term.job_id = fn.termopen(name, {detach = 1, cwd = directory})

    local commands = {
      {
        "TermClose",
        string.format("<buffer=%d>", term.bufnr),
        string.format('lua require"toggleterm".delete(%d)', num)
      }
    }
    if preferences.start_in_insert then
      vim.cmd("startinsert!")
      table.insert(
        commands,
        {
          "BufEnter",
          "<buffer>",
          "startinsert!"
        }
      )
    end
    if preferences.persist_size then
      table.insert(
        commands,
        {
          "CursorHold",
          string.format("<buffer=%d>", term.bufnr),
          "lua require'toggleterm'.save_window_size()"
        }
      )
    end
    create_augroups({["ToggleTerm" .. term.bufnr] = commands})
    setup_buffer_mappings(term.bufnr)
    terminals[num] = term
  else
    open_split(size)
    vim.cmd("keepalt buffer " .. term.bufnr)
    vim.wo.winfixheight = true
    term.window = fn.win_getid()
  end
end

--- @param args string
function M.exec(args)
  vim.validate {args = {args, "string"}}
  local num = vim.v.count
  local parsed = parse_args(args)
  vim.validate {
    cmd = {parsed.cmd, "string"},
    dir = {parsed.dir, "string", true},
  }
  -- count
  num = num < 1 and 1 or num
  local term = find_term(num)
  if not find_window(term.window) then
    M.open(num, parsed.size, parsed.dir)
  end
  term = find_term(num)
  fn.chansend(term.job_id, "clear" .. "\n" .. parsed.cmd .. "\n")
  vim.cmd("normal! G")
  vim.cmd("wincmd p")
  vim.cmd("stopinsert!")
end

--- @param num number
function M.close(num)
  local term = find_term(num)

  update_origin_win(term.window)

  if find_window(term.window) then
    M.save_window_size()

    vim.cmd("hide")

    if api.nvim_win_is_valid(origin_win) then
      api.nvim_set_current_win(origin_win)
    else
      origin_win = nil
    end

    vim.cmd("stopinsert!")
  else
    if num then
      vim.cmd(string.format('echoerr "Failed to close window: %d does not exist"', num))
    else
      vim.cmd('echoerr "Failed to close window: invalid term number"')
    end
  end
end

--- only shade explicitly specified filetypes
function M.__apply_colors()
  local ft = vim.bo.filetype

  if not vim.bo.filetype or vim.bo.filetype == "" then
    ft = "none"
  end

  local allow_list = preferences.shade_filetypes or {}
  table.insert(allow_list, term_ft)

  local is_enabled_ft = false
  for _, filetype in ipairs(allow_list) do
    if ft == filetype then
      is_enabled_ft = true
      break
    end
  end
  if vim.bo.buftype == "terminal" and is_enabled_ft then
    colors.darken_terminal()
  end
end

--- If a count is provided we operate on the specific terminal buffer
--- i.e. 2ToggleTerm => open or close Term 2
--- if the count is 1 we use a heuristic which is as follows
--- if there is no open terminal window we toggle the first one i.e. assumed
--- to be the primary. However if several are open we close them.
--- this can be used with the count commands to allow specific operations
--- per term or mass actions
--- @param args string
function M.toggle(args)
  local count = vim.v.count < 1 and 1 or vim.v.count
  local parsed = parse_args(args)
  vim.validate {
    size = {parsed.size, "string", true},
    directory = {parsed.dir, "string", true}
  }
  if parsed.size then
    parsed.size = tonumber(parsed.size)
  end
  if count > 1 then
    toggle_nth_term(count, parsed.size, parsed.dir)
  else
    smart_toggle(count, parsed.size, parsed.dir)
  end
end

function M.setup(user_prefs)
  if user_prefs then
    preferences = vim.tbl_deep_extend("force", preferences, user_prefs)
  end
  setup_global_mappings()
  local autocommands = {
    {
      "BufEnter",
      "term://*toggleterm#*",
      "nested",
      "lua require'toggleterm'.close_last_window()"
    },
    {
      "TermOpen",
      "term://*toggleterm#*",
      "lua require'toggleterm'.on_term_open()"
    }
  }
  if preferences.shade_terminals then
    local is_bright = colors.is_bright_background()

    -- if background is light then darken the terminal a lot more to increase contrast
    local factor =
      preferences.shading_factor and type(preferences.shading_factor) == "number" and
      preferences.shading_factor or
      (is_bright and 3 or 1)

    local amount = factor * SHADING_AMOUNT
    colors.set_highlights(amount)

    vim.list_extend(
      autocommands,
      {
        {
          -- call set highlights once on vim start
          -- as this plugin might not be initialised till
          -- after the colorscheme autocommand has fired
          -- reapply highlights when the colorscheme
          -- is re-applied
          "ColorScheme",
          "*",
          string.format("lua require'toggleterm'.__set_highlights(%d)", amount)
        },
        {
          "TermOpen",
          "term://*zsh*,term://*bash*,term://*toggleterm#*",
          "lua require('toggleterm').__apply_colors()"
        }
      }
    )
  end
  create_augroups({ToggleTerminal = autocommands})
end

--- FIXME this shows a cached version of the terminals
function M.introspect()
  print("All terminals: " .. vim.inspect(terminals))
end

return M
