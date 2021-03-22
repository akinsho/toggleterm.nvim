" Plugin file for terminal.vim
" see: toggleterm/init.lua for more details
if !has('nvim-0.5')
  echoerr 'You need neovim nightly to run this plugin'
  finish
endif

"--------------------------------------------------------------------------------
" Commands
"--------------------------------------------------------------------------------
" count defaults to 1
command! -count=1 -complete=shellcmd -nargs=* TermExec lua require'toggleterm'.exec_command(<q-args>)
command! -count=1 -nargs=* ToggleTerm lua require'toggleterm'.toggle_command(<q-args>)
