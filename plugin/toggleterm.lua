---Handle Vim session-saving logic when buffers contain a toggleterm terminal.

---Write `lines` of text to-disk at `path`.
---
---@param lines string[] The text to write.
---@param path string An absolute path on-disk to append `lines` onto.
local function _append_lines(commands, path)
    local handler = io.open(path, "a")

    if not handler then
      vim.api.nvim_err_writeln('Unable to write to  "%s" Sessionx.vim.', path)

      return
    end

    for _, line in ipairs(commands) do
        handler:write(line .. "\n")
    end

    handler:close()
end

---@return string # Get the full path where a Sessionx.vim file should be written to-disk.
local function _get_sessionx_path()
    local path = vim.v.this_session

    if not path then
        return nil
    end

    return vim.fn.fnamemodify(path, ":h") .. "/Sessionx.vim"
end

---Serialize all toggleterm terminals to a Sessionx.vim file so they can be restored later.
local function _save_terminals()
    local commands = require("toggleterm.terminal").get_all_terminal_commands()
    local path = _get_sessionx_path()
    -- IMPORTANT: Ideally in the future we can allow multiple x.vim file support
    -- Reference: https://github.com/akinsho/toggleterm.nvim/issues/567
    vim.fn.delete(path)

    if not commands then
        -- No new terminals needed to be saved
        return
    end

    _append_lines(commands, path)
end

vim.api.nvim_create_autocmd("SessionWritePost", {callback=_save_terminals})
