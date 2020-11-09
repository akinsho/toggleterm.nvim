# nvim-toggleterm.lua

A _neovim_ plugin to persist and toggle multiple terminals during an editing session

![screenshot](./github/toggleterm.gif "Toggleterm in action")

### Orientation (vertical or horizontal)

![vertical orientation](./github/vertical-terms.png)

## Why?

Neovim's terminal is a very cool, but not super ergonomic tool to use. I find that I often want to
set a process going and leave it continue to run in the background. I don't need to see it all the time though.
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

It sort of works fine for the exact use case above, but there are undoubtedly some niggling bugs.

## Roadmap

All I really want this plugin to be is what I described above. A wrapper around the terminal functionality.

It basically (almost) does all that I need it to.

I won't be turning this into a REPL plugin or doing a bunch of complex stuff.
If you find any issues, _please_ consider a _pull request_ not an issue. I won't be breaking my back to maintain
this especially if it isn't broken "on my machine". I'm also going to be pretty conservative about what I add.

### Usage

## NOTE:

This plugin must now be explicitly enabled by using `require"toggleterm".setup{}`

Setting the key to use for toggling the terminal(s) will setup mappings for _insert, normal and terminal_ modes
If you prefix the mapping with a number that particular terminal will be opened.

```lua
require"toggleterm".setup{
  size = 20,
  open_mapping = [[<c-\>]],
  shade_filetypes = {},
  shade_terminals = true
  direction = 'vertical' | 'horizontal'
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

### Statusline

In order to tell each terminal apart you can use the terminal buffer variable `b:toggle_number`
in your statusline

```vim
" this is pseudo code
let statusline .= '%{&ft == "toggleterm" ? "terminal (".b:toggle_number.")" : ""}'
```

This plugin provides 2 commands

### `ToggleTerm`

This is the command the mappings call under the hood. You can use it directly
and prefix it with a count to target a specific terminal.

### `TermExec`

This command allows you to open a terminal with a specific action.
e.g. `2TermExec git status` will run git status in terminal 2.

### Custom commands

You can create your on commands by using the lua functions this plugin provides directly

```vim
command! -count=1 TermGitPush  lua require'toggleterm'.exec("git push",    <count>, 12)
command! -count=1 TermGitPushF lua require'toggleterm'.exec("git push -f", <count>, 12)
```
