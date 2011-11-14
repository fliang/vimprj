" File:    vimprj.vim
"
" License: Vim License  (see vim's :help license)
"          No warranty, use this program At-Your-Own-Risk.
"
" Brief:   filetype detect script, used with projectmgr.vim and projectmgr.py
"
" Author:  Liang Feng <fliang98 AT gmail DOT com>
"
" Verion:  0.8

if exists("s:loaded_vimprjtype")
    finish
endif

let s:loaded_vimprjtype = 1

augroup vimprjdetect
    au BufRead,BufNewFile *.vimprj set filetype=vimprj syntax=conf
augroup END

" vim: set et sw=4 ts=4 ff=unix ft=vim:
