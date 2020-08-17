" Plugin file for terminal.vim
" see: toggleterm/init.lua for more details
if !has('nvim-0.5')
  echoerr 'You need neovim nightly to run this plugin'
  finish
endif

let g:toggleterm_shade_terminals = 1

lua require"toggleterm".setup()

"--------------------------------------------------------------------------------
" Commands
"--------------------------------------------------------------------------------
" count defaults to 1
command! -count=1 -complete=shellcmd -nargs=* TermExec lua require'toggleterm'.exec(<q-args>, <count>, 12)
command! -count=1 ToggleTerm lua require'toggleterm'.toggle(<count>, 12)
