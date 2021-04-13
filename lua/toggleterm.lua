local api = vim.api
local fn = vim.fn
local fmt = string.format

local constants = require("toggleterm.constants")
local colors = require("toggleterm.colors")
local config = require("toggleterm.config")
local utils = require("toggleterm.utils")
local ui = require("toggleterm.ui")

local T = require("toggleterm.terminal")

---@type Terminal
local Terminal = T.Terminal
---@type Terminal[]
local terminals = T.terminals
---@type fun(id: integer, directory: string, direction: string): Terminal
local get_term = T.get_or_create_term
---@type fun(id: integer, term: Terminal, on_add: fun(term: Terminal, num: number)): Terminal,number
local set_term = T.add

local term_ft = constants.term_ft
local SHADING_AMOUNT = constants.shading_amount
-----------------------------------------------------------
-- Export
-----------------------------------------------------------
local M = {
  __set_highlights = colors.set_highlights
}

--- only shade explicitly specified filetypes
function M.__apply_colors()
  local ft = vim.bo.filetype

  if not vim.bo.filetype or vim.bo.filetype == "" then
    ft = "none"
  end

  local allow_list = config.get("shade_filetypes") or {}
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

local function parse_argument(str, result)
  local arg = vim.split(str, "=")
  if #arg > 1 then
    local key, value = arg[1], arg[2]
    if key == "size" then
      value = tonumber(value)
    elseif key == "cmd" then
      -- Remove quotes
      -- TODO: find a better way to do this
      value = string.sub(value, 2, #value - 1)
    end
    result[key] = value
  end
  return result
end

---Take a users command arguments in the format "cmd='git commit' dir=~/dotfiles"
---and parse this into a table of arguments
---{cmd = "git commit", dir = "~/dotfiles"}
---TODO: only the cmd argument can handle quotes!
---@param args string
---@return table<string, string>
local function parse_input(args)
  local result = {}
  if args then
    -- extract the quoted command then remove it from the rest of the argument string
    -- \v - very magic, reduce the amount of escaping needed
    -- \w+\= - match a word followed by an = sign
    -- ("([^"]*)"|'([^']*)') - match double or single quoted text
    -- @see: https://stackoverflow.com/a/5950910
    local regex = [[\v\w+\=%("([^"]*)"|'([^']*)')]]
    local quoted_arg = fn.matchstr(args, regex, "g")
    args = fn.substitute(args, regex, "", "g")
    parse_argument(quoted_arg, result)

    local parts = vim.split(args, " ")
    for _, part in ipairs(parts) do
      parse_argument(part, result)
    end
  end
  return result
end

local function setup_global_mappings()
  local conf = config.get()
  local mapping = conf.open_mapping
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
  if conf.insert_mappings then
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
end

--- @param bufnr number
local function find_windows_by_bufnr(bufnr)
  return fn.win_findbuf(bufnr)
end

--Create a new terminal or close beginning from the last opened
---@param _ number
---@param size number
---@param directory string
---@param direction string
local function smart_toggle(_, size, directory, direction)
  if not ui.find_open_windows() then
    get_term(1, directory, direction):open(size)
  else
    local target = #terminals
    -- count backwards from the end of the list
    for i = #terminals, 1, -1 do
      local term = terminals[i]
      if not term then
        utils.echomsg(fmt("Term does not exist %d", i))
        break
      end
      local wins = find_windows_by_bufnr(term.bufnr)
      if #wins > 0 then
        target = i
        break
      end
    end
    get_term(target):close()
  end
end

--- @param num number
--- @param size number
--- @param directory string
--- @param direction string
local function toggle_nth_term(num, size, directory, direction)
  local term = get_term(num, directory, direction)
  ui.update_origin_window(term.window)
  term:toggle(size)
end

function M.close_last_window()
  local buf = api.nvim_get_current_buf()
  local _, term = T.identify(api.nvim_buf_get_name(buf))
  local only_one_window = fn.winnr("$") == 1
  if only_one_window and vim.bo[buf].filetype == term_ft then
    if term:is_split() then
      term:close()
      vim.cmd("keepalt bnext")
    end
  end
end

function M.on_term_open()
  local id = T.identify(fn.bufname())
  set_term(
    id,
    Terminal:new {
      bufnr = api.nvim_get_current_buf(),
      window = api.nvim_get_current_win(),
      job_id = vim.b.terminal_job_id
    },
    function(term)
      term:__resurrect(term.window, term.bufnr)
    end
  )
end

function M.exec_command(args, count)
  vim.validate {args = {args, "string"}}
  if not args:match("cmd") then
    return utils.echomsg(
      "TermExec requires a cmd specified using the syntax cmd='ls -l' e.g. TermExec cmd='ls -l'",
      "ErrorMsg"
    )
  end
  local parsed = parse_input(args)
  vim.validate {
    cmd = {parsed.cmd, "string"},
    dir = {parsed.dir, "string", true},
    size = {parsed.size, "number", true}
  }
  M.exec(parsed.cmd, count, parsed.size, parsed.dir)
end

--- @param cmd string
--- @param num number
--- @param size number
function M.exec(cmd, num, size, dir)
  vim.validate {
    cmd = {cmd, "string"},
    num = {num, "number"},
    size = {size, "number", true}
  }
  -- count
  num = num < 1 and 1 or num
  local term, created = get_term(num, dir)
  if not term:is_open() then
    term:open(size)
  end
  if not created and dir then
    term:change_dir(dir)
  end
  term:send(cmd)
  vim.cmd("normal! G")
  vim.cmd("wincmd p")
  vim.cmd("stopinsert!")
end

function M.toggle_command(args, count)
  local parsed = parse_input(args)
  vim.validate {
    size = {parsed.size, "number", true},
    directory = {parsed.dir, "string", true},
    direction = {parsed.direction, "string", true}
  }
  if parsed.size then
    parsed.size = tonumber(parsed.size)
  end
  M.toggle(count, parsed.size, parsed.dir, parsed.direction)
end

--- If a count is provided we operate on the specific terminal buffer
--- i.e. 2ToggleTerm => open or close Term 2
--- if the count is 1 we use a heuristic which is as follows
--- if there is no open terminal window we toggle the first one i.e. assumed
--- to be the primary. However if several are open we close them.
--- this can be used with the count commands to allow specific operations
--- per term or mass actions
--- @param count number
--- @param size number
--- @param dir string
--- @param direction string
function M.toggle(count, size, dir, direction)
  vim.validate {
    count = {count, "number", true},
    size = {size, "number", true}
  }
  if count > 1 then
    toggle_nth_term(count, size, dir, direction)
  else
    smart_toggle(count, size, dir, direction)
  end
end

function M.setup(user_prefs)
  local conf = config.set(user_prefs)
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
  if conf.shade_terminals then
    local is_bright = colors.is_bright_background()

    -- if background is light then darken the terminal a lot more to increase contrast
    local factor =
      conf.shading_factor and type(conf.shading_factor) == "number" and conf.shading_factor or
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
  utils.create_augroups({ToggleTerminal = autocommands})
end

return M
