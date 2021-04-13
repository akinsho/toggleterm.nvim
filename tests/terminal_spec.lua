local api = vim.api

describe(
  "Terminals",
  function()
    local toggleterm = require("toggleterm")

    local ui = require("toggleterm.ui")
    local t = require("toggleterm.terminal")

    ---@type Terminal
    local Terminal = t.Terminal
    ---@type Terminal[]
    local terminals

    ---Return if a terminal has windows
    ---@param term table
    ---@return any
    local function term_has_windows(term)
      return ui.find_open_windows(
        function(buf)
          return buf == term.bufnr
        end
      )
    end

    before_each(
      function()
        terminals = require("toggleterm.terminal").get_all()

        toggleterm.setup {
          open_mapping = [[<c-\>]]
        }
      end
    )

    after_each(
      function()
        require("toggleterm.terminal").reset()
      end
    )

    it(
      "new terminals are assigned incremental ids",
      function()
        local test1 = Terminal:new():toggle()
        local test2 = Terminal:new():toggle()
        local test3 = Terminal:new():toggle()
        assert.are.same(test1.id, 1)
        assert.are.same(test2.id, 2)
        assert.are.same(test3.id, 3)
      end
    )

    it(
      "should open a terminal window on toggle",
      function()
        local test1 = Terminal:new()
        test1:toggle()
        assert.is_true(api.nvim_buf_is_valid(test1.bufnr))
        assert.is_true(vim.tbl_contains(api.nvim_list_wins(), test1.window))
      end
    )

    it(
      "should close a terminal window if open",
      function()
        local test1 = Terminal:new()
        test1:toggle()
        assert.is_true(vim.tbl_contains(api.nvim_list_wins(), test1.window))
        test1:toggle()
        assert.is_not_true(vim.tbl_contains(api.nvim_list_wins(), test1.window))
      end
    )

    it(
      "should toggle a specific buffer if a count is passed",
      function()
        toggleterm.toggle(2, 15)
        assert.equals(#terminals, 1)
        local term = terminals[1]
        assert.is_true(term_has_windows(term))
      end
    )
  end
)
