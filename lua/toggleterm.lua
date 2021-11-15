local api = vim.api
local fn = vim.fn
local fmt = string.format

local constants = require("toggleterm.constants")
local colors = require("toggleterm.colors")

local terms = require("toggleterm.terminal")

local term_ft = constants.term_ft
local SHADING_AMOUNT = constants.shading_amount
-----------------------------------------------------------
-- Export
-----------------------------------------------------------
local M = {
  __set_highlights = colors.set_highlights,
}

--- only shade explicitly specified filetypes
function M.__apply_colors()
  local ft = vim.bo.filetype
  ft = (not ft or ft == "") and "none" or ft
  local allow_list = require("toggleterm.config").get("shade_filetypes") or {}
  local is_enabled_ft = vim.tbl_contains(allow_list, ft)
  if vim.bo.buftype == "terminal" and is_enabled_ft then
    local _, term = terms.identify()
    require("toggleterm.ui").hl_term(term)
  end
end

local function setup_global_mappings()
  local conf = require("toggleterm.config").get()
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
  local ui = require("toggleterm.ui")
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
      return require("toggleterm.utils").echomsg("Couldn't find a terminal to close")
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
  require("toggleterm.ui").update_origin_window(term.window)
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

function M.handle_term_enter()
  local _, term = terms.identify()
  if term then
    close_last_window(term)
  end
end

function M.handle_term_leave()
  local _, term = terms.identify()
  if term and term:is_float() then
    term:close()
  end
end

function M.on_term_open()
  local id, term = terms.identify()
  if not term then
    terms.Terminal
      :new({
        id = id,
        bufnr = api.nvim_get_current_buf(),
        window = api.nvim_get_current_win(),
        job_id = vim.b.terminal_job_id,
        direction = require("toggleterm.ui").guess_direction(),
      })
      :__resurrect()
  end
end

function M.exec_command(args, count)
  vim.validate({ args = { args, "string" } })
  if not args:match("cmd") then
    return require("toggleterm.utils").echomsg(
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
--- @param num number
--- @param size number
--- @param dir string
--- @param direction string
--- @param go_back boolean whether or not to return to original window
--- @param open boolean whether or not to open terminal window
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

function M.toggle_command(args, count)
  local parsed = require("toggleterm.commandline").parse(args)
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
--- @param size number
--- @param dir string
--- @param direction string
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
function M.toggle_all_terms()
  local ui = require("toggleterm.ui")
  local terminals = terms.get_all()

  if not ui.find_open_windows() then
    for _, term in pairs(terms.get_all()) do
      term:open()
    end
  else
    for _, term in pairs(terms.get_all()) do
      term:close()
    end
  end
end

function M.setup(user_prefs)
  local conf = require("toggleterm.config").set(user_prefs)
  setup_global_mappings()
  local autocommands = {
    {
      "WinEnter",
      "term://*toggleterm#*",
      "nested", -- this is necessary in case the buffer is the last
      "lua require'toggleterm'.handle_term_enter()",
    },
    {
      "WinLeave",
      "term://*toggleterm#*",
      "lua require'toggleterm'.handle_term_leave()",
    },
    {
      "TermOpen",
      "term://*toggleterm#*",
      "lua require'toggleterm'.on_term_open()",
    },
  }
  if conf.shade_terminals then
    local is_bright = colors.is_bright_background()

    -- if background is light then darken the terminal a lot more to increase contrast
    local factor = conf.shading_factor
        and type(conf.shading_factor) == "number"
        and conf.shading_factor
      or (is_bright and 3 or 1)

    local amount = factor * SHADING_AMOUNT
    colors.set_highlights(amount)

    vim.list_extend(autocommands, {
      {
        -- call set highlights once on vim start
        -- as this plugin might not be initialised till
        -- after the colorscheme autocommand has fired
        -- reapply highlights when the colorscheme
        -- is re-applied
        "ColorScheme",
        "*",
        fmt("lua require'toggleterm'.__set_highlights(%d)", amount),
      },
      {
        "TermOpen",
        "term://*",
        "lua require('toggleterm').__apply_colors()",
      },
    })
  end
  require("toggleterm.utils").create_augroups({ ToggleTerminal = autocommands })
end

return M
