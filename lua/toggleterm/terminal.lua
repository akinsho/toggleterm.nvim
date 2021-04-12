local M = {}

local ui = require("toggleterm.ui")
local config = require("toggleterm.config")
local utils = require("toggleterm.utils")
local term_ft = require("toggleterm.constants").term_ft

local api = vim.api
local fmt = string.format
local fn = vim.fn

--- @param bufnr number
local function setup_buffer_mappings(bufnr)
  local mapping = config.get("open_mapping")
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
        "lua require'toggleterm'.save_window_size()"
      }
    )
  end
  utils.create_augroups({["ToggleTerm" .. term.bufnr] = commands})
end

--- @class Terminal
--- @field cmd string
--- @field direction string
--- @field id number
--- @field bufnr number
--- @field window number
--- @field job_id number
--- @field dir string
M.Terminal = {}

---Create a new terminal object
---@param term Terminal
---@return Terminal
function M.Terminal:new(term)
  local conf = config.get()
  assert(term.id, "A terminal id must be specified")
  term = term or {}
  self.__index = self
  term.direction = term.direction or conf.direction
  term.window = term.window or -1
  term.job_id = term.job_id or -1
  term.bufnr = term.bufnr or -1
  term.dir = term.dir or vim.loop.cwd()
  term.id = term.id
  return setmetatable(term, self)
end

function M.Terminal:is_split()
  return self.direction == "vertical" or self.direction == "horizontal"
end

function M.Terminal:resize(size)
  if self:is_split() then
    vim.cmd(self.direction == "vertical" and "vertical resize" or "resize" .. " " .. size)
  end
end

function M.Terminal:close()
  ui.update_origin_window(self.window)
  if ui.find_window(self.window) then
    if self:is_split() then
      ui.save_size()
      vim.cmd("hide")
      local origin = ui.get_origin_window()
      if api.nvim_win_is_valid(origin) then
        api.nvim_set_current_win(origin)
      else
        ui.set_origin_window(nil)
      end
    else
      vim.cmd("b#")
    end

    vim.cmd("stopinsert!")
  else
    if self.id then
      vim.cmd(fmt('echoerr "Failed to close window: %d does not exist"', self.id))
    else
      vim.cmd('echoerr "Failed to close window: invalid term number"')
    end
  end
end

---Send a command to a running terminal
---@param cmd any
function M.Terminal:send(cmd)
  fn.chansend(self.job_id, cmd)
end

---Update the directory of an already opened terminal
---@param dir string
function M.Terminal:change_dir(dir)
  if self.dir ~= dir then
    self:send("cd " .. dir .. "\n" .. "clear" .. "\n")
  end
end

---Open a terminal window
---@param size number
---@param is_new boolean
function M.Terminal:open(size, is_new)
  ui.set_origin_window()
  if not api.nvim_buf_is_loaded(self.bufnr) then
    self.window = api.nvim_get_current_win()
    self.bufnr = api.nvim_create_buf(false, false)
    self:toggle(size, self)

    api.nvim_set_current_buf(self.bufnr)
    api.nvim_win_set_buf(self.window, self.bufnr)

    local name = vim.o.shell .. ";#" .. term_ft .. "#" .. self.id
    self.job_id = fn.termopen(name, {detach = 1, cwd = self.dir})

    setup_buffer_autocommands(self)
    setup_buffer_mappings(self.bufnr)
    M.terminals[self.id] = self
  else
    self:toggle(size, self)
    self.window = api.nvim_get_current_win()
    if not is_new then
      self:change_dir(self.dir)
    end
  end
end

---Open a terminal in a type of window i.e. a split,full window or tab
---@param size number
---@param term table
function M.Terminal:toggle(size, term)
  local dir = self.direction
  if dir == "horizontal" or dir == "vertical" then
    ui.open_split(size)
  elseif dir == "window" then
    ui.open_window(term.bufnr)
  elseif dir == "tab" then
    ui.open_tab()
  end
end

---Add a terminal to the list of terminals, if it does not exist add nothing
---@param num number
---@param term Terminal
---@param on_add fun(term: Terminal, num: number):nil
function M.add(num, term, on_add)
  if not M.terminals[num] then
    M.terminals[num] = term
    if on_add then
      on_add(term, num)
    else
      return term, num
    end
  end
  return nil, num
end

--- get the toggle term number from
--- the name e.g. term://~/.dotfiles//3371887:/usr/bin/zsh;#toggleterm#1
--- the number in this case is 1
--- @param name string
function M.identify(name)
  local parts = vim.split(name, "#")
  return tonumber(parts[#parts])
end

--- Remove the in memory reference to the no longer open terminal
--- @param num string
function M.delete(num)
  if M.terminals[num] then
    M.terminals[num] = nil
  end
end

return M
