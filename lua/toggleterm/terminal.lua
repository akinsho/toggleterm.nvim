local M = {}

local ui = require("toggleterm.ui")
local config = require("toggleterm.config")
local utils = require("toggleterm.utils")
local term_ft = require("toggleterm.constants").term_ft

local api = vim.api
local fmt = string.format
local fn = vim.fn

local is_windows = fn.has("win32") == 1
local function is_cmd()
  local shell = config.get("shell")
  return string.find(shell, "cmd")
end

local function is_pwsh()
  local shell = config.get("shell")
  return string.find(shell, "pwsh") or string.find(shell, "powershell")
end

local function get_command_sep()
  return is_windows and is_cmd() and "&" or ";"
end

local function get_comment_sep()
  return is_windows and is_cmd() and "::" or "#"
end

local function get_newline_chr()
  return is_windows and (is_pwsh() and "\r" or "\r\n") or "\n"
end

---@type Terminal[]
local terminals = {}

--- @class Terminal
--- @field cmd string
--- @field direction string the layout style for the terminal
--- @field id number
--- @field bufnr number
--- @field window number
--- @field job_id number
--- @field dir string the directory for the terminal
--- @field name string the name of the terminal
--- @field count number the count that triggers that specific terminal
--- @field hidden boolean whether or not to include this terminal in the terminals list
--- @field close_on_exit boolean whether or not to close the terminal window when the process exits
--- @field float_opts table<string, any>
--- @field on_stdout fun(t: Terminal, job: number, data: string[], name: string)
--- @field on_stderr fun(t: Terminal, job: number, data: string[], name: string)
--- @field on_exit fun(t: Terminal, job: number, exit_code: number, name: string)
--- @field on_open fun(term:Terminal)
--- @field on_close fun(term:Terminal)
local Terminal = {}

---@type number[]
local ids = {}

---@private
--- Get the next available id based on the next number in the sequence that
--- hasn't already been allocated e.g. in a list of {1,2,5,6} the next id should
--- be 3 then 4 then 7
---@return integer
local function next_id()
  local next_to_use = #ids + 1
  local next_index = #ids + 1
  for index, id in ipairs(ids) do
    if id ~= index then
      next_to_use = index
      next_index = index
    end
  end
  table.insert(ids, next_index, next_to_use)
  return next_to_use
end

--- remove the passed id from the list of available ids
---@param num number
local function decrement_id(num)
  ids = vim.tbl_filter(function(id)
    return id ~= num
  end, ids)
end

---Get an opened (valid) toggle terminal by id, defaults to the first opened
---@param position number
---@return nil
function M.get_toggled_id(position)
  position = position or 1
  local t = M.get_all()
  return t[position] and t[position].id or nil
end

--- @param bufnr number
local function setup_buffer_mappings(bufnr)
  local conf = config.get()
  local mapping = conf.open_mapping
  if mapping and conf.terminal_mappings then
    api.nvim_buf_set_keymap(bufnr, "t", mapping, "<Cmd>ToggleTerm<CR>", {
      silent = true,
      noremap = true,
    })
  end
end

---Terminal buffer autocommands
---@param term Terminal
local function setup_buffer_autocommands(term)
  local conf = config.get()
  local commands = {
    {
      "TermClose",
      fmt("<buffer=%d>", term.bufnr),
      fmt('lua require"toggleterm.terminal".delete(%d)', term.id),
    },
    term:is_float() and {
      "VimResized",
      fmt("<buffer=%d>", term.bufnr),
      fmt('lua require"toggleterm.terminal".__on_vim_resized(%d)', term.id),
    } or nil,
  }

  if conf.start_in_insert then
    vim.cmd("startinsert")
    table.insert(commands, {
      "BufEnter",
      fmt("<buffer=%d>", term.bufnr),
      "startinsert",
    })
  end

  utils.create_augroups({ ["ToggleTerm" .. term.bufnr] = commands })
end

---get the directory for the terminal parsing special arguments
---@param dir string
---@return string
local function _get_dir(dir)
  if dir == "git_dir" then
    dir = require("toggleterm.utils").git_dir()
  end
  if dir then
    return vim.fn.expand(dir)
  else
    return vim.loop.cwd()
  end
end

---Create a new terminal object
---@param term Terminal
---@return Terminal
function Terminal:new(term)
  term = term or {}
  --- If we try to create a new terminal, but the id is already
  --- taken, return the terminal with the containing id
  local id = term.count or term.id
  if id and terminals[id] then
    return terminals[id]
  end
  local conf = config.get()
  self.__index = self
  term.direction = term.direction or conf.direction
  -- HACK: temporarily re-assign window layout to "tab" whilst user's migrate
  -- 15/09/2021 -> remove 7-10 days from now
  term.direction = term.direction == "window" and "tab" or term.direction
  term.id = id or next_id()
  term.hidden = term.hidden or false
  term.float_opts = vim.tbl_deep_extend("keep", term.float_opts or {}, conf.float_opts)
  term.on_open = term.on_open or conf.on_open
  term.on_close = term.on_close or conf.on_close
  term.on_stdout = term.on_stdout or conf.on_stdout
  term.on_stderr = term.on_stderr or conf.on_stderr
  term.on_exit = term.on_exit or conf.on_exit
  if term.close_on_exit == nil then
    term.close_on_exit = conf.close_on_exit
  end
  -- Add the newly created terminal to the list of all terminals
  return setmetatable(term, self)
end

---@private
---Add a terminal to the list of terminals
function Terminal:__add()
  if not terminals[self.id] then
    terminals[self.id] = self
  end
  return self
end

function Terminal:is_float()
  return self.direction == "float" and ui.is_float(self.window)
end

function Terminal:is_split()
  return (self.direction == "vertical" or self.direction == "horizontal")
    and not ui.is_float(self.window)
end

function Terminal:resize(size)
  if self:is_split() then
    ui.resize_split(self, size)
  end
end

function Terminal:is_open()
  if not self.window then
    return false
  end
  local win_type = fn.win_gettype(self.window)
  -- empty string window type corresponds to a normal window
  local win_open = win_type == "" or win_type == "popup"
  return win_open and api.nvim_win_get_buf(self.window) == self.bufnr
end

function Terminal:close()
  if self.on_close then
    self:on_close()
  end
  ui.close(self)
  ui.stopinsert()
  ui.update_origin_window(self.window)
end

function Terminal:shutdown()
  if self:is_open() then
    self:close()
  end
  ui.delete_buf(self)
end

---Combine arguments into strings separated by new lines
---@vararg string
---@return string
local function with_cr(...)
  local result = {}
  local newline_chr = get_newline_chr()
  for _, str in ipairs({ ... }) do
    table.insert(result, str .. newline_chr)
  end
  return table.concat(result, "")
end

---Send a command to a running terminal
---@param cmd string|string[]
---@param go_back boolean whether or not to return to original window
function Terminal:send(cmd, go_back)
  cmd = type(cmd) == "table" and with_cr(unpack(cmd)) or with_cr(cmd)
  fn.chansend(self.job_id, cmd)
  if go_back then
    ui.scroll_to_bottom()
    ui.goto_previous()
    ui.stopinsert()
  end
end

function Terminal:clear()
  self:send("clear")
end

---Update the directory of an already opened terminal
---@param dir string
function Terminal:change_dir(dir)
  dir = _get_dir(dir)
  if self.dir ~= dir then
    self:send({ fmt("cd %s", dir), "clear" })
  end
end

---Update the direction of an already opened terminal
---@param direction string
function Terminal:change_direction(direction)
  self.direction = direction
  self.window = nil
end

--- Handle when a terminal process exits
---@param term Terminal
local function __handle_exit(term)
  return function(...)
    if term.on_exit then
      term:on_exit(...)
    end
    if term.close_on_exit then
      term:close()
      if api.nvim_buf_is_loaded(term.bufnr) then
        api.nvim_buf_delete(term.bufnr, { force = true })
      end
    end
  end
end

---@private
---Pass self as first parameter to callback
function Terminal:__stdout()
  if self.on_stdout then
    return function(...)
      self.on_stdout(self, ...)
    end
  end
end

---@private
---Pass self as first parameter to callback
function Terminal:__stderr()
  if self.on_stderr then
    return function(...)
      self.on_stderr(self, ...)
    end
  end
end

---@private
function Terminal:__spawn()
  local cmd = self.cmd or config.get("shell")
  local command_sep = get_command_sep()
  local comment_sep = get_comment_sep()
  cmd = table.concat({
    cmd,
    command_sep,
    comment_sep,
    term_ft,
    comment_sep,
    self.id,
  })
  self.job_id = fn.termopen(cmd, {
    detach = 1,
    cwd = _get_dir(self.dir),
    on_exit = __handle_exit(self),
    on_stdout = self:__stdout(),
    on_stderr = self:__stderr(),
  })
  self.name = cmd
end

---@private
---Add an orphaned terminal to the list of terminal and re-apply settings
function Terminal:__resurrect()
  self:__add()
  if self:is_split() then
    ui.resize_split(self)
  end
  -- set the window options including fixing height or width once the window is resized
  ui.set_options(self.window, self.bufnr, self)
  ui.hl_term(self)
end

---Open a terminal in a type of window i.e. a split,full window or tab
---@param size number
---@param term table
local function opener(size, term)
  local direction = term.direction
  if term:is_split() then
    ui.open_split(size, term)
  elseif direction == "tab" then
    ui.open_tab(term)
  elseif direction == "float" then
    ui.open_float(term)
  else
    error("Invalid terminal direction")
  end
end

---Open a terminal window
---@param size number
---@param direction string
---@param is_new boolean
function Terminal:open(size, direction, is_new)
  self.dir = _get_dir(self.dir)
  ui.set_origin_window()
  if direction then
    self:change_direction(direction)
  end
  if fn.bufexists(self.bufnr) == 0 then
    local ok, err = pcall(opener, size, self)
    if not ok then
      return utils.notify(err, "error")
    end
    self:__add()
    self:__spawn()
    setup_buffer_autocommands(self)
    setup_buffer_mappings(self.bufnr)
  else
    local ok, err = pcall(opener, size, self)
    if not ok then
      return utils.notify(err, "error")
    end
    ui.switch_buf(self.bufnr)
    if not is_new then
      self:change_dir(self.dir)
    end
  end
  ui.hl_term(self)
  -- NOTE: it is important that this function is called at this point. i.e. the buffer has been correctly assigned
  if self.on_open then
    self:on_open()
  end
end

---Open if closed and close if opened
---@param size number
---@param direction string
function Terminal:toggle(size, direction)
  if self:is_open() then
    self:close()
  else
    self:open(size, direction)
  end
  return self
end

---@private
---@param id number terminal id
function M.__on_vim_resized(id)
  local term = M.get(id)
  if not term or not term:is_float() or not term:is_open() then
    return
  end
  ui.update_float(term)
end

--- get the toggle term number from
--- the name e.g. term://~/.dotfiles//3371887:/usr/bin/zsh;#toggleterm#1
--- the number in this case is 1
--- @param name string
--- @return number
function M.identify(name)
  name = name or api.nvim_buf_get_name(api.nvim_get_current_buf())
  local comment_sep = get_comment_sep()
  local parts = vim.split(name, comment_sep)
  local id = tonumber(parts[#parts])
  return id, terminals[id]
end

--- Remove the in memory reference to the no longer open terminal
--- @param num string
function M.delete(num)
  if terminals[num] then
    decrement_id(num)
    terminals[num] = nil
  end
end

---get existing terminal or create an empty term table
---@param num number
---@param dir string
---@param direction string
---@return Terminal
---@return boolean
function M.get_or_create_term(num, dir, direction)
  local term = M.get(num)
  if term then
    return term, false
  end
  return Terminal:new({ id = num, dir = dir, direction = direction }), true
end

---Get a single terminal by id, unless it is hidden
---@param id number
---@return Terminal
function M.get(id)
  local term = terminals[id]
  return (term and not term.hidden) and term or nil
end

---Return the potentially non contiguous map of terminals as a sorted array
---@param include_hidden boolean whether or nor to filter out hidden
---@return Terminal[]
function M.get_all(include_hidden)
  local result = {}
  for _, v in pairs(terminals) do
    if include_hidden or (not include_hidden and not v.hidden) then
      table.insert(result, v)
    end
  end
  table.sort(result, function(a, b)
    return a.id < b.id
  end)
  return result
end

if _G.IS_TEST then
  ---@private
  function M.__reset()
    for _, term in pairs(terminals) do
      term:shutdown()
      M.delete(term.id)
    end
    ids = {}
  end

  ---@private
  ---@param tbl number[]
  function M.__set_ids(tbl)
    ids = tbl
  end

  M.__next_id = next_id
end

M.Terminal = Terminal

return M
