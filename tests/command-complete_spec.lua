describe("command-complete", function()
  local command_complete = require("toggleterm.commandline")
  it("should return the default options", function()
    local results = command_complete.term_exec_complete("", "TermExec ", 9)

    assert.is_equal("cmd=, dir=, direction=, size=", table.concat(results, ", "))
  end)

  describe("helpers", function()
    it("should validate relative paths", function()
      local cwd, no_search_term = command_complete.get_path_parts("")
      assert.is_equal(nil, no_search_term)
      assert.is_equal("", cwd)

      local partial_path, search_term = command_complete.get_path_parts(".github/work")
      assert.is_equal(".github", partial_path)
      assert.is_equal("work", search_term)

      local path_with_slash, _ = command_complete.get_path_parts(".github/")
      assert.is_equal(".github", path_with_slash)

      local path_without_slash, _ = command_complete.get_path_parts(".github")
      assert.is_equal(".github", path_without_slash)
    end)
  end)

  describe("cmd=", function()
    it("should return all the commands in $PATH", function()
      local results = command_complete.term_exec_complete("cmd=", "ToggleExec cmd=", 16)

      assert.is_not_equal(0, #results)
    end)

    it("should return matching commands in $PATH", function()
      local results = command_complete.term_exec_complete("cmd=m", "ToggleExec cmd=m", 16)

      assert.is_not_equal(0, #results)
      assert.is_true(vim.tbl_contains(results, "cmd=mv"))
      assert.is_true(vim.tbl_contains(results, "cmd=mkdir"))
    end)
  end)

  describe("dir=", function()
    it("should return all directories in the cwd", function()
      local results = command_complete.term_exec_complete("dir=", "ToggleExec dir=", 16)

      assert.is_not_equal(0, #results)
    end)

    it("should return matching subdirectories", function()
      local results =
        command_complete.term_exec_complete("dir=.github/wor", "ToggleExec dir=.github/wor", 27)

      assert.is_equal("dir=.github/workflows", table.concat(results, ", "))
    end)

    it("should handle empty dir values", function()
      local results = command_complete.term_exec_complete("dir", "ToggleExec dir", 15)

      assert.is_not_equal(0, #results)
    end)
  end)

  describe("directions=", function()
    it("should return all directions", function()
      local results = command_complete.term_exec_complete("direction=", "TermExec direction=", 19)

      assert.equal(
        table.concat({
          "direction=float",
          "direction=horizontal",
          "direction=tab",
          "direction=vertical",
        }, ", "),
        table.concat(results, ", ")
      )
    end)

    it("should return partiall typed directions", function()
      local results =
        command_complete.term_exec_complete("direction=ver", "TermExec direction=ver", 22)

      assert.equal("direction=vertical", table.concat(results, ", "))
    end)
  end)
end)
