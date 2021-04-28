# nvim-toggleterm.lua

A _neovim_ plugin to persist and toggle multiple terminals during an editing session

![screenshot](./github/toggleterm.gif "Toggleterm in action")

### Multiple orientations

- **Float**

![floating window](https://user-images.githubusercontent.com/22454918/115306123-42d2ac00-a15f-11eb-84fc-c4246ee82a09.png)

- **Vertical**

![vertical orientation](./github/vertical-terms.png)

- **Window**

![window orientation](https://user-images.githubusercontent.com/22454918/115306273-82999380-a15f-11eb-9c2b-57266ca16493.png)

### Send commands to different terminals

![exec](https://user-images.githubusercontent.com/22454918/112119367-36d1e980-8bb5-11eb-9787-5936391127a3.gif)


## Notices

- **23/03/2021**: `TermExec` command syntax has been refactored to use `TermExec cmd='my-command'`

## Requirements

This plugin requires a *recent* **nvim nightly**.

## Why?

Neovim's terminal is a very cool, but not super ergonomic tool to use. I find that I often want to
set a process going and leave it to continue to run in the background. I don't need to see it all the time.
I just need to be able to refer back to it at intervals. I also sometimes want to create a new terminal and run a few commands.

Sometimes I want these side by side, and I _really_ want these terminals to be easy to access and not clutter my buffer list.
I also want my terminal to look different from non-terminal buffers so I use `winhighlight` to darken them based on the `Normal`
background colour.

This is the exact use case this was designed for. If that's your use case this might work for you. If not there are a lot of
much more stable alternatives.

- [neoterm](https://github.com/kassio/neoterm)

## Why Lua?

I wrote this initially in vimscript as part of my `init.vim`. I then realised I wanted to extend the functionality,
but didn't want to end up maintaining a bunch of vimscript I had just managed to hack into place 🤷.

## Roadmap

All I really want this plugin to be is what I described above. A wrapper around the terminal functionality.

It basically (almost) does all that I need it to.

I won't be turning this into a REPL plugin or doing a bunch of complex stuff.
If you find any issues, _please_ consider a _pull request_ not an issue. I won't be breaking my back to maintain
this especially if it isn't broken "on my machine". I'm also going to be pretty conservative about what I add.

### Setup

This plugin must be explicitly enabled by using `require"toggleterm".setup{}`

Setting the key to use for toggling the terminal(s) will setup mappings for _insert, normal and terminal_ modes
If you prefix the mapping with a number that particular terminal will be opened.

**NOTE**: Please ensure you have set `hidden` in your neovim config, otherwise the terminals will be discarded
when closed.

```lua
require"toggleterm".setup{
  size = 20,
  open_mapping = [[<c-\>]],
  hide_numbers = true, -- hide the number column in toggleterm buffers
  shade_filetypes = {},
  shade_terminals = true,
  shading_factor = '<number>', -- the degree by which to darken to terminal colour, default: 1 for dark backgrounds, 3 for light
  start_in_insert = true,
  persist_size = true,
  direction = 'vertical' | 'horizontal' | 'window' | 'float',
  shell = vim.o.shell, -- change the default shell 
  -- This field is only relevant if direction is set to 'float'
  float_opts = {
    -- The border key is *almost* the same as 'nvim_win_open'
    -- see :h nvim_win_open for details on borders however
    -- the 'curved' border is a custom border type
    -- not natively supported but implemented in this plugin.
    border = 'single' | 'double' | 'shadow' | 'curved' | ... other options supported by win open
    width = <value>,
    height = <value>,
    winblend = 3,
    highlights = {
      border = "Normal",
      background = "Normal",
    }
  }
}
```

alternatively you can do this manually (not recommended but, your prerogative)

```vim
" set
let g:toggleterm_terminal_mapping = '<C-t>'
" or manually...
autocmd TermEnter term://*toggleterm#*
      \ tnoremap <silent><c-t> <C-\><C-n>:exe v:count1 . "ToggleTerm"<CR>

" By applying the mappings this way you can pass a count to your
" mapping to open a specific window.
" For example: 2<C-t> will open terminal 2
nnoremap <silent><c-t> :<c-u>exe v:count1 . "ToggleTerm"<CR>
inoremap <silent><c-t> <Esc>:<c-u>exe v:count1 . "ToggleTerm"<CR>
```

### Usage

This plugin provides 2 commands

### `ToggleTerm`

This is the command the mappings call under the hood. You can use it directly
and prefix it with a count to target a specific terminal. This function also takes
a the `size` and `dir` as an argument e.g.

```vim
:ToggleTerm size=40 dir=~/Desktop
```

If specified on creation toggle term will open at the specified directory at the
specified height.

_NOTE_: If the terminal has already been opened at a particular directory it will
remain in that dir

### `TermExec`

This command allows you to open a terminal with a specific action.
e.g. `2TermExec cmd="git status" dir=~/<my-repo-path>` will run git status in terminal 2.
note that the `cmd` argument is quoted so that can it can be distinguished from the `dir`
argument.

### Set terminal shading

This plugin automatically shades terminal filetypes to be darker than other window
you can disable this by setting `shade_terminals = false` in the setup object

```lua
require'toggleterm'.setup{
  shade_terminals = false
}
```

alternatively you can set _which_ filetypes should be shaded by setting

```lua
-- fzf is just an example
require'toggleterm'.setup{
  shade_filetypes = { "none", "fzf" }
}

```

setting `"none"` will allow normal terminal buffers to be highlighted.

### Set persistent size

By default, this plugin will persist the size of the terminal split. You can disable
this behaviour by setting `persist_size = false` in the setup object. Disabling this
behaviour forces the opening terminal size to the `size` defined in the setup object.

```lua
require'toggleterm'.setup{
  persist_size = false
}
```

### Custom Terminals

![lazy git](https://user-images.githubusercontent.com/22454918/116447435-e69f1480-a84f-11eb-86dd-19fa29646aa1.png)
*using [lazygit](https://github.com/jesseduffield/lazygit)*

Toggleterm also exposes the `Terminal` class so that this can be used to create custom terminals
for showing terminal UIs like `lazygit`, `htop` etc.

Each terminal can take the following arguments:
```lua
Terminal:new {
  cmd =  string -- command to execute when creating the terminal e.g. 'top'
  direction = string -- the layout for the terminal, same as the main config options
  dir = string -- the directory for the terminal
  on_open = fun(t: Terminal) -- function to run when the terminal opens
  on_close = fun(t: Terminal) -- function to run when the terminal closes
  -- callbacks for processing the output
  on_stdout = fun(job: number, exit_code: number, type: string)
  on_stderr = fun(job: number, data: string[], name: string)
  on_exit = fun(job: number, data: string[], name: string)
}
```

#### Usage
```lua
local Terminal  = require('toggleterm.terminal').Terminal
local lazygit = Terminal:new({ cmd = "lazygit", hidden = true })

function _lazygit_toggle()
  lazygit:toggle()
end

vim.api.nvim_set_keymap("n", "<leader>g", "<cmd>lua _lazygit_toggle()<CR>", {noremap = true, silent = true})
```

This will create a new terminal that runs the specified command once toggled
if the `hidden` key is set to true. This terminal will not be toggled by normal toggleterm
commands such as `:ToggleTerm` or the open mapping. It will only open and close in response to a user
specified mapping like the above.

Alternatively the terminal can be specified with a count which is the number that can be used
to trigger this specific terminal. This can then be triggered using the current count e.g.
`:5ToggleTerm<CR>`

```lua
local lazygit = Terminal:new({ cmd = "lazygit", count = 5 })
```

You can also set a custom layout for a terminal.
```lua
local lazygit = Terminal:new({
  cmd = "lazygit",
  direction = "float",
  float_opts = {
    border = "double",
  },
  -- function to run on opening the terminal
  on_open = function(term)
    vim.api.nvim_buf_set_keymap(term.bufnr, "n", "q", "<cmd>close<CR>", {noremap = true, silent = true})
  end,
  -- function to run on closing the terminal
  on_close = function(term)
    vim.cmd("Closing terminal")
  end,
})

function _lazygit_toggle()
  lazygit:toggle()
end

vim.api.nvim_set_keymap("n", "<leader>g", "<cmd>lua _lazygit_toggle()<CR>", {noremap = true, silent = true})
```

**WARNING**: do not use any of the private functionality of the terminal or other non-public parts of the API as these
can change in the future.

### Statusline

In order to tell each terminal apart you can use the terminal buffer variable `b:toggle_number`
in your statusline

```vim
" this is pseudo code
let statusline .= '%{&ft == "toggleterm" ? "terminal (".b:toggle_number.")" : ""}'
```

### Custom commands

You can create your on commands by using the lua functions this plugin provides directly

```vim
command! -count=1 TermGitPush  lua require'toggleterm'.exec("git push",    <count>, 12)
command! -count=1 TermGitPushF lua require'toggleterm'.exec("git push -f", <count>, 12)
```
