local M = {}

local fn, api, opt = vim.fn, vim.api, vim.opt
local fmt = string.format
local levels = vim.log.levels

function M.is_nightly()
  local v = vim.version()
  return v.minor >= 8
end

---@alias error_types 'error' | 'info' | 'warn'
---Inform a user about something
---@param msg string
---@param level error_types
function M.notify(msg, level)
  local err = level:upper()
  level = level and levels[err] or levels.INFO
  vim.schedule(function() vim.notify(msg, level, { title = "Toggleterm" }) end)
end

---@private
---Helper function to derive the current git directory path
---@return string|nil
function M.git_dir()
  local gitdir = fn.system(fmt("git -C %s rev-parse --show-toplevel", fn.expand("%:p:h")))
  local isgitdir = fn.matchstr(gitdir, "^fatal:.*") == ""
  if not isgitdir then return end
  return vim.trim(gitdir)
end

---@param str string|nil
---@return boolean
function M.str_is_empty(str) return str == nil or str == "" end

---@param tbl table
---@return table
function M.tbl_filter_empty(tbl)
  return vim.tbl_filter(
    ---@param str string|nil
    function(str) return not M.str_is_empty(str) end,
    tbl
  )
end

--- Concats a table ignoring empty entries
---@param tbl table
---@param sep string
function M.concat_without_empty(tbl, sep) return table.concat(M.tbl_filter_empty(tbl), sep) end

-- Key mapping function
---@param mod string | string[]
---@param lhs string | string[]
---@param rhs string | function
---@param opts table?
function M.key_map(mod, lhs, rhs, opts)
  if type(lhs) == "string" then
    vim.keymap.set(mod, lhs, rhs, opts)
  elseif type(lhs) == "table" then
    for _, key in pairs(lhs) do
      vim.keymap.set(mod, key, rhs, opts)
    end
  end
end

---@param mode "visual" | "motion"
---@return table
function M.get_line_selection(mode)
  local start_char, end_char = unpack(({
    visual = { "'<", "'>" },
    motion = { "'[", "']" },
  })[mode])
  -- '< marks are only updated when one leaves visual mode.
  -- When calling lua functions directly from a mapping, need to
  -- explicitly exit visual with the escape key to ensure those marks are
  -- accurate.
  vim.cmd("normal! ")

  -- Get the start and the end of the selection
  local start_line, start_col = unpack(fn.getpos(start_char), 2, 3)
  local end_line, end_col = unpack(fn.getpos(end_char), 2, 3)
  local selected_lines = api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  return {
    start_pos = { start_line, start_col },
    end_pos = { end_line, end_col },
    selected_lines = selected_lines,
  }
end

function M.get_visual_selection(res, motion)
  motion = motion or false
  local mode = fn.visualmode()
  if motion then mode = "v" end

  -- line-visual
  -- return lines encompassed by the selection; already in res object
  if mode == "V" then return res.selected_lines end

  if mode == "v" then
    -- regular-visual
    -- return the buffer text encompassed by the selection
    local start_line, start_col = unpack(res.start_pos)
    local end_line, end_col = unpack(res.end_pos)
    -- exclude the last char in text if "selection" is set to "exclusive"
    if opt.selection:get() == "exclusive" then end_col = end_col - 1 end
    return api.nvim_buf_get_text(0, start_line - 1, start_col - 1, end_line - 1, end_col, {})
  end

  -- block-visual
  -- return the lines encompassed by the selection, each truncated by the start and end columns
  if mode == "\x16" then
    local _, start_col = unpack(res.start_pos)
    local _, end_col = unpack(res.end_pos)
    -- exclude the last col of the block if "selection" is set to "exclusive"
    if opt.selection:get() == "exclusive" then end_col = end_col - 1 end
    -- exchange start and end columns for proper substring indexing if needed
    -- e.g. instead of str:sub(10, 5), do str:sub(5, 10)
    if start_col > end_col then
      start_col, end_col = end_col, start_col
    end
    -- iterate over lines, truncating each one
    return vim.tbl_map(function(line) return line:sub(start_col, end_col) end, res.selected_lines)
  end
end

--- Sets a local window option, like `:setlocal`
--- TODO: replace with double-indexing on `vim.wo` when neovim/neovim#20288 (hopefully) merges
---@param win number
---@param option string
---@param value any
function M.wo_setlocal(win, option, value)
  api.nvim_set_option_value(option, value, { scope = "local", win = win })
end

---Returns the list of non-shell child processes running under a terminal process tree
---@param root_pid number
---@return table<{pid: number, name: string}>
function M.get_child_processes(root_pid)
  if not root_pid or fn.executable("pgrep") ~= 1 then return {} end
  local procs = {}
  local known_shells = {
    bash = true,
    zsh = true,
    fish = true,
    sh = true,
    dash = true,
    ksh = true,
    csh = true,
    tcsh = true,
  }

  local function scan(p)
    local handle = io.popen("pgrep -P " .. p .. " -l 2>/dev/null")
    if not handle then return end
    local out = handle:read("*a")
    handle:close()

    for line in out:gmatch("[^\r\n]+") do
      local cpid, cname = line:match("^(%d+)%s+(.+)$")
      if cpid and cname then
        local base_name = cname:match("[^/]+$") or cname
        if known_shells[base_name] then
          -- It's a shell process (wrapper or subshell), check its children
          scan(cpid)
        else
          local is_zombie = false
          local stat_file = io.open("/proc/" .. cpid .. "/status", "r")
          if stat_file then
            local stat = stat_file:read("*a")
            stat_file:close()
            if stat and stat:match("State:%s+[Zz]") then is_zombie = true end
          end

          if not is_zombie then
            table.insert(procs, { pid = tonumber(cpid), name = cname })
          end
        end
      end
    end
  end

  scan(root_pid)
  return procs
end

return M
