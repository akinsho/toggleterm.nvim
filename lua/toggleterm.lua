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
  if not ft or ft == "" then
    ft = "none"
  end

  local allow_list = require("toggleterm.config").get("shade_filetypes") or {}
  table.insert(allow_list, term_ft)

  local is_enabled_ft = false
  for _, filetype in ipairs(allow_list) do
    if ft == filetype then
      is_enabled_ft = true
      break
    end
  end
  if vim.bo.buftype == "terminal" and is_enabled_ft then
    local _, term = terms.identify()
    require("toggleterm.ui").darken_terminal(term)
  end
end

local function setup_global_mappings()
  local conf = require("toggleterm.config").get()
  local mapping = conf.open_mapping
  -- v:count1 defaults the count to 1 but if a count is passed in uses that instead
  -- <c-u> allows passing along the count
  if mapping then
    api.nvim_set_keymap("n", mapping, ':<c-u>exe v:count1 . "ToggleTerm"<CR>', {
      silent = true,
      noremap = true,
    })
    if conf.insert_mappings then
      api.nvim_set_keymap("i", mapping, '<Esc>:<c-u>exe v:count1 . "ToggleTerm"<CR>', {
        silent = true,
        noremap = true,
      })
    end
  end
end

--Create a new terminal or close beginning from the last opened
---@param _ number
---@param size number
---@param directory string
---@param direction string
local function smart_toggle(_, size, directory, direction)
  local ui = require("toggleterm.ui")
  local terminals = terms.get_all()
  if not ui.find_open_windows() then
    -- Re-open the first terminal toggled
    local id = terminals[1] and terminals[1].id or 1
    terms.get_or_create_term(id, directory, direction):open(size)
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
--- @param directory string
--- @param direction string
local function toggle_nth_term(num, size, directory, direction)
  local term = terms.get_or_create_term(num, directory, direction)
  require("toggleterm.ui").update_origin_window(term.window)
  term:toggle(size)
end

---Close the last window if only a terminal *split* is open
---@param term Terminal
local function close_last_window(term)
  local only_one_window = fn.winnr("$") == 1
  if only_one_window and vim.bo[term.bufnr].filetype == term_ft then
    if term:is_split() then
      term:close()
      vim.cmd("keepalt bnext")
    end
  end
end

function M.handle_term_enter()
  local _, term = terms.identify()
  if term then
    term:resize()
    close_last_window(term)
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
    dir = { parsed.dir, "string", true },
    size = { parsed.size, "number", true },
  })
  M.exec(parsed.cmd, count, parsed.size, parsed.dir)
end

--- @param cmd string
--- @param num number
--- @param size number
--- @param dir string
function M.exec(cmd, num, size, dir)
  vim.validate({
    cmd = { cmd, "string" },
    num = { num, "number" },
    size = { size, "number", true },
    dir = { dir, "string", true },
  })
  if dir then
    dir = fn.expand(dir)
  end
  -- count
  num = num < 1 and 1 or num
  local term, created = terms.get_or_create_term(num, dir)
  if not term:is_open() then
    term:open(size, created)
  end
  if not created and dir then
    term:change_dir(dir)
  end
  term:send(cmd, true)
end

function M.toggle_command(args, count)
  local parsed = require("toggleterm.commandline").parse(args)
  vim.validate({
    size = { parsed.size, "number", true },
    directory = { parsed.dir, "string", true },
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
  if count > 1 then
    toggle_nth_term(count, size, dir, direction)
  else
    smart_toggle(count, size, dir, direction)
  end
end

function M.setup(user_prefs)
  local conf = require("toggleterm.config").set(user_prefs)
  setup_global_mappings()
  local autocommands = {
    {
      "BufEnter",
      "term://*toggleterm#*",
      "nested",
      "lua require'toggleterm'.handle_term_enter()",
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
