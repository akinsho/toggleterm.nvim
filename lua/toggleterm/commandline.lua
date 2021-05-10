local fn = vim.fn
local fmt = string.format

local M = {}

-- \v: Use "verymagic" mode, so we don't need to backslash parens, etc.
-- (['"]): Matches either a single or double quote and store it in \1.
-- %(...)*: Then match zero or more of:
-- \1@![^\\]: A single character that does not match the quote itself (\1@! is a negative lookahead for whatever is in the capture group) or a backslash.
--           So any character other than those. (Or a newline, that's also not matched by the [...] expression.)
-- |: Or...
-- \\.: A backslash followed by any character. Including a second backslash, or the quote, whatever the quoting style was.
-- \1: Finally, a matching closing quote.
--@see: https://vi.stackexchange.com/a/22161
local quoted_regex = [[\v(['"])%(\1@![^\\]|\\.)*\1]]

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

local function parse_argument(str, result)
  --TODO: find a way to make this generic i.e. match all characters before the
  --"=" and the quoted argument after so that other args like "dir" can be quoted
  if str:match("cmd=") then
    local cmd = fn.matchstr(str, quoted_regex)
    if cmd then
      result.cmd = expand(fn.substitute(cmd, [['\|\"]], "", "g"))
    end
  else
    local arg = vim.split(str, "=")
    if #arg > 1 then
      local key, value = arg[1], arg[2]
      if key == "size" then
        value = tonumber(value)
      end
      result[key] = value
    end
  end
  return result
end

---Take a users command arguments in the format "cmd='git commit' dir=~/dotfiles"
---and parse this into a table of arguments
---{cmd = "git commit", dir = "~/dotfiles"}
---TODO: only the cmd argument can handle quotes!
---@param args string
---@return table<string, string|number>
function M.parse(args)
  local result = {}
  if args then
    -- 1. extract the quoted command
    local regex = quoted_regex:gsub("\\v", [[\v\w+\=]])
    local quoted_arg = fn.matchstr(args, regex)
    -- 2. then remove it from the rest of the argument string
    args = fn.substitute(args, regex, "", "g")
    parse_argument(quoted_arg, result)

    local parts = vim.split(args, " ")
    for _, part in ipairs(parts) do
      parse_argument(part, result)
    end
  end
  return result
end

return M
