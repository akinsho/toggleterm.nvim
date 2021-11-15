" Plugin file for terminal.vim
" see: toggleterm/init.lua for more details
if !has('nvim-0.5')
  echoerr 'You need neovim nightly to run this plugin'
  finish
endif

"--------------------------------------------------------------------------------
" Commands
"--------------------------------------------------------------------------------
" Count is 0 by default
command! -count -complete=shellcmd -nargs=* TermExec lua require'toggleterm'.exec_command(<q-args>, <count>)
command! -count -nargs=* ToggleTerm lua require'toggleterm'.toggle_command(<q-args>, <count>)
command! ToggleTermToggleAll lua require'toggleterm'.toggle_all_terms()
