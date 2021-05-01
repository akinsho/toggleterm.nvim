local M = {}

local config = {
  size = 12,
  shade_filetypes = {},
  hide_numbers = true,
  shade_terminals = true,
  insert_mappings = true,
  start_in_insert = true,
  persist_size = true,
  close_on_exit = true,
  direction = "horizontal",
  shading_factor = nil,
  shell = vim.o.shell,
  float_opts = {
    winblend = 3,
    highlights = {
      background = "Normal",
      border = "Normal",
    },
  },
}

--- get the full user config or just a specified value
---@param key string
---@return table | string | number
function M.get(key)
  if key then
    return config[key]
  end
  return config
end

function M.set(user_conf)
  if user_conf and type(user_conf) == "table" then
    config = vim.tbl_deep_extend("force", config, user_conf)
  end
  return config
end

return M
