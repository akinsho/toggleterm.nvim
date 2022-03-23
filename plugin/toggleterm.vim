" Plugin file for terminal.vim
" see: toggleterm/init.lua for more details
if !has('nvim-0.5')
  echoerr 'You need neovim version >= 0.5 to run this plugin'
  finish
endif

"--------------------------------------------------------------------------------
" Commands
"--------------------------------------------------------------------------------
" Count is 0 by default
command! -count -complete=shellcmd -nargs=* TermExec lua require'toggleterm'.exec_command(<q-args>, <count>)
command! -count -nargs=* ToggleTerm lua require'toggleterm'.toggle_command(<q-args>, <count>)
command! -bang ToggleTermToggleAll lua require'toggleterm'.toggle_all(<q-bang>)
command! -range -nargs=? ToggleTermSendVisualLines '<,'> lua require'toggleterm'.send_lines_to_terminal('visual_lines', true, <q-args>)<CR>
command! -range -nargs=? ToggleTermSendVisualSelection '<,'> lua require'toggleterm'.send_lines_to_terminal('visual_selection', true, <q-args>)<CR>
command! -nargs=? ToggleTermSendCurrentLine lua require'toggleterm'.send_lines_to_terminal('single_line', true, <q-args>)<CR>
