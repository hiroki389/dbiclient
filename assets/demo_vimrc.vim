set nocompatible
set number
set termguicolors
set shortmess+=I
set noshowmode
set noruler
set laststatus=0

let s:assets_dir = fnamemodify(expand('<sfile>:p'), ':h')
let s:repo_root = fnamemodify(s:assets_dir, ':h')

" SQLite connection
execute 'set runtimepath^=' .. fnameescape(s:repo_root)
call setenv('DEMO_DB_DSN',  'sqlite:' .. s:assets_dir .. '/demo.db')
call setenv('DEMO_DB_USER', '')
call setenv('DEMO_DB_PASS', '')
command! DBIConnDemo call dbiclient#connect('DEMO')

let g:dbiclient_float_window = 1
let g:dbiclient_debugflg = 0
let g:dbiclient_debuglog = 0
