local fmt = string.format

describe("Commandline tests:", function()
  local parser = require("toggleterm.commandline")
  it("should return a table containg correct arguments", function()
    local file = vim.fn.tempname() .. ".txt"
    vim.cmd(fmt("e %s", file))
    local result = parser.parse("cmd='echo %' dir='/test dir/file.txt'")
    assert.is_truthy(result.cmd)
    assert.is_truthy(result.dir)

    assert.equal(fmt("echo %s", file), result.cmd)
    assert.equal("/test dir/file.txt", result.dir)
  end)

  it("should handle double quotes", function()
    local result = parser.parse('cmd="git status"')
    assert.truthy(result.cmd)
    assert.equal("git status", result.cmd)
  end)

  it("should handle non-quoted arguments", function()
    local result = parser.parse("direction=horizontal dir=/test/file.txt")
    assert.is_truthy(result.dir)
    assert.is_truthy(result.direction)
    assert.equal("/test/file.txt", result.dir)
    assert.equal("horizontal", result.direction)
  end)

  it("should handle size args correctly", function()
    local result = parser.parse("size=34")
    assert.is_truthy(result.size)
    assert.is_true(type(result.size) == "number")
    assert.equal(34, result.size)
  end)

  it("should handle go_back args correctly", function()
    local result = parser.parse("go_back=0")
    assert.is_true(type(result.go_back) == "boolean")
    assert.is_false(result.go_back)
  end)

  it("should handle open args correctly", function()
    local result = parser.parse("open=0")
    assert.is_true(type(result.open) == "boolean")
    assert.is_false(result.open)
  end)
end)
