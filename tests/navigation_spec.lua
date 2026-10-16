local nav = require("toggleterm.navigation")

describe("Navigation tests:", function()
  describe("get_file_under_cursor parsing", function()
    it("should parse file with line and column", function()
      local line = "Error in src/main.lua:42:15: syntax error"
      local col = 15 -- inside 'src/main.lua:42:15'
      local file, lnum, colnr = nav.get_file_under_cursor(line, col)
      assert.equal("src/main.lua", file)
      assert.equal(42, lnum)
      assert.equal(15, colnr)
    end)

    it("should parse file with line only", function()
      local line = "--> src/utils.lua:100"
      local col = 10
      local file, lnum, colnr = nav.get_file_under_cursor(line, col)
      assert.equal("src/utils.lua", file)
      assert.equal(100, lnum)
      assert.is_nil(colnr)
    end)

    it("should parse plain file without line/column", function()
      local line = "opening config/nvim/init.lua now"
      local col = 15
      local file, lnum, colnr = nav.get_file_under_cursor(line, col)
      assert.equal("config/nvim/init.lua", file)
      assert.is_nil(lnum)
      assert.is_nil(colnr)
    end)

    it("should parse Python traceback format", function()
      local line = '  File "app.py", line 42, in my_func'
      local col = 12
      local file, lnum = nav.get_file_under_cursor(line, col)
      assert.equal("app.py", file)
      assert.equal(42, lnum)
    end)

    it("should handle brackets and parentheses delimiters", function()
      local line = "([src/parser.lua:25:3]) failed"
      local col = 6
      local file, lnum, colnr = nav.get_file_under_cursor(line, col)
      assert.equal("src/parser.lua", file)
      assert.equal(25, lnum)
      assert.equal(3, colnr)
    end)

    it("should return nil when cursor is on whitespace or empty line", function()
      local line = "   "
      local col = 2
      local file = nav.get_file_under_cursor(line, col)
      assert.is_nil(file)
    end)
  end)
end)
