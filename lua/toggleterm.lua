local api = vim.api
local fn = vim.fn
local opt = vim.opt

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

local term_ft = constants.term_ft
local AUGROUP = "ToggleTermCommands"
-----------------------------------------------------------
-- Export
-----------------------------------------------------------
local M = {}

--- only shade explicitly specified filetypes
local function apply_colors()
  local ft = vim.bo.filetype
  ft = (not ft or ft == "") and "none" or ft
  local allow_list = config.get("shade_filetypes") or {}
  local is_enabled_ft = vim.tbl_contains(allow_list, ft)
  if vim.bo.buftype == "terminal" and is_enabled_ft then
    local _, term = terms.identify()
    ui.hl_term(term)
  end
end

local function setup_global_mappings()
  local conf = config.get()
  local mapping = conf.open_mapping
  -- v:count defaults the count to 0 but if a count is passed in uses that instead
  if mapping then
    api.nvim_set_keymap("n", mapping, '<Cmd>execute v:count . "ToggleTerm"<CR>', {
      silent = true,
      noremap = true,
    })
    if conf.insert_mappings then
      api.nvim_set_keymap("i", mapping, "<Esc><Cmd>ToggleTerm<CR>", {
        silent = true,
        noremap = true,
      })
    end
  end
end

--Create a new terminal or close beginning from the last opened
---@param _ number
---@param size number
---@param dir string
---@param direction string
local function smart_toggle(_, size, dir, direction)
  local terminals = terms.get_all()
  if not ui.find_open_windows() then
    -- Re-open the first terminal toggled
    terms.get_or_create_term(terms.get_toggled_id(), dir, direction):open(size, direction)
  else
    local target
    -- count backwards from the end of the list
    for i = #terminals, 1, -1 do
      local term = terminals[i]
      if term and ui.term_has_open_win(term) then
        target = term
        break
      end
    end
    if not target then
      utils.notify("Couldn't find a terminal to close", "error")
      return
    end
    target:close()
  end
end

--- @param num number
--- @param size number
--- @param dir string
--- @param direction string
local function toggle_nth_term(num, size, dir, direction)
  local term = terms.get_or_create_term(num, dir, direction)
  ui.update_origin_window(term.window)
  term:toggle(size, direction)
end

---Close the last window if only a terminal *split* is open
---@param term Terminal
local function close_last_window(term)
  local only_one_window = fn.winnr("$") == 1
  if only_one_window and vim.bo[term.bufnr].filetype == term_ft then
    if term:is_split() then
      vim.cmd("keepalt bnext")
    end
  end
end

local function handle_term_enter()
  local _, term = terms.identify()
  if term then
    close_last_window(term)
  end
end

local function handle_term_leave()
  local _, term = terms.identify()
  if term and term:is_float() then
    term:close()
  end
end

local function on_term_open()
  local id, term = terms.identify()
  if not term then
    terms.Terminal
      :new({
        id = id,
        bufnr = api.nvim_get_current_buf(),
        window = api.nvim_get_current_win(),
        highlights = config.get("highlights"),
        job_id = vim.b.terminal_job_id,
        direction = ui.guess_direction(),
      })
      :__resurrect()
  end
end

function M.exec_command(args, count)
  vim.validate({ args = { args, "string" } })
  if not args:match("cmd") then
    return utils.echomsg(
      "TermExec requires a cmd specified using the syntax cmd='ls -l' e.g. TermExec cmd='ls -l'",
      "ErrorMsg"
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
--- @param go_back? boolean whether or not to return to original window
--- @param open? boolean whether or not to open terminal window
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
  local term, created = terms.get_or_create_term(num, dir, direction)
  if not term:is_open() then
    term:open(size, direction, created)
  end
  if not created and dir then
    term:change_dir(dir)
  end
  -- going back from floating window closes it
  if term:is_float() then
    go_back = false
  end
  if go_back == nil then
    go_back = true
  end
  if not open then
    term:close()
    go_back = false
  end
  term:send(cmd, go_back)
end

--- @param selection_type string
--- @param trim_spaces boolean
--- @param terminal_id number
function M.send_lines_to_terminal(selection_type, trim_spaces, terminal_id)
  -- trim_spaces defines if we should trim the spaces from lines which are sent to the terminal
  trim_spaces = trim_spaces == nil or trim_spaces

  -- If no terminal id provided fall back to the default
  terminal_id = terminal_id or 1
  terminal_id = tonumber(terminal_id)

  vim.validate({
    selection_type = { selection_type, "string", true },
    trim_spaces = { trim_spaces, "boolean", true },
    terminal_id = { terminal_id, "number", true },
  })

  -- Window number from where we are calling the function (needed so we can get back to it automatically)
  local current_window = api.nvim_get_current_win()
  -- Line texts - these will be sent over to the terminal one by one
  local lines = {}
  -- Beginning of the selection: line number, column number
  local b_line, b_col

  local function line_selection(mode)
    local start_char, end_char
    if mode == "visual" then
      start_char = "'<"
      end_char = "'>"
    elseif mode == "motion" then
      start_char = "'["
      end_char = "']"
    end

    -- Get the start and the end of the selection
    local start_line, start_col = unpack(fn.getpos(start_char), 2, 3)
    local end_line, end_col = unpack(fn.getpos(end_char), 2, 3)
    local selected_lines = api.nvim_buf_get_lines(0, start_line - 1, end_line, 0)
    return {
      start_pos = { start_line, start_col },
      end_pos = { end_line, end_col },
      selected_lines = selected_lines,
    }
  end

  local function get_visual_selection(res)
    -- Return the text of the precise visual selection

    local vis_mode = fn.visualmode()

    if vis_mode == "V" then
      -- line-visual
      -- return lines encompassed by the selection; already in res object
      return res.selected_lines

    elseif vis_mode == "v" then
      -- regular-visual
      -- return the buffer text encompassed by the selection
      local start_line, start_col = unpack(res.start_pos)
      local end_line, end_col = unpack(res.end_pos)
      -- exclude the last char in text if "selection" is set to "exclusive"
      if opt.selection._value == "exclusive" then
        end_col = end_col - 1
      end
      return api.nvim_buf_get_text(
        0, start_line - 1, start_col - 1, end_line - 1, end_col, {}
      )

    elseif vis_mode == "\x16" then
      -- block-visual
      -- return the lines encompassed by the selection, each truncated by the
      -- start and end columns
      local _, start_col = unpack(res.start_pos)
      local _, end_col = unpack(res.end_pos)
      -- exclude the last col of the block if "selection" is set to "exclusive"
      if opt.selection._value == "exclusive" then
        end_col = end_col - 1
      end
      -- exchange start and end columns for proper substring indexing if needed
      -- e.g. instead of str:sub(10, 5), do str:sub(5, 10)
      if start_col > end_col then
        start_col, end_col = end_col, start_col
      end
      -- iterate over lines, truncating each one
      local block_lines = {}
      for i, v in ipairs(res.selected_lines) do
        block_lines[i] = v:sub(start_col, end_col)
      end
      return block_lines
    end
  end

  if selection_type == "single_line" then
    b_line, b_col = unpack(api.nvim_win_get_cursor(0))
    table.insert(lines, fn.getline(b_line))

  elseif selection_type == "visual_lines" then
    local res = line_selection("visual")
    b_line, b_col = unpack(res.start_pos)
    lines = res.selected_lines

  elseif selection_type == "visual_selection" then
    local res = line_selection("visual")
    b_line, b_col = unpack(res.start_pos)
    lines = get_visual_selection(res)
  end

  -- If no lines are fetched we don't need to do anything
  if #lines == 0 or lines == nil then
    return
  end

  -- Send each line to the terminal after some preprocessing if required
  for _, v in ipairs(lines) do
    -- Trim whitespaces from the strings
    v = trim_spaces and v:gsub("^%s+", ""):gsub("%s+$", "") or v
    M.exec(v, terminal_id)
  end

  -- Jump back with the cursor where we were at the begiining of the selection
  api.nvim_set_current_win(current_window)
  api.nvim_win_set_cursor(current_window, { b_line, b_col })
end

function M.toggle_command(args, count)
  local parsed = commandline.parse(args)
  vim.validate({
    size = { parsed.size, "number", true },
    dir = { parsed.dir, "string", true },
    direction = { parsed.direction, "string", true },
  })
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
--- @param size number?
--- @param dir string?
--- @param direction string?
function M.toggle(count, size, dir, direction)
  vim.validate({ count = { count, "number", true }, size = { size, "number", true } })
  -- TODO this should toggle the specified term if any count is passed in
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

  api.nvim_create_autocmd("WinEnter", {
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
          api.nvim_win_call(term.window, function()
            ui.hl_term(term)
          end)
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
local function setup_commands()
  -- Count is 0 by default
  api.nvim_create_user_command("TermExec", function(opts)
    M.exec_command(opts.args, opts.count)
  end, { count = true, complete = "shellcmd", nargs = "*" })

  api.nvim_create_user_command("ToggleTerm", function(opts)
    M.toggle_command(opts.args, opts.count)
  end, { count = true, nargs = "*" })

  api.nvim_create_user_command("ToggleTermToggleAll", function(opts)
    M.toggle_all(opts.bang)
  end, { bang = true })

  -- TODO: Convert this functions to use lua functions with the passed in line1,line2 args
  api.nvim_create_user_command(
    "ToggleTermSendVisualLines",
    "'<,'> lua require'toggleterm'.send_lines_to_terminal('visual_lines', true, <q-args>)<CR>",
    { range = true, nargs = "?" }
  )
  -- TODO: Convert this functions to use lua functions with the passed in line1,line2 args
  api.nvim_create_user_command(
    "ToggleTermSendVisualSelection",
    "'<,'> lua require'toggleterm'.send_lines_to_terminal('visual_selection', true, <q-args>)<CR>",
    { range = true, nargs = "?" }
  )
  api.nvim_create_user_command("ToggleTermSendCurrentLine", function(opts)
    M.send_lines_to_terminal("single_line", true, opts.args)
  end, { nargs = "?" })
end

function M.setup(user_prefs)
  local conf = config.set(user_prefs)
  setup_global_mappings()
  setup_autocommands(conf)
  setup_commands()
end

return M
