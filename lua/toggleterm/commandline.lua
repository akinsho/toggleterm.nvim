local fn = vim.fn

local M = {}

local p = {
  single = "'(.-)'",
  double = '"(.-)"',
}

---Take a users command arguments in the format "cmd='git commit' dir=~/dotfiles"
---and parse this into a table of arguments
---{cmd = "git commit", dir = "~/dotfiles"}
---@see https://stackoverflow.com/a/27007701
---@param args string
---@return table<string, string|number>
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
        quotes = jit.os ~= "Windows" and p.single
          or vim.g.shellslash == "yes" and quotes
          or p.single

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
        elseif key == "go_back" then
          value = value ~= "0"
        end
        result[key] = value
      end
    end
  end
  return result
end

return M
