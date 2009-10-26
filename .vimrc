set tabstop=4
set noai
syntax on

" Silly Python people like 4 spaces
au BufRead,BufNewFile *.py,fabfile set expandtab
au BufRead,BufNewFile fabfile set filetype=python

" Rackup files are ruby
au BufRead,BufNewFile *.ru set filetype=ruby
