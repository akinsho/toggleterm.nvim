_G.IS_TEST = true

local toggleterm = require("toggleterm")
local t = require("toggleterm.terminal")

local Terminal = t.Terminal

describe("Terminal state - ", function()
  vim.o.hidden = true
  toggleterm.setup({ start_in_insert = true })

  after_each(function()
    require("toggleterm.terminal").__reset()
  end)

  it("should persist the terminal state when the window is closed", function()
    local term = Terminal:new()
    term:open()
    vim.wait(500)
    term:close()
    vim.wait(500)
    assert.is_not_true(vim.bo.buftype, "terminal")

    assert.equal(term.__state.mode, t.mode.INSERT)
  end)

  it("should restore the terminal state when the window is re-opened", function()
    local term = Terminal:new()
    term:open()
    vim.cmd("startinsert")
    vim.wait(500)
    term:close()
    vim.wait(500)

    term:open()
    vim.wait(500)
    assert.equal(term.__state.mode, t.mode.INSERT)
  end)
end)
