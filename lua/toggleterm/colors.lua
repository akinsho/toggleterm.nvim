local fn = vim.fn
-----------------------------------------------------------
-- Export
-----------------------------------------------------------
local M = {}
-----------------------------------------------------------
-- Helpers
-----------------------------------------------------------
---Convert a hex color to an rgb color
---@param color string
---@return number
---@return number
---@return number
local function to_rgb(color)
  return tonumber(color:sub(2, 3), 16), tonumber(color:sub(4, 5), 16), tonumber(color:sub(6), 16)
end

-- SOURCE: https://stackoverflow.com/questions/5560248/programmatically-lighten-or-darken-a-hex-color-or-rgb-and-blend-colors
local function shade_color(color, percent)
  local r, g, b = to_rgb(color)
  -- If any of the colors are missing return "NONE" i.e. no highlight
  if not r or not g or not b then
    return "NONE"
  end
  r = math.floor(tonumber(r * (100 + percent) / 100))
  g = math.floor(tonumber(g * (100 + percent) / 100))
  b = math.floor(tonumber(b * (100 + percent) / 100))
  r, g, b = r < 255 and r or 255, g < 255 and g or 255, b < 255 and b or 255

  -- see: https://stackoverflow.com/questions/37796287/convert-decimal-to-hex-in-lua-4
  r, g, b = string.format("%0x", r), string.format("%0x", g), string.format("%0x", b)
  return "#" .. r .. g .. b
end

--- Determine whether to use black or white text
--- Ref:
--- 1. https://stackoverflow.com/a/1855903/837964
--- 2. https://stackoverflow.com/a/596243
function M.color_is_bright(hex)
  if not hex then
    return false
  end
  local r, g, b = to_rgb(hex)
  -- If any of the colors are missing return false
  if not r or not g or not b then
    return false
  end
  -- Counting the perceptive luminance - human eye favors green color
  local luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
  -- If luminance is > 0.5 -> Bright colors, black font else Dark colors, white font
  return luminance > 0.5
end

function M.is_bright_background()
  local bg_color = fn.synIDattr(fn.hlID("Normal"), "bg")
  return M.color_is_bright(bg_color)
end

-----------------------------------------------------------
-- Darken Terminal
-----------------------------------------------------------
function M.set_highlights(amount)
  local bg_color = fn.synIDattr(fn.hlID("Normal"), "bg")
  local darkened_bg = shade_color(bg_color, amount)
  vim.cmd("highlight DarkenedPanel guibg=" .. darkened_bg)
  vim.cmd("highlight DarkenedStatusline gui=NONE guibg=" .. darkened_bg)
  -- setting cterm to italic is a hack
  -- to prevent the statusline caret issue
  vim.cmd("highlight DarkenedStatuslineNC cterm=italic gui=NONE guibg=" .. darkened_bg)
end

return M
