describe(
  "Terminals",
  function()
    --- TODO cannot find toggle term
    require("toggleterm")
    local T = require("toggleterm.terminal")
    local Terminal = T.Terminal
    it(
      "can add numbers",
      function()
        local test = Terminal:new()
        assert.are.same(test.id, 1)
      end
    )
  end
)
