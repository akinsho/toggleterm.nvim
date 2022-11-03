local api = vim.api
local fn = vim.fn

local lazy = require("toggleterm.lazy")
---@module "toggleterm.utils"
local utils = lazy.require("toggleterm.utils")
---@module "toggleterm.constants"
local constants = require("toggleterm.constants")
---@module "toggleterm.config"
local config = lazy.require("toggleterm.config")
---@module "toggleterm.ui"
local ui = lazy.require("toggleterm.ui")
---@module "toggleterm.commandline"
local commandline = lazy.require("toggleterm.commandline")

local terms = require("toggleterm.terminal")

local AUGROUP = "ToggleTermCommands"
-----------------------------------------------------------
-- Export
-----------------------------------------------------------
local M = {}

--- only shade explicitly specified filetypes
local function apply_colors()
  local ft = vim.bo.filetype
  ft = (not ft or ft == "") and "none" or ft
  local allow_list = config.shade_filetypes or {}
  local is_enabled_ft = vim.tbl_contains(allow_list, ft)
  if vim.bo.buftype == "terminal" and is_enabled_ft then
    local _, term = terms.identify()
    ui.hl_term(term)
  end
end

local function setup_global_mappings()
  local mapping = config.open_mapping
  -- v:count defaults the count to 0 but if a count is passed in uses that instead
  if mapping then
    vim.keymap.set("n", mapping, '<Cmd>execute v:count . "ToggleTerm"<CR>', {
      desc = "Toggle Terminal",
      silent = true,
    })
    if config.insert_mappings then
      vim.keymap.set("i", mapping, "<Esc><Cmd>ToggleTerm<CR>", {
        desc = "Toggle Terminal",
        silent = true,
      })
    end
  end
end

--Create a new terminal or close beginning from the last opened
---@param _ number
---@param size number?
---@param dir string?
---@param direction string?
local function smart_toggle(_, size, dir, direction)
  local terminals = terms.get_all()
  if not ui.find_open_windows() then
    -- Re-open the first terminal toggled
    terms.get_or_create_term(terms.get_toggled_id(), dir, direction):open(size, direction)
  else
    -- count backwards from the end of the list
    for i = #terminals, 1, -1 do
      local term = terminals[i]
      if term and ui.term_has_open_win(term) then return term:close() end
    end
    utils.notify("Couldn't find a terminal to close", "error")
  end
end

--- @param num number
--- @param size number?
--- @param dir string?
--- @param direction string?
local function toggle_nth_term(num, size, dir, direction)
  local term = terms.get_or_create_term(num, dir, direction)
  ui.update_origin_window(term.window)
  term:toggle(size, direction)
end

---Close the last window if only a terminal *split* is open
---@param term Terminal
---@return boolean
local function close_last_window(term)
  local only_one_window = fn.winnr("$") == 1
  if only_one_window and vim.bo[term.bufnr].filetype == constants.FILETYPE then
    if term:is_split() then
      vim.cmd("keepalt bnext")
      return true
    end
  end
  return false
end

local function handle_term_enter()
  local _, term = terms.identify()
  if term then
    --- FIXME: we have to reset the filetype here because it is reset by other plugins
    --- i.e. telescope.nvim
    if vim.bo[term.bufnr] ~= constants.FILETYPE then term:__set_ft_options() end

    local closed = close_last_window(term)
    if closed then return end
    if config.persist_mode then
      term:__restore_mode()
    elseif config.start_in_insert then
      term:set_mode(terms.mode.INSERT)
    end
  end
end

local function handle_term_leave()
  local _, term = terms.identify()
  if not term then return end
  if config.persist_mode then term:persist_mode() end
  if term:is_float() then term:close() end
end

local function on_term_open()
  local id, term = terms.identify()
  if not term then
    terms.Terminal
      :new({
        id = id,
        bufnr = api.nvim_get_current_buf(),
        window = api.nvim_get_current_win(),
        highlights = config.highlights,
        job_id = vim.b.terminal_job_id,
        direction = ui.guess_direction(),
      })
      :__resurrect()
  end
  ui.set_winbar(term)
end

function M.exec_command(args, count)
  vim.validate({ args = { args, "string" } })
  if not args:match("cmd") then
    return utils.notify(
      "TermExec requires a cmd specified using the syntax cmd='ls -l' e.g. TermExec cmd='ls -l'",
      "error"
    )
  end
  local parsed = require("toggleterm.commandline").parse(args)
  vim.validate({
    cmd = { parsed.cmd, "string" },
    size = { parsed.size, "number", true },
    dir = { parsed.dir, "string", true },
    direction = { parsed.direction, "string", true },
    go_back = { parsed.go_back, "boolean", true },
    open = { parsed.open, "boolean", true },
  })
  M.exec(parsed.cmd, count, parsed.size, parsed.dir, parsed.direction, parsed.go_back, parsed.open)
end

--- @param cmd string
--- @param num number?
--- @param size number?
--- @param dir string?
--- @param direction string?
--- @param go_back boolean? whether or not to return to original window
--- @param open boolean? whether or not to open terminal window
function M.exec(cmd, num, size, dir, direction, go_back, open)
  vim.validate({
    cmd = { cmd, "string" },
    num = { num, "number", true },
    size = { size, "number", true },
    dir = { dir, "string", true },
    direction = { direction, "string", true },
    go_back = { go_back, "boolean", true },
    open = { open, "boolean", true },
  })
  num = (num and num >= 1) and num or terms.get_toggled_id()
  open = open == nil or open
  local term = terms.get_or_create_term(num, dir, direction)
  if not term:is_open() then term:open(size, direction) end
  -- going back from floating window closes it
  if term:is_float() then go_back = false end
  if go_back == nil then go_back = true end
  if not open then
    term:close()
    go_back = false
  end
  term:send(cmd, go_back)
end

--- @param selection_type string
--- @param trim_spaces boolean
--- @param cmd_data table<string, any>
function M.send_lines_to_terminal(selection_type, trim_spaces, cmd_data)
  local id = tonumber(cmd_data.args) or 1
  trim_spaces = trim_spaces == nil or trim_spaces

  vim.validate({
    selection_type = { selection_type, "string", true },
    trim_spaces = { trim_spaces, "boolean", true },
    terminal_id = { id, "number", true },
  })

  local current_window = api.nvim_get_current_win() -- save current window

  local lines = {}
  -- Beginning of the selection: line number, column number
  local start_line, start_col
  if selection_type == "single_line" then
    start_line, start_col = unpack(api.nvim_win_get_cursor(0))
    table.insert(lines, fn.getline(start_line))
  elseif selection_type == "visual_lines" then
    local res = utils.get_line_selection("visual")
    start_line, start_col = unpack(res.start_pos)
    lines = res.selected_lines
  elseif selection_type == "visual_selection" then
    local res = utils.get_line_selection("visual")
    start_line, start_col = unpack(res.start_pos)
    lines = utils.get_visual_selection(res)
  end

  if not lines or not next(lines) then return end

  for _, line in ipairs(lines) do
    local l = trim_spaces and line:gsub("^%s+", ""):gsub("%s+$", "") or line
    M.exec(l, id)
  end

  -- Jump back with the cursor where we were at the beginning of the selection
  api.nvim_set_current_win(current_window)
  api.nvim_win_set_cursor(current_window, { start_line, start_col })
end

function M.toggle_command(args, count)
  local parsed = commandline.parse(args)
  vim.validate({
    size = { parsed.size, "number", true },
    dir = { parsed.dir, "string", true },
    direction = { parsed.direction, "string", true },
  })
  if parsed.size then parsed.size = tonumber(parsed.size) end
  M.toggle(count, parsed.size, parsed.dir, parsed.direction)
end

function _G.___toggleterm_winbar_click(id)
  if id then
    local term = terms.get_or_create_term(id)
    if not term then return end
    term:toggle()
  end
end
--- If a count is provided we operate on the specific terminal buffer
--- i.e. 2ToggleTerm => open or close Term 2
--- if the count is 1 we use a heuristic which is as follows
--- if there is no open terminal window we toggle the first one i.e. assumed
--- to be the primary. However if several are open we close them.
--- this can be used with the count commands to allow specific operations
--- per term or mass actions
--- @param count number
--- @param size number?
--- @param dir string?
--- @param direction string?
function M.toggle(count, size, dir, direction)
  vim.validate({ count = { count, "number", true }, size = { size, "number", true } })
  -- TODO: this should toggle the specified term if any count is passed in
  if count >= 1 then
    toggle_nth_term(count, size, dir, direction)
  else
    smart_toggle(count, size, dir, direction)
  end
end

-- Toggle all terminals
-- If any terminal is open it will be closed
-- If no terminal exists it will do nothing
-- If any terminal exists but is not open it will be open
function M.toggle_all(force)
  local terminals = terms.get_all()

  if force and ui.find_open_windows() then
    for _, term in pairs(terminals) do
      term:close()
    end
  else
    if not ui.find_open_windows() then
      for _, term in pairs(terminals) do
        term:open()
      end
    else
      for _, term in pairs(terminals) do
        term:close()
      end
    end
  end
end

---@param _ ToggleTermConfig
local function setup_autocommands(_)
  api.nvim_create_augroup(AUGROUP, { clear = true })
  local toggleterm_pattern = "term://*#toggleterm#*"

  api.nvim_create_autocmd("BufEnter", {
    pattern = toggleterm_pattern,
    group = AUGROUP,
    nested = true, -- this is necessary in case the buffer is the last
    callback = handle_term_enter,
  })

  api.nvim_create_autocmd("WinLeave", {
    pattern = toggleterm_pattern,
    group = AUGROUP,
    callback = handle_term_leave,
  })

  api.nvim_create_autocmd("TermOpen", {
    pattern = toggleterm_pattern,
    group = AUGROUP,
    callback = on_term_open,
  })

  api.nvim_create_autocmd("ColorScheme", {
    group = AUGROUP,
    callback = function()
      config.reset_highlights()
      for _, term in pairs(terms.get_all()) do
        if api.nvim_win_is_valid(term.window) then
          api.nvim_win_call(term.window, function() ui.hl_term(term) end)
        end
      end
    end,
  })

  api.nvim_create_autocmd("TermOpen", {
    group = AUGROUP,
    pattern = "term://*",
    callback = apply_colors,
  })
end

---------------------------------------------------------------------------------
-- Commands
---------------------------------------------------------------------------------

---@param callback fun(t: Terminal?)
local function get_subject_terminal(callback)
  local items = terms.get_all(true)
  if #items == 0 then return utils.notify("No toggleterms are open yet") end

  vim.ui.select(items, {
    prompt = "Please select a terminal to name: ",
    format_item = function(term) return term.id .. ": " .. term:_display_name() end,
  }, function(term)
    if not term then return end
    callback(term)
  end)
end

---@param name string
---@param term Terminal
local function set_term_name(name, term) term.display_name = name end

local function request_term_name(term)
  vim.ui.input({ prompt = "Please set a name for the terminal" }, function(name)
    if name and #name > 0 then set_term_name(name, term) end
  end)
end

local function setup_commands()
  local cmd = api.nvim_create_user_command
  -- Count is 0 by default
  cmd(
    "TermExec",
    function(opts) M.exec_command(opts.args, opts.count) end,
    { count = true, complete = commandline.term_exec_complete, nargs = "*" }
  )

  cmd(
    "ToggleTerm",
    function(opts) M.toggle_command(opts.args, opts.count) end,
    { count = true, complete = commandline.toggle_term_complete, nargs = "*" }
  )

  cmd("ToggleTermToggleAll", function(opts) M.toggle_all(opts.bang) end, { bang = true })

  cmd(
    "ToggleTermSendVisualLines",
    function(args) M.send_lines_to_terminal("visual_lines", true, args) end,
    { range = true, nargs = "?" }
  )

  cmd(
    "ToggleTermSendVisualSelection",
    function(args) M.send_lines_to_terminal("visual_selection", true, args) end,
    { range = true, nargs = "?" }
  )

  cmd(
    "ToggleTermSendCurrentLine",
    function(args) M.send_lines_to_terminal("single_line", true, args) end,
    { nargs = "?" }
  )

  cmd("ToggleTermSetName", function(opts)
    local no_count = not opts.count or opts.count < 1
    local no_name = opts.args == ""
    if no_count and no_name then
      get_subject_terminal(request_term_name)
    elseif no_name then
      request_term_name()
    elseif no_count then
      get_subject_terminal(function(t) set_term_name(opts.args, t) end)
    else
      local term = terms.get(opts.count)
      if not term then return end
      set_term_name(opts.args, term)
    end
  end, { nargs = "?" })
end

function M.setup(user_prefs)
  local conf = config.set(user_prefs)
  setup_global_mappings()
  setup_autocommands(conf)
  setup_commands()
end

return M
