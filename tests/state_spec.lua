_G.IS_TEST = true

local t = require("toggleterm.terminal")

local Terminal = t.Terminal

describe("Terminal state - ", function()
  local toggleterm
  vim.o.hidden = true
  vim.o.swapfile = false

  before_each(function()
    package.loaded["toggleterm"] = nil
    toggleterm = require("toggleterm")
    toggleterm.setup({ start_in_insert = true })
  end)

  after_each(function() require("toggleterm.terminal").__reset() end)

  -- TODO: this test fails because (I think) the shell takes some time to start up and
  -- and so the right autocommands haven't fired yet
  pending("should persist the terminal state when the window is closed", function()
    vim.cmd("edit test.txt")
    local term = Terminal:new():toggle()
    assert.is_equal(vim.bo.buftype, "terminal")
    vim.api.nvim_feedkeys("ils", "x", true)
    assert.is.equal("ls", vim.api.nvim_get_current_line())
    term:close()
    assert.is_not_equal(vim.bo.buftype, "terminal")
    assert.equal(t.mode.INSERT, term.__state.mode)
  end)

  pending("should restore the terminal state when the window is re-opened", function()
    local term = Terminal:new():toggle()
    term:close()
    term:open()
    assert.equal(term.__state.mode, t.mode.UNSUPPORTED)
    term:set_mode(t.mode.INSERT)
    vim.cmd("wincmd p")
    vim.cmd("wincmd p")
    assert.equal(term.__state.mode, t.mode.INSERT)
  end)
end)
