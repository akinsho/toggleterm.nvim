local colors = require("toggleterm.colors")
local constants = require("toggleterm.constants")

local M = {}

local L = vim.log.levels

local function shade(color, factor)
  return colors.shade_color(color, factor)
end

--- @alias ToggleTermHighlights table<string, table<string, string>>

--- @class ToggleTermConfig
--- @field size number
--- @field shade_filetypes string[]
--- @field hide_numbers boolean
--- @field shade_terminals boolean
--- @field insert_mappings boolean
--- @field terminal_mappings boolean
--- @field start_in_insert boolean
--- @field persist_size boolean
--- @field close_on_exit boolean
--- @field direction  '"horizontal"' | '"vertical"' | '"float"'
--- @field shading_factor number
--- @field shell string
--- @field float_opts table<string, any>
--- @field highlights ToggleTermHighlights

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
  shading_factor = constants.shading_amount,
  shell = vim.o.shell,
  float_opts = {
    winblend = 0,
  },
}

---Derive the highlights for a toggleterm and merge these with the user's preferences
---@param conf ToggleTermConfig
---@return ToggleTermHighlights
local function get_highlights(conf)
  local normal_bg = colors.get_hex("Normal", "bg")
  local terminal_bg = conf.shade_terminals and shade(normal_bg, conf.shading_factor) or normal_bg
  return vim.tbl_deep_extend("force", {
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
  }, conf.highlights or {})
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

---@param user_conf ToggleTermConfig
---@return ToggleTermConfig
function M.set(user_conf)
  if user_conf and type(user_conf) == "table" then
    handle_deprecations(user_conf)
  end
  config = vim.tbl_deep_extend("force", config, user_conf or {})
  config.highlights = get_highlights(config)
  return config
end

return M
