set tabstop=4
set noai
set modeline
syntax on

" Silly Python people like 4 spaces.
au FileType python setlocal tabstop=4 expandtab

" Silly Rubytards like 2 spaces.
au FileType ruby setlocal tabstop=2 expandtab
au BufRead,BufNewFile *.erb setlocal tabstop=2 expandtab

" Capfile, Gemfile, Rakefile, *.ru, and *.gemspec files are Ruby.
au BufRead,BufNewFile Capfile,Gemfile,Rakefile,*.ru,*.gemspec setlocal ft=ruby

" Markdown files are just plaintext, lest we hurt ourselves.
au BufRead,BufNewFile *.md,*.markdown setlocal ft=plaintext

" Use the Bash syntax highlighting for all shells.  It's prettier, and
" I know the difference between POSIX shell and Bash.  It's fine.
let b:is_bash=1

" Blackboard, dammit!
set t_Co=256
"set t_Co=88
if (&t_Co == 256 || &t_Co == 88) && !has("gui_running") &&
	\ filereadable(expand("$HOME/.vim/plugin/guicolorscheme.vim"))

	" Use the guicolorscheme plugin to makes 256-color or 88-color
	" terminal use GUI colors rather than cterm colors.
	runtime! plugin/guicolorscheme.vim
	GuiColorScheme blackboard

else

	" For 8-color 16-color terminals or for gvim, just use the
	" regular :colorscheme command.
	colorscheme blackboard

endif
