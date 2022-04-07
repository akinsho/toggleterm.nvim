local colors = require("toggleterm.colors")
local constants = require("toggleterm.constants")

local M = {}

local L = vim.log.levels

local function shade(color)
  return colors.shade_color(color, constants.shading_amount)
end

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

local function get_highlights(conf)
  conf = conf or config
  local normal_bg = colors.get_hex("Normal", "bg")
  local terminal_bg = conf.shade_terminals and shade(normal_bg) or normal_bg
  local highlights = {
    Normal = {
      guibg = terminal_bg,
    },
    NormalFloat = {
      guibg = normal_bg,
    },
    FloatBorder = {
      guifg = colors.get_hex("Normal", "fg"),
      guibg = normal_bg,
    },
    SignColumn = {
      guibg = terminal_bg,
    },
    EndOfBuffer = {
      guibg = terminal_bg,
    },
    StatusLine = {
      gui = "NONE",
      guibg = terminal_bg,
    },
    StatusLineNC = {
      cterm = "italic",
      gui = "NONE",
      guibg = terminal_bg,
    },
  }
  return highlights
end

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
  end
  local highlights = get_highlights(user_conf)
  config = vim.tbl_deep_extend("force", config, { highlights = highlights }, user_conf or {})
  return config
end

return M
