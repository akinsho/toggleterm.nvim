local M = {}

local lazy = require("toggleterm.lazy")
---@module "toggleterm.ui"
local ui = lazy.require("toggleterm.ui")
---@module "toggleterm.config"
local config = lazy.require("toggleterm.config")
---@module "toggleterm.utils"
local utils = lazy.require("toggleterm.utils")
---@module "toggleterm.constants"
local constants = lazy.require("toggleterm.constants")

local api = vim.api
local fmt = string.format
local fn = vim.fn

local mode = {
  INSERT = "i",
  NORMAL = "n",
  UNSUPPORTED = "?",
}

local AUGROUP = api.nvim_create_augroup("ToggleTermBuffer", { clear = true })

local is_windows = fn.has("win32") == 1
local function is_cmd(shell) return shell:find("cmd") end

local function is_pwsh(shell) return shell:find("pwsh") or shell:find("powershell") end

local function get_command_sep() return is_windows and is_cmd(vim.o.shell) and "&" or ";" end

local function get_comment_sep() return is_windows and is_cmd(vim.o.shell) and "::" or "#" end

local function get_newline_chr()
  local shell = config.get("shell")
  return is_windows and (is_pwsh(shell) and "\r" or "\r\n") or "\n"
end

---@alias Mode "n" | "i" | "?"

--- @class TerminalState
--- @field mode Mode

---@type Terminal[]
local terminals = {}

--- @class TermCreateArgs
--- @field cmd string
--- @field direction? string the layout style for the terminal
--- @field id number?
--- @field highlights table<string, table<string, string>>?
--- @field dir string? the directory for the terminal
--- @field count number? the count that triggers that specific terminal
--- @field display_name string?
--- @field hidden boolean? whether or not to include this terminal in the terminals list
--- @field close_on_exit boolean? whether or not to close the terminal window when the process exits
--- @field auto_scroll boolean? whether or not to scroll down on terminal output
--- @field float_opts table<string, any>?
--- @field on_stdout fun(t: Terminal, job: number, data: string[]?, name: string?)?
--- @field on_stderr fun(t: Terminal, job: number, data: string[], name: string)?
--- @field on_exit fun(t: Terminal, job: number, exit_code: number?, name: string?)?
--- @field on_create fun(term:Terminal)?
--- @field on_open fun(term:Terminal)?
--- @field on_close fun(term:Terminal)?

--- @class Terminal
--- @field cmd string
--- @field direction string the layout style for the terminal
--- @field id number
--- @field bufnr number
--- @field window number
--- @field job_id number
--- @field highlights table<string, table<string, string>>
--- @field dir string the directory for the terminal
--- @field name string the name of the terminal
--- @field count number the count that triggers that specific terminal
--- @field hidden boolean whether or not to include this terminal in the terminals list
--- @field close_on_exit boolean? whether or not to close the terminal window when the process exits
--- @field auto_scroll boolean? whether or not to scroll down on terminal output
--- @field float_opts table<string, any>?
--- @field display_name string?
--- @field env table<string, string> environmental variables passed to jobstart()
--- @field clear_env boolean use clean job environment, passed to jobstart()
--- @field on_stdout fun(t: Terminal, job: number, data: string[]?, name: string?)?
--- @field on_stderr fun(t: Terminal, job: number, data: string[], name: string)?
--- @field on_exit fun(t: Terminal, job: number, exit_code: number?, name: string?)?
--- @field on_create fun(term:Terminal)?
--- @field on_open fun(term:Terminal)?
--- @field on_close fun(term:Terminal)?
--- @field _display_name fun(term: Terminal): string
--- @field __state TerminalState
local Terminal = {}

---@private
--- Get the next available id based on the next number in the sequence that
--- hasn't already been allocated e.g. in a list of {1,2,5,6} the next id should
--- be 3 then 4 then 7
---@return integer
local function next_id()
  local all = M.get_all(true)
  for index, term in pairs(all) do
    if index ~= term.id then return index end
  end
  return #all + 1
end

---Get an opened (valid) toggle terminal by id, defaults to the first opened
---@param position number?
---@return number?
function M.get_toggled_id(position)
  position = position or 1
  local t = M.get_all()
  return t[position] and t[position].id or nil
end

--- @param bufnr number
local function setup_buffer_mappings(bufnr)
  local mapping = config.open_mapping
  if mapping and config.terminal_mappings then
    vim.keymap.set("t", mapping, "<Cmd>ToggleTerm<CR>", { buffer = bufnr, silent = true })
  end
end

---@private
---@param id number terminal id
local function on_vim_resized(id)
  local term = M.get(id)
  if not term or not term:is_float() or not term:is_open() then return end
  ui.update_float(term)
end

--- Remove the in memory reference to the no longer open terminal
--- @param num number
local function delete(num)
  if terminals[num] then terminals[num] = nil end
end

---Terminal buffer autocommands
---@param term Terminal
local function setup_buffer_autocommands(term)
  local conf = config.get()
  api.nvim_create_autocmd("TermClose", {
    buffer = term.bufnr,
    group = AUGROUP,
    callback = function() delete(term.id) end,
  })
  if term:is_float() then
    api.nvim_create_autocmd("VimResized", {
      buffer = term.bufnr,
      group = AUGROUP,
      callback = function() on_vim_resized(term.id) end,
    })
  end

  if conf.start_in_insert then
    -- Avoid entering insert mode when spawning terminal in the background
    if term.window == api.nvim_get_current_win() then vim.cmd("startinsert") end
  end
end

---get the directory for the terminal parsing special arguments
---@param dir string?
---@return string
local function _get_dir(dir)
  if dir == "git_dir" then dir = utils.git_dir() end
  if dir then
    return fn.expand(dir)
  else
    return vim.loop.cwd()
  end
end

---Create a new terminal object
---@param term TermCreateArgs?
---@return Terminal
function Terminal:new(term)
  term = term or {}
  --- If we try to create a new terminal, but the id is already
  --- taken, return the terminal with the containing id
  local id = term.count or term.id
  if id and terminals[id] then return terminals[id] end
  local conf = config.get()
  self.__index = self
  term.direction = term.direction or conf.direction
  term.id = id or next_id()
  term.float_opts = vim.tbl_deep_extend("keep", term.float_opts or {}, conf.float_opts)
  term.clear_env = term.clear_env
  term.auto_scroll = vim.F.if_nil(term.auto_scroll, conf.auto_scroll)
  term.env = vim.F.if_nil(term.env, conf.env)
  term.hidden = vim.F.if_nil(term.hidden, false)
  term.on_create = vim.F.if_nil(term.on_create, conf.on_create)
  term.on_open = vim.F.if_nil(term.on_open, conf.on_open)
  term.on_close = vim.F.if_nil(term.on_close, conf.on_close)
  term.on_stdout = vim.F.if_nil(term.on_stdout, conf.on_stdout)
  term.on_stderr = vim.F.if_nil(term.on_stderr, conf.on_stderr)
  term.on_exit = vim.F.if_nil(term.on_exit, conf.on_exit)
  term.__state = { mode = "?" }
  if term.close_on_exit == nil then term.close_on_exit = conf.close_on_exit end
  -- Add the newly created terminal to the list of all terminals
  ---@diagnostic disable-next-line: return-type-mismatch
  return setmetatable(term, self)
end

---@private
---Add a terminal to the list of terminals
function Terminal:__add()
  if not terminals[self.id] then terminals[self.id] = self end
  return self
end

function Terminal:is_float() return self.direction == "float" and ui.is_float(self.window) end

function Terminal:is_split()
  return (self.direction == "vertical" or self.direction == "horizontal")
    and not ui.is_float(self.window)
end

function Terminal:is_tab() return self.direction == "tab" and not ui.is_float(self.window) end

function Terminal:resize(size)
  if self:is_split() then ui.resize_split(self, size) end
end

function Terminal:is_open()
  if not self.window then return false end
  local win_type = fn.win_gettype(self.window)
  -- empty string window type corresponds to a normal window
  local win_open = win_type == "" or win_type == "popup"
  return win_open and api.nvim_win_get_buf(self.window) == self.bufnr
end

---@private
function Terminal:__restore_mode() self:set_mode(self.__state.mode) end

--- Set the terminal's mode
---@param m Mode
function Terminal:set_mode(m)
  if m == mode.INSERT then
    vim.cmd("startinsert")
  elseif m == mode.NORMAL then
    vim.cmd("stopinsert")
  elseif m == mode.UNSUPPORTED and config.get("start_in_insert") then
    vim.cmd("startinsert")
  end
end

function Terminal:persist_mode()
  local raw_mode = api.nvim_get_mode().mode
  local m = "?"
  if raw_mode:match("nt") then -- nt is normal mode in the terminal
    m = mode.NORMAL
  elseif raw_mode:match("t") then -- t is insert mode in the terminal
    m = mode.INSERT
  end
  self.__state.mode = m
end

---@private
function Terminal:_display_name() return self.display_name or vim.split(self.name, ";")[1] end

function Terminal:close()
  if self.on_close then self:on_close() end
  ui.close(self)
  ui.stopinsert()
  ui.update_origin_window(self.window)
end

function Terminal:shutdown()
  if self:is_open() then self:close() end
  ui.delete_buf(self)
  delete(self.id)
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

function Terminal:scroll_bottom()
  if not api.nvim_buf_is_loaded(self.bufnr) or not api.nvim_buf_is_valid(self.bufnr) then return end
  if ui.term_has_open_win(self) then api.nvim_buf_call(self.bufnr, ui.scroll_to_bottom) end
end

function Terminal:is_focused() return self.window == api.nvim_get_current_win() end

function Terminal:focus()
  if ui.term_has_open_win(self) then api.nvim_set_current_win(self.window) end
end

---Send a command to a running terminal
---@param cmd string|string[]
---@param go_back boolean? whether or not to return to original window
function Terminal:send(cmd, go_back)
  cmd = type(cmd) == "table" and with_cr(unpack(cmd)) or with_cr(cmd)
  fn.chansend(self.job_id, cmd)
  self:scroll_bottom()
  if go_back and self:is_focused() then
    ui.goto_previous()
    ui.stopinsert()
  elseif not go_back and not self:is_focused() then
    self:focus()
  end
end

function Terminal:clear() self:send("clear") end

---Update the directory of an already opened terminal
---@param dir string
function Terminal:change_dir(dir)
  dir = _get_dir(dir)
  if self.dir == dir then return end
  self:send({ fmt("cd %s", dir), "clear" })
  self.dir = dir
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
    if term.on_exit then term:on_exit(...) end
    if term.close_on_exit then
      term:close()
      if api.nvim_buf_is_loaded(term.bufnr) then
        api.nvim_buf_delete(term.bufnr, { force = true })
      end
    end
  end
end

---@private
---Prepare callback for terminal output handling
---If `auto_scroll` is active, will create a handler that scrolls on terminal output
---If `handler` is present, will call it passing `self` as the first parameter
---If none of the above is applicable, will not return a handler
---@param handler function? a custom callback function for output handling
function Terminal:__make_output_handler(handler)
  if self.auto_scroll or handler then
    return function(...)
      if self.auto_scroll then self:scroll_bottom() end
      if handler then handler(self, ...) end
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
    constants.FILETYPE,
    comment_sep,
    self.id,
  })
  local dir = _get_dir(self.dir)
  self.job_id = fn.termopen(cmd, {
    detach = 1,
    cwd = dir,
    on_exit = __handle_exit(self),
    on_stdout = self:__make_output_handler(self.on_stdout),
    on_stderr = self:__make_output_handler(self.on_stderr),
    env = self.env,
    clear_env = self.clear_env,
  })
  self.name = cmd
  self.dir = dir
end

---@private
---Add an orphaned terminal to the list of terminal and re-apply settings
function Terminal:__resurrect()
  self:__add()
  if self:is_split() then ui.resize_split(self) end
  -- set the window options including fixing height or width once the window is resized
  self:__set_options()
  ui.hl_term(self)
end

---@private
function Terminal:__set_ft_options()
  local buf = vim.bo[self.bufnr]
  buf.filetype = constants.FILETYPE
  buf.buflisted = false
end

---@private
function Terminal:__set_win_options()
  local win = vim.wo[self.window]
  if self:is_split() then
    local field = self.direction == "vertical" and "winfixwidth" or "winfixheight"
    win[field] = true
  end

  if config.hide_numbers then
    win.number = false
    win.relativenumber = false
  end
end

---@private
function Terminal:__set_options()
  self:__set_ft_options()
  self:__set_win_options()
  vim.b[self.bufnr].toggle_number = self.id
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

---Spawn terminal background job in a buffer without a window
function Terminal:spawn()
  if not (self.bufnr and api.nvim_buf_is_valid(self.bufnr)) then
    self.bufnr = ui.create_buf()
    self:__add()
    api.nvim_buf_call(self.bufnr, function() self:__spawn() end)
    setup_buffer_autocommands(self)
    setup_buffer_mappings(self.bufnr)
  end
end

---Open a terminal window
---@param size number?
---@param direction string?
function Terminal:open(size, direction)
  self.dir = _get_dir(self.dir)
  ui.set_origin_window()
  if direction then self:change_direction(direction) end
  if not self.bufnr or not api.nvim_buf_is_valid(self.bufnr) then
    local ok, err = pcall(opener, size, self)
    if not ok and err then return utils.notify(err, "error") end
    self:__add()
    self:__spawn()
    setup_buffer_autocommands(self)
    setup_buffer_mappings(self.bufnr)
    if self.on_create then self:on_create() end
  else
    local ok, err = pcall(opener, size, self)
    if not ok and err then return utils.notify(err, "error") end
    ui.switch_buf(self.bufnr)
    if config.autochdir then
      local cwd = fn.getcwd()
      if self.dir ~= cwd then self:change_dir(cwd) end
    end
  end
  ui.hl_term(self)
  -- NOTE: it is important that this function is called at this point. i.e. the buffer has been correctly assigned
  if self.on_open then self:on_open() end
end

---Open if closed and close if opened
---@param size number?
---@param direction string?
function Terminal:toggle(size, direction)
  if self:is_open() then
    self:close()
  else
    self:open(size, direction)
  end
  return self
end

--- get the toggle term number from
--- the name e.g. term://~/.dotfiles//3371887:/usr/bin/zsh;#toggleterm#1
--- the number in this case is 1
--- @param name string?
--- @return number?
--- @return Terminal?
function M.identify(name)
  name = name or api.nvim_buf_get_name(api.nvim_get_current_buf())
  local comment_sep = get_comment_sep()
  local parts = vim.split(name, comment_sep)
  local id = tonumber(parts[#parts])
  return id, terminals[id]
end

---get existing terminal or create an empty term table
---@param num number?
---@param dir string?
---@param direction string?
---@return Terminal
---@return boolean
function M.get_or_create_term(num, dir, direction)
  local term = M.get(num)
  if term then return term, false end
  if dir and fn.isdirectory(fn.expand(dir)) == 0 then dir = nil end
  return Terminal:new({ id = num, dir = dir, direction = direction }), true
end

---Get a single terminal by id, unless it is hidden
---@param id number?
---@return Terminal?
function M.get(id)
  local term = terminals[id]
  return (term and not term.hidden) and term or nil
end

---Return the potentially non contiguous map of terminals as a sorted array
---@param include_hidden boolean? whether or nor to filter out hidden
---@return Terminal[]
function M.get_all(include_hidden)
  local result = {}
  for _, v in pairs(terminals) do
    if include_hidden or (not include_hidden and not v.hidden) then table.insert(result, v) end
  end
  table.sort(result, function(a, b) return a.id < b.id end)
  return result
end

if _G.IS_TEST then
  function M.__reset()
    for _, term in pairs(terminals) do
      term:shutdown()
    end
  end

  M.__next_id = next_id
end

M.Terminal = Terminal
M.mode = mode

return M
