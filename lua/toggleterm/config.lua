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
---A few caveats must be noted. Since I link the normal and float border to the Normal
---highlight this has to be done carefully as if the user has speficied any Float highlights
---themselves merging will result in a mix of user highlights and the link key which is invalid
---so I check that they have not attempted to highlight these themselves. Also
---if they have chosen to shade the terminal then this takes priority over their own highlights
---since they can't have it both ways i.e. custom highlighting and shading
---@param conf ToggleTermConfig
---@return ToggleTermHighlights
local function get_highlights(conf)
  local user = conf.highlights
  local defaults = {
    NormalFloat = vim.F.if_nil(user.NormalFloat, { link = "Normal" }),
    FloatBorder = vim.F.if_nil(user.FloatBorder, { link = "Normal" }),
    StatusLine = { gui = "NONE" },
    StatusLineNC = { cterm = "italic", gui = "NONE" },
  }
  local overrides = {}

  if conf.shade_terminals then
    local is_bright = colors.is_bright_background()
    local degree = is_bright and -3 or 1
    local amount = conf.shading_factor * degree
    local normal_bg = colors.get_hex("Normal", "bg")
    local terminal_bg = conf.shade_terminals and shade(normal_bg, amount) or normal_bg
    overrides = {
      Normal = { guibg = terminal_bg },
      SignColumn = { guibg = terminal_bg },
      EndOfBuffer = { guibg = terminal_bg },
      StatusLine = { guibg = terminal_bg },
      StatusLineNC = { guibg = terminal_bg },
    }
  end
  return vim.tbl_deep_extend("force", defaults, conf.highlights, overrides)
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
---@param key string?
---@return any
function M.get(key)
  if key then
    return config[key]
  end
  return config
end

function M.reset_highlights()
  config.highlights = get_highlights(config)
end

---@param user_conf ToggleTermConfig
---@return ToggleTermConfig
function M.set(user_conf)
  user_conf = user_conf or {}
  user_conf.highlights = user_conf.highlights or {}
  if user_conf and type(user_conf) == "table" then
    handle_deprecations(user_conf)
  end
  config = vim.tbl_deep_extend("force", config, user_conf)
  config.highlights = get_highlights(config)
  return config
end

---@return ToggleTermConfig
return setmetatable(M, {
  __index = function(_, k)
    return config[k]
  end,
})
