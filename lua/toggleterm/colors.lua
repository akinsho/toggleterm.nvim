local fn = vim.fn
local api = vim.api
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
--- Shade Color generate
--- @param color string hex color
--- @param percent number
--- @return string
function M.shade_color(color, percent)
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
  r, g, b = string.format("%02x", r), string.format("%02x", g), string.format("%02x", b)
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

--- Get hex color
---@param hlgroup_name string highlight group name
---@param attr string attr name 'bg', 'fg'
---@return string
function M.get_hex(hlgroup_name, attr)
  local hlgroup_ID = fn.synIDtrans(fn.hlID(hlgroup_name))
  local hex = fn.synIDattr(hlgroup_ID, attr)
  return hex ~= "" and hex or "NONE"
end

--- Check if background is bright
--- @return boolean
function M.is_bright_background()
  local bg_color = M.get_hex("Normal", "bg")
  return M.color_is_bright(bg_color)
end

-----------------------------------------------------------
-- Darken Terminal
-----------------------------------------------------------

local function convert_attributes(result, key, value)
  local target = result
  if key == "cterm" then
    result.cterm = {}
    target = result.cterm
  end
  if value:find(",") then
    for _, v in vim.split(value, ",") do
      target[v] = true
    end
  else
    target[value] = true
  end
end

local function convert_options(opts)
  local keys = {
    gui = true,
    guifg = "foreground",
    guibg = "background",
    guisp = "sp",
    cterm = "cterm",
    ctermfg = "ctermfg",
    ctermbg = "ctermbg",
    link = "link",
  }
  local result = {}
  for key, value in pairs(opts) do
    if keys[key] then
      if key == "gui" or key == "cterm" then
        if value ~= "NONE" then
          convert_attributes(result, key, value)
        end
      else
        result[keys[key]] = value
      end
    end
  end
  return result
end

function M.set_hl(name, opts)
  api.nvim_set_hl(0, name, convert_options(opts))
end

return M
