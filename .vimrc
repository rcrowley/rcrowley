set modeline
set noai
set noexpandtab shiftwidth=4 softtabstop=4 tabstop=4

syntax on
set background=dark
colorscheme solarized

" Clojure sort of uses 2 spaces.  It also uses single spaces.
au BufNewFile,BufRead *.clj setlocal expandtab shiftwidth=2 softtabstop=2 tabstop=2

" Various almost-Makefiles are used in Go source trees.
au BufRead,BufNewFile Make.cmd,Make.inc,Make.pkg setlocal ft=make

" Silly Python people like 4 spaces.
au FileType python setlocal expandtab shiftwidth=4 softtabstop=4 tabstop=4

" Silly Rubytards like 2 spaces.
au FileType ruby setlocal expandtab shiftwidth=2 softtabstop=2 tabstop=2
au BufRead,BufNewFile *.erb setlocal expandtab shiftwidth=2 softtabstop=2 tabstop=2

" Capfile, Gemfile, Rakefile, *.ru, and *.gemspec files are Ruby.
au BufRead,BufNewFile Capfile,Gemfile,Rakefile,*.ru,*.gemspec setlocal ft=ruby

" Markdown files are just plaintext, lest we hurt ourselves.
au BufRead,BufNewFile *.md,*.markdown setlocal ft=plaintext

" Use the Bash syntax highlighting for all shells.  It's prettier, and
" I know the difference between POSIX shell and Bash.  It's fine.
let g:is_bash=1
