local fn = vim.fn
local u = require("toggleterm.utils")

local M = {}

local p = {
  single = "'(.-)'",
  double = '"(.-)"',
}

local is_windows = vim.loop.os_uname().version:match("Windows")

---@class ParsedArgs
---@field direction string?
---@field cmd string?
---@field dir string?
---@field size number?
---@field go_back boolean?
---@field open boolean?

---Take a users command arguments in the format "cmd='git commit' dir=~/dotfiles"
---and parse this into a table of arguments
---{cmd = "git commit", dir = "~/dotfiles"}
---@see https://stackoverflow.com/a/27007701
---@param args string
---@return ParsedArgs
function M.parse(args)
  local result = {}
  if args then
    local quotes = args:match(p.single) and p.single or args:match(p.double) and p.double or nil
    if quotes then
      -- 1. extract the quoted command
      local pattern = "(%S+)=" .. quotes
      for key, value in args:gmatch(pattern) do
        -- Check if the current OS is Windows so we can determine if +shellslash
        -- exists and if it exists, then determine if it is enabled. In that way,
        -- we can determine if we should match the value with single or double quotes.
        if is_windows then
          quotes = not vim.opt.shellslash:get() and quotes or p.single
        else
          quotes = p.single
        end
        value = fn.shellescape(value)
        result[vim.trim(key)] = fn.expandcmd(value:match(quotes))
      end
      -- 2. then remove it from the rest of the argument string
      args = args:gsub(pattern, "")
    end

    for _, part in ipairs(vim.split(args, " ")) do
      if #part > 1 then
        local arg = vim.split(part, "=")
        local key, value = arg[1], arg[2]
        if key == "size" then
          value = tonumber(value)
        elseif key == "go_back" or key == "open" then
          value = value ~= "0"
        end
        result[key] = value
      end
    end
  end
  return result
end

-- Get a valid base path for a user provided path
-- and an optional search term
---@param typed_path string
---@return string|nil, string|nil
function M.get_path_parts(typed_path)
  if vim.fn.isdirectory(typed_path ~= "" and typed_path or ".") == 1 then
    -- The string is a valid path, we just need to drop trailing slashes to
    -- ease joining the base path with the suggestions
    return typed_path:gsub("/$", ""), nil
  elseif typed_path:find("/", 2) ~= nil then
    -- Maybe the typed path is looking for a nested directory
    -- we need to make sure it has at least one slash in it, and that is not
    -- from a root path
    local base_path = vim.fn.fnamemodify(typed_path, ":h")
    local search_term = vim.fn.fnamemodify(typed_path, ":t")
    if vim.fn.isdirectory(base_path) then return base_path, search_term end
  end

  return nil, nil
end

local term_exec_options = {
  --- Suggests commands
  ---@param typed_cmd string|nil
  cmd = function(typed_cmd)
    local paths = vim.split(vim.env.PATH, ":")
    local commands = {}

    for _, path in ipairs(paths) do
      local glob_str = path .. "/" .. (typed_cmd or "") .. "*"
      local dir_cmds = vim.split(vim.fn.glob(glob_str), "\n")

      for _, cmd in ipairs(dir_cmds) do
        if not u.str_is_empty(cmd) then table.insert(commands, vim.fn.fnamemodify(cmd, ":t")) end
      end
    end

    return commands
  end,
  --- Suggests paths in the cwd
  ---@param typed_path string
  dir = function(typed_path)
    -- Read the typed path as the base for the directory search
    local base_path, search_term = M.get_path_parts(typed_path or "")
    local safe_path = base_path ~= "" and base_path or "."

    local paths = vim.fn.readdir(
      safe_path,
      function(entry) return vim.fn.isdirectory(safe_path .. "/" .. entry) end
    )

    if not u.str_is_empty(search_term) then
      paths = vim.tbl_filter(
        function(path) return path:match("^" .. search_term .. "*") ~= nil end,
        paths
      )
    end

    return vim.tbl_map(
      function(path) return u.concat_without_empty({ base_path, path }, "/") end,
      paths
    )
  end,
  --- Suggests directions for the term
  ---@param typed_direction string
  direction = function(typed_direction)
    local directions = {
      "float",
      "horizontal",
      "tab",
      "vertical",
    }
    if u.str_is_empty(typed_direction) then return directions end
    return vim.tbl_filter(
      function(direction) return direction:match("^" .. typed_direction .. "*") ~= nil end,
      directions
    )
  end,
  --- The size param takes in arbitrary numbers, we keep this function only to
  --- match the signature of other options
  size = function() return {} end,
}

local toggle_term_options = {
  dir = term_exec_options.dir,
  direction = term_exec_options.direction,
  size = term_exec_options.size,
}

---@param options table a dictionary of key to function
---@return fun(lead: string, command: string, _: number)
local function complete(options)
  ---@param lead string the leading portion of the argument currently being completed on
  ---@param command string the entire command line
  ---@param _ number the cursor position in it (byte index)
  return function(lead, command, _)
    local parts = vim.split(lead, "=")
    local key = parts[1]
    local value = parts[2]
    if options[key] then
      return vim.tbl_map(function(option) return key .. "=" .. option end, options[key](value))
    end

    local available_options = vim.tbl_filter(
      function(option) return command:match(" " .. option .. "=") == nil end,
      vim.tbl_keys(options)
    )

    table.sort(available_options)

    return vim.tbl_map(function(option) return option .. "=" end, available_options)
  end
end

--- See :h :command-completion-custom
M.term_exec_complete = complete(term_exec_options)

--- See :h :command-completion-custom
M.toggle_term_complete = complete(toggle_term_options)

return M
