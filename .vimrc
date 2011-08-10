set modeline
set noai
set ts=4

syntax on
set background=dark
colorscheme solarized

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
let g:is_bash=1
