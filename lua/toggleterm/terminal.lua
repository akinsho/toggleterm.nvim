local M = {}

local ui = require("toggleterm.ui")
local config = require("toggleterm.config")
local utils = require("toggleterm.utils")
local term_ft = require("toggleterm.constants").term_ft

local api = vim.api
local fmt = string.format
local fn = vim.fn

---@type Terminal[]
local terminals = {}

--- @class Terminal
--- @field cmd string
--- @field direction string
--- @field id number
--- @field bufnr number
--- @field window number
--- @field job_id number
--- @field dir string
--- @field name string
--- @field on_stdout fun(job: number, exit_code: number, type: string)
--- @field on_stderr fun(job: number, data: string[], name: string)
--- @field on_exit fun(job: number, data: string[], name: string)
local Terminal = {}

local function next_id()
  return #terminals == 0 and 1 or #terminals + 1
end

--- @param bufnr number
local function setup_buffer_mappings(bufnr)
  local mapping = config.get("open_mapping")
  if mapping then
    api.nvim_buf_set_keymap(
      bufnr,
      "t",
      mapping,
      [[<C-\><C-n>:exe v:count1 . "ToggleTerm"<CR>]],
      {
        silent = true,
        noremap = true
      }
    )
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
      fmt('lua require"toggleterm.terminal".delete(%d)', term.id)
    }
  }

  if conf.start_in_insert then
    vim.cmd("startinsert!")
    table.insert(
      commands,
      {
        "BufEnter",
        fmt("<buffer=%d>", term.bufnr),
        "startinsert!"
      }
    )
  end
  if conf.persist_size and term:is_split() then
    table.insert(
      commands,
      {
        "CursorHold",
        fmt("<buffer=%d>", term.bufnr),
        "lua require'toggleterm.ui'.save_window_size()"
      }
    )
  end
  utils.create_augroups({["ToggleTerm" .. term.bufnr] = commands})
end

---Create a new terminal object
---@param term Terminal
---@return Terminal
function Terminal:new(term)
  term = term or {}
  --- If we try to create a new terminal, but the id is already
  --- taken, return the terminal with the containing id
  if term.id and terminals[term.id] then
    return terminals[term.id]
  end
  local conf = config.get()
  self.__index = self
  term.direction = term.direction or conf.direction
  term.window = term.window or -1
  term.job_id = term.job_id or -1
  term.bufnr = term.bufnr or -1
  term.dir = term.dir or vim.loop.cwd()
  term.id = term.id or next_id()
  term.on_stdout = term.on_stdout
  term.on_stderr = term.on_stderr
  term.on_exit = term.on_exit
  return setmetatable(term, self)
end

---@private
---Add a terminal to the list of terminals
function Terminal:__add()
  terminals[self.id] = self
  return self
end

function Terminal:is_split()
  return self.direction == "vertical" or self.direction == "horizontal"
end

function Terminal:resize(size)
  if self:is_split() then
    ui.resize_split(self, size)
  end
end

function Terminal:is_open()
  --- TODO: try open will actually attempt to switch to this window
  local win_open = ui.try_open(self.window)
  return win_open and api.nvim_win_get_buf(self.window) == self.bufnr
end

function Terminal:close()
  ui.update_origin_window(self.window)

  if ui.try_open(self.window) then
    ui.close(self)
    ui.stopinsert()
  else
    local msg =
      self.id and fmt("Failed to close window: %d does not exist", self.id) or
      "Failed to close window: invalid term number"
    utils.echomsg(msg, "Error")
  end
  ui.update_origin_window(self.window)
end

function Terminal:shutdown()
  self:close()
  ui.delete_buf(self)
end

---Combine arguments into strings separated by new lines
---@vararg string
---@return string
local function with_cr(...)
  local result = {}
  for _, str in ipairs({...}) do
    table.insert(result, str .. "\n")
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
  if self.dir ~= dir then
    self:send({fmt("cd %s", dir), "clear"})
  end
end

---@private
function Terminal:__spawn()
  local name = vim.o.shell .. ";#" .. term_ft .. "#" .. self.id
  self.job_id = fn.termopen(name, {detach = 1, cwd = self.dir})
  self.name = name
end

---@private
---Add an orphaned terminal to the list of terminal and re-apply settings
function Terminal:__resurrect()
  self:__add()
  ui.set_options(self.window, self.bufnr, self)
  self:resize()
end

---Open a terminal in a type of window i.e. a split,full window or tab
---@param size number
---@param term table
local function opener(size, term)
  local dir = term.direction
  if term:is_split() then
    ui.open_split(size, term)
  elseif dir == "window" then
    --- do nothing, maybe later this should close other windows or something
  elseif dir == "tab" then
    ui.open_tab()
  end
end

---Open a terminal window
---@param size number
---@param is_new boolean
function Terminal:open(size, is_new)
  ui.set_origin_window()
  if fn.bufexists(self.bufnr) == 0 then
    opener(size, self)
    self.window, self.bufnr = ui.create_buf_and_set(self)
    self:__spawn()
    setup_buffer_autocommands(self)
    setup_buffer_mappings(self.bufnr)
    self:__add()
  else
    opener(size, self)
    ui.switch_buf(self.bufnr)
    self.window = api.nvim_get_current_win()
    if not is_new then
      self:change_dir(self.dir)
    end
  end
end

---Open if closed and close if opened
---@param size number
function Terminal:toggle(size)
  if self:is_open() then
    self:close()
  else
    self:open(size)
  end
  return self
end

--- get the toggle term number from
--- the name e.g. term://~/.dotfiles//3371887:/usr/bin/zsh;#toggleterm#1
--- the number in this case is 1
--- @param name string
--- @return number
function M.identify(name)
  local parts = vim.split(name, "#")
  local id = tonumber(parts[#parts])
  return id, terminals[id]
end

--- Remove the in memory reference to the no longer open terminal
--- @param num string
function M.delete(num)
  if terminals[num] then
    terminals[num] = nil
  end
end

---get existing terminal or create an empty term table
---@param num number
---@param dir string
---@return Terminal
---@return boolean
function M.get_or_create_term(num, dir, direction)
  if terminals[num] then
    return terminals[num], false
  end
  return Terminal:new {id = next_id(), dir = dir, direction = direction}, true
end

function M.get_all()
  return terminals
end

function M.reset()
  for idx, term in pairs(terminals) do
    term:shutdown()
    terminals[idx] = nil
  end
end

M.Terminal = Terminal

return M
