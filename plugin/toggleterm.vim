" Plugin file for terminal.vim
" see: toggleterm/init.lua for more details

"--------------------------------------------------------------------------------
" Helpers
"--------------------------------------------------------------------------------
" FIXME normal terminals have no filetype. The only other type of terminal
" we should color is toggleterm. This can be done in a clear way though.
function! s:terminal_setup()
  if &buftype ==# 'terminal' &&
        \ (&filetype ==# '' || &filetype ==# 'toggleterm')
      lua require"toggleterm".darken_terminal(-30)
    endif
endfunction

"--------------------------------------------------------------------------------
" Autocommands
"--------------------------------------------------------------------------------
augroup ToggleTerminal
  autocmd!

  autocmd BufEnter term://*toggleterm#*
        \ lua require'toggleterm'.close_last_window()

  autocmd TermOpen term://*toggleterm#*
        \ lua require'toggleterm'.on_term_open()

  autocmd TermEnter term://*toggleterm#*
        \ tnoremap <silent><c-\> <C-\><C-n>:exe v:count1 . "ToggleTerm"<CR>

  " Colorize terminal buffers
  " FIXME this does not cover all available shells
  " the primary aim here is to avoid fzf terminals
  autocmd TermOpen,ColorScheme,WinNew,TermEnter term://*zsh*,term://*bash*
        \ call <SID>terminal_setup()
  " on BufRead the name of the toggle-able terminal will have changed
  " so it will not be caught by the pattern above
  autocmd BufEnter,ColorScheme * call <SID>terminal_setup()
augroup END

"--------------------------------------------------------------------------------
" Commands
"--------------------------------------------------------------------------------
" count defaults to 1
command! -count=1 -complete=shellcmd -nargs=* TermExec lua require'toggleterm'.exec(<q-args>, <count>, 12)
command! -count=1 TermGitPush lua require'toggleterm'.exec("git push", <count>, 12)
command! -count=1 TermGitPushF lua require'toggleterm'.exec("git push -f", <count>, 12)

command! -count=1 ToggleTerm lua require'toggleterm'.toggle(<count>, 12)

"--------------------------------------------------------------------------------
" Mappings
"--------------------------------------------------------------------------------
" v:count1 defaults the count to 1 but if a count is passed in uses that instead
" <c-u> allows passing along the count
nnoremap <silent><c-\> :<c-u>exe v:count1 . "ToggleTerm"<CR>
inoremap <silent><c-\> <Esc>:<c-u>exe v:count1 . "ToggleTerm"<CR>
