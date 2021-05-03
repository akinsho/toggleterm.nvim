" Plugin file for terminal.vim
" see: toggleterm/init.lua for more details

if has('nvim')
	if !has('nvim-0.5')
		echoerr 'You need Neovim Nightly to run this plugin'
		finish
	endif
else
    echohl Error
    echom "Sorry this plugin only works with NeoVim ¯\_(ツ)_/¯"
    echohl clear
    finish
endif

"--------------------------------------------------------------------------------
" Commands
"--------------------------------------------------------------------------------
" count defaults to 1
command! -count=1 -complete=shellcmd -nargs=* TermExec lua require'toggleterm'.exec_command(<q-args>, <count>)
command! -count=1 -nargs=* ToggleTerm lua require'toggleterm'.toggle_command(<q-args>, <count>)
