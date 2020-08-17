local fn = vim.fn
-----------------------------------------------------------
-- Export
-----------------------------------------------------------
local M = {}
-----------------------------------------------------------
-- Helpers
-----------------------------------------------------------
function to_rgb(color)
  local r = tonumber(string.sub(color, 2,3), 16)
  local g = tonumber(string.sub(color, 4,5), 16)
  local b = tonumber(string.sub(color, 6), 16)
  return r, g, b
end

-- SOURCE: https://stackoverflow.com/questions/5560248/programmatically-lighten-or-darken-a-hex-color-or-rgb-and-blend-colors
function shade_color(color, percent)
  local r, g, b = to_rgb(color)

  -- If any of the colors are missing return "NONE" i.e. no highlight
  if not r or not g or not b then return "NONE" end

  r = math.floor(tonumber(r * (100 + percent) / 100))
  g = math.floor(tonumber(g * (100 + percent) / 100))
  b = math.floor(tonumber(b * (100 + percent) / 100))

  r = r < 255 and r or 255
  g = g < 255 and g or 255
  b = b < 255 and b or 255

  -- see: https://stackoverflow.com/questions/37796287/convert-decimal-to-hex-in-lua-4
  r = string.format("%x", r)
  g = string.format("%x", g)
  b = string.format("%x", b)

  local rr = string.len(r) == 1 and "0" .. r or r
  local gg = string.len(g) == 1 and "0" .. g or g
  local bb = string.len(b) == 1 and "0" .. b or b

  return "#"..rr..gg..bb
end

-----------------------------------------------------------
-- Darken Terminal
-----------------------------------------------------------
function M.set_highlights(amount)
  local bg_color = fn.synIDattr(fn.hlID('Normal'), 'bg')
  local darkened_bg = shade_color(bg_color, amount)
  vim.cmd('highlight DarkenedPanel guibg='..darkened_bg)
  vim.cmd('highlight DarkenendStatusline gui=NONE guibg='..darkened_bg)
  -- setting cterm to italic is a hack
  -- to prevent the statusline caret issue
  vim.cmd('highlight DarkenendStatuslineNC cterm=italic gui=NONE guibg='..darkened_bg)
end

function M.darken_terminal()
  local highlights = {
    "Normal:DarkenedPanel",
    "VertSplit:DarkenedPanel",
    "StatusLine:DarkenendStatusline",
    "StatusLineNC:DarkenendStatuslineNC",
    "SignColumn:DarkenedPanel",
  }
  vim.cmd('setlocal winhighlight='..table.concat(highlights, ','))
end

return M
