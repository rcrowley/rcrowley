set expandtab shiftwidth=4 softtabstop=4 tabstop=4
set hlsearch
set modeline
set modelines=4
set noai
set ruler

" Stop Vim from assuming the first match is what I want when tab-completing
" filenames during :sp and :vsp commands.
set wildmenu
set wildignore=longest,list

syntax on
set background=dark
colorscheme solarized

" F1 bringing up the help screen is super annoying.
map <F1> <Esc>
imap <F1> <Esc>

" Clojure sort of uses 2 spaces.  It also uses single spaces.
au BufNewFile,BufRead *.clj setlocal expandtab shiftwidth=2 softtabstop=2 tabstop=2

" Load the Vim configuration that ships with Go.  Additionally set us up to
" run goimports on save.
au FileType go setlocal noexpandtab
let g:gofmt_command = "goimports"
filetype off
filetype plugin off
set runtimepath+=$GOROOT/misc/vim
filetype plugin on
syntax on
autocmd FileType go autocmd BufWritePre <buffer> Fmt

" JavaScript, especially node, likes to use 2 spaces but at Betable,
" we use 4 spaces.
au FileType javascript setlocal shiftwidth=4 softtabstop=4 tabstop=4
au BufRead,BufNewFile *.ejs setlocal ft=html shiftwidth=4 softtabstop=4 tabstop=4

" Various almost-Makefiles are used in Go source trees.
au BufRead,BufNewFile Make.cmd,Make.inc,Make.pkg setlocal ft=make

" Makefiles absolutely require tabs.
au FileType make setlocal noexpandtab

" Markdown needs to be told it is.
au BufRead,BufNewFile *.md setlocal filetype=markdown

" Perl and PHP follow the Flickr standards.
au FileType perl setlocal noexpandtab shiftwidth=8 softtabstop=8 tabstop=8
au FileType php setlocal noexpandtab shiftwidth=8 softtabstop=8 tabstop=8

" Protocol buffers can be whatever but I like tabs because I mostly use
" them with Go.
au BufRead,BufNewFile *.proto setlocal noexpandtab

" Silly Rubytards like 2 spaces.
au FileType ruby setlocal expandtab shiftwidth=2 softtabstop=2 tabstop=2
au BufRead,BufNewFile *.erb setlocal expandtab shiftwidth=2 softtabstop=2 tabstop=2

" Capfile, Gemfile, Rakefile, *.ru, and *.gemspec files are Ruby.
au BufRead,BufNewFile Capfile,Gemfile,Rakefile,*.ru,*.gemspec setlocal ft=ruby

" Use the Bash syntax highlighting for all shells.  It's prettier, and
" I know the difference between POSIX shell and Bash.  It's fine.
let g:is_bash=1
