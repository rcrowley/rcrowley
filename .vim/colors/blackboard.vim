set bg=dark
hi clear
if exists("syntax_on")
	syntax reset
endif

let colors_name = "blackboard"

hi Normal ctermfg=15 ctermbg=16 guifg=#ffffff guibg=#0c1021
hi Comment ctermfg=145 guifg=#aeaeae
hi Constant ctermfg=191 guifg=#d7fa41
hi String ctermfg=77 guifg=#64ce3e
hi Statement ctermfg=221 guifg=#f8de33
hi Entity ctermfg=202 guifg=#fa6513
hi Support ctermfg=110 guifg=#8fa6cd
hi LineNr ctermfg=145 guifg=#aeaeae guibg=#0c1021
hi Title ctermfg=7 guifg=#f6f3e8 guibg=#0c1021
hi NonText ctermfg=244 guifg=#808080 guibg=#0c1021
hi Special ctermfg=208

hi Visual gui=reverse
hi VertSplit guifg=#444444 guibg=#444444
hi StatusLine guifg=#f6f3e8 guibg=#444444 gui=italic
hi StatusLineNC guifg=#857b6f guibg=#444444
hi SpecialKey guifg=#808080 guibg=#343434


hi link Define Entity
hi link Function Entity

hi link Structure Support
hi link Special Support
hi link Test Support

hi link Character Constant
hi link Number Constant
hi link Boolean Constant

hi link Float Number

hi link Conditional Statement
hi link StorageClass Statement
hi link Operator Statement
hi link Statement Statement
