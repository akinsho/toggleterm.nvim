local fn = vim.fn
local fmt = string.format

local M = {}

local wildcards = fmt(
  [[\(%s\)]],
  (table.concat({
    "%",
    "#",
    "#\\d",
    "<cfile>",
    "<afile>",
    "<abuf>",
    "<amatch>",
    "<cexpr>",
    "<sfile>",
    "<slnum>",
    "<sflnum>",
    "<SID>",
    "<stack>",
    "<cword>",
    "<cWORD>",
    "<client>",
  }, [[\|]]))
)

---Expand wildcards similar to `:h expand`
---all credit to @voldkiss for this vim regex wizadry
---https://github.com/voldikss/vim-floaterm/blob/master/autoload/floaterm/cmdline.vim#L51
---@param cmd string
---@return string
local function expand(cmd)
  cmd = fn.substitute(
    cmd,
    [[\([^\\]\|^\)\zs]] .. wildcards .. [[\(<\|\(\(:g\=s?.*?.*?\)\|\(:[phtreS8\~\.]\)\)*\)\ze]],
    [[\=expand(submatch(0))]],
    "g"
  )
  cmd = fn.substitute(cmd, [[\zs\\]] .. wildcards, [=[\=submatch(0)[1:]]=], "g")
  return cmd
end

local p = {
  single = "'(.-)'",
  double = '"(.-)"',
}

---Take a users command arguments in the format "cmd='git commit' dir=~/dotfiles"
---and parse this into a table of arguments
---{cmd = "git commit", dir = "~/dotfiles"}
---@param args string
---@return table<string, string|number>
function M.parse(args)
  local result = {}
  if args then
    local quotes = args:match(p.single) and p.single or args:match(p.double) and p.double or nil
    if quotes then
      -- 1. extract the quoted command
      local pattern = "([^=-]+)=" .. quotes
      for key, value in args:gmatch(pattern) do
        value = fn.shellescape(value)
        result[vim.trim(key)] = expand(value:match(quotes))
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
        end
        result[key] = value
      end
    end
  end
  return result
end

return M
