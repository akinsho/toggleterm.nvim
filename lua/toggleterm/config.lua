local colors = require("toggleterm.colors")
local constants = require("toggleterm.constants")

local M = {}

local L = vim.log.levels

local config = {
  size = 12,
  shade_filetypes = {},
  hide_numbers = true,
  shade_terminals = true,
  insert_mappings = true,
  terminal_mappings = true,
  start_in_insert = true,
  persist_size = true,
  close_on_exit = true,
  direction = "horizontal",
  shading_factor = nil,
  shell = vim.o.shell,
  float_opts = {
    winblend = 0,
  },
}

config.highlights = {
  Normal = {
    guibg = colors.shade_color(colors.get_hex("Normal", "bg"), constants.shading_amount),
  },
  NormalFloat = {
    guibg = colors.get_hex("NormalFloat", "bg"),
  },
  FloatBorder = {
    guifg = colors.get_hex("FloatBorder", "fg"),
    guibg = colors.get_hex("FloatBorder", "bg"),
  },
  EndOfBuffer = {
    guibg = colors.shade_color(colors.get_hex("Normal", "bg"), constants.shading_amount),
  },
  StatusLine = {
    gui = "NONE",
    guibg = colors.shade_color(colors.get_hex("Normal", "bg"), constants.shading_amount),
  },
  StatusLineNC = {
    cterm = "italic",
    gui = "NONE",
    guibg = colors.shade_color(colors.get_hex("StatusLineNC", "bg"), constants.shading_amount),
  },
  SignColumn = {
    guibg = colors.shade_color(colors.get_hex("SignColumn", "bg"), constants.shading_amount),
  },
}

local function handle_deprecations(conf)
  if conf.direction == "window" then
    vim.schedule(function()
      vim.notify(
        "[Toggleterm] The window layout is deprecated please use the 'tab' layout instead",
        L.WARN,
        { title = "Toggleterm" }
      )
    end)
  end
end

--- get the full user config or just a specified value
---@param key string
---@return any
function M.get(key)
  if key then
    return config[key]
  end
  return config
end

function M.set(user_conf)
  if user_conf and type(user_conf) == "table" then
    handle_deprecations(user_conf)
    config = vim.tbl_deep_extend("force", config, user_conf)
  end
  return config
end

return M
