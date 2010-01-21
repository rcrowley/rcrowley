set tabstop=4
set noai
syntax on

" Silly Python people like 4 spaces
au BufRead,BufNewFile *.py,fabfile set expandtab
au BufRead,BufNewFile fabfile set filetype=python

" Rackup files are ruby
au BufRead,BufNewFile *.ru set filetype=ruby

" Markdown files are just plaintext, lest we hurt ourselves
au BufRead,BufNewFile *.md,*.markdown set filetype=plaintext

" Blackboard, dammit
"   This pretty well depends on iTerm's xterm-256color terminal
"set t_Co=256
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
