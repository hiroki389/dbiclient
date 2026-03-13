set nocompatible
set number
set termguicolors

" dbiclient plugin path
set runtimepath+=/home/w033u/.local/share/nvim/site/pack/core/opt/dbiclient

" SQLite connection
call setenv('DEMO_DB_DSN',  'sqlite:/home/w033u/.local/share/nvim/site/pack/core/opt/dbiclient/assets/demo.db')
call setenv('DEMO_DB_USER', '')
call setenv('DEMO_DB_PASS', '')
command! DBIConnDemo call dbiclient#connect('DEMO')

let g:dbiclient_float_window = 1
let g:dbiclient_debugflg = 0
let g:dbiclient_debuglog = 0
