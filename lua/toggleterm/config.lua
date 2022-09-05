local colors = require("toggleterm.colors")
local constants = require("toggleterm.constants")
local utils = require("toggleterm.utils")

local M = {}

local fmt = string.format

local function shade(color, factor) return colors.shade_color(color, factor) end

--- @alias ToggleTermHighlights table<string, table<string, string>>

---@class WinbarOpts
---@field name_formatter fun(term: Terminal):string
---@field enabled boolean

--- @class ToggleTermConfig
--- @field size number
--- @field shade_filetypes string[]
--- @field hide_numbers boolean
--- @field open_mapping string
--- @field shade_terminals boolean
--- @field insert_mappings boolean
--- @field terminal_mappings boolean
--- @field start_in_insert boolean
--- @field persist_size boolean
--- @field persist_mode boolean
--- @field close_on_exit boolean
--- @field direction  '"horizontal"' | '"vertical"' | '"float"'
--- @field shading_factor number
--- @field shell string
--- @field auto_scroll boolean
--- @field float_opts table<string, any>
--- @field highlights ToggleTermHighlights
--- @field winbar WinbarOpts
--- @field autochdir boolean

---@type ToggleTermConfig
local config = {
  size = 12,
  shade_filetypes = {},
  hide_numbers = true,
  shade_terminals = true,
  insert_mappings = true,
  terminal_mappings = true,
  start_in_insert = true,
  persist_size = true,
  persist_mode = false,
  close_on_exit = true,
  direction = "horizontal",
  shading_factor = constants.shading_amount,
  shell = vim.o.shell,
  autochdir = false,
  auto_scroll = true,
  winbar = {
    enabled = false,
    name_formatter = function(term) return fmt("%d:%s", term.id, term:_display_name()) end,
  },
  float_opts = {
    winblend = 0,
  },
}

---Derive the highlights for a toggleterm and merge these with the user's preferences
---A few caveats must be noted. Since I link the normal and float border to the Normal
---highlight this has to be done carefully as if the user has specified any Float highlights
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
  local nightly = utils.is_nightly()

  local comment_fg = colors.get_hex("Comment", "fg")
  local dir_fg = colors.get_hex("Directory", "fg")

  local winbar_inactive_opts = { guifg = comment_fg }
  local winbar_active_opts = { guifg = dir_fg, gui = "underline" }

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
    -- TODO: Move this to the main overrides block once nvim 0.8 is stable
    if nightly then
      winbar_inactive_opts.guibg = terminal_bg
      winbar_active_opts.guibg = terminal_bg
      overrides.WinBarNC = { guibg = terminal_bg }
      overrides.WinBar = { guibg = terminal_bg }
    end
  end

  if nightly and conf.winbar.enabled then
    colors.set_hl("WinBarActive", winbar_active_opts)
    colors.set_hl("WinBarInactive", winbar_inactive_opts)
  end

  return vim.tbl_deep_extend("force", defaults, conf.highlights, overrides)
end

--- get the full user config or just a specified value
---@param key string?
---@return any
function M.get(key)
  if key then return config[key] end
  return config
end

function M.reset_highlights() config.highlights = get_highlights(config) end

---@param user_conf ToggleTermConfig
---@return ToggleTermConfig
function M.set(user_conf)
  user_conf = user_conf or {}
  user_conf.highlights = user_conf.highlights or {}
  config = vim.tbl_deep_extend("force", config, user_conf)
  config.highlights = get_highlights(config)
  return config
end

---@return ToggleTermConfig
return setmetatable(M, {
  __index = function(_, k) return config[k] end,
})
