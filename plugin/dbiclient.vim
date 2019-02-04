scriptencoding utf-8

if exists('g:loaded_dbiclient')
    finish
endif
let g:loaded_dbiclient = 1

let s:cpo_save = &cpo
set cpo&vim

" default 
if !exists('g:dbiclient_debugflg')
    let g:dbiclient_debugflg         = 0
endif
if !exists('g:dbiclient_rootPath')
    let g:dbiclient_rootPath         = expand('~') . '/.temp/dbiclient'
endif
if !exists('g:dbiclient_perlmPath')
    let g:dbiclient_perlmPath        = fnamemodify(expand('<sfile>:h') . '/../rplugin/perl/socket.pl',':p')
endif
if !exists('g:dbiclient_col_delimiter')
    let g:dbiclient_col_delimiter    = "\t"
endif
if !exists('g:dbiclient_sql_delimiter1')
    let g:dbiclient_sql_delimiter1   = ';'
endif
if !exists('g:dbiclient_sql_delimiter2')
    let g:dbiclient_sql_delimiter2   = '/'
endif
if !exists('g:dbiclient_null')
    let g:dbiclient_null             = ''
endif
if !exists('g:dbiclient_linesep')
    let g:dbiclient_linesep          = v:null
endif
if !exists('g:dbiclient_surround')
    let g:dbiclient_surround         = v:null
endif
if !exists('g:dbiclient_new_window_hight')
    let g:dbiclient_new_window_hight = ''
endif
if !exists('g:dbiclient_perl_binmode')
    let g:dbiclient_perl_binmode     = 'utf8'
endif
if !exists('g:dbiclient_buffer_encoding')
    let g:dbiclient_buffer_encoding  = 'utf8'
endif

"command! -nargs=* DBIJobStart :call dbiclient#jobStart(<f-args>)
"command! DBIJobStat :call dbiclient#jobStat()
command! DBIJobStop :call dbiclient#jobStop(1)
command! DBIJobStopAll :call dbiclient#jobStopAll()
command! DBIJobNext :call dbiclient#jobNext()
command! DBIJobList :call dbiclient#joblist()
command! DBIClose :call dbiclient#close()
"command! -nargs=+ DBISet :call dbiclient#set(<f-args>)
"command! -nargs=* DBIConnect :call dbiclient#connect(<f-args>)

command! DBICommit :call dbiclient#commit()
command! DBIRollback :call dbiclient#rollback()
command! DBICancel :call dbiclient#cancel()

"command! DBILog :call dbiclient#sqllog()
command! DBIHistory :call dbiclient#dbhistory()
command! DBIHistoryDo :call dbiclient#dbhistoryDo()
"command! DBIAlign :call dbiclient#align(!get(b:bufmap,'alignFlg',0))

command! -bang -range -nargs=? DBISelect :<line1>,<line2>call dbiclient#selectRangeSQL('!',<f-args>)
command! -bang -nargs=? DBISelectFrmTbl :call dbiclient#selectTable('!',1,<f-args>)
command! -nargs=? DBIReload :call dbiclient#reload(<f-args>)
command! -nargs=* DBITables :call dbiclient#UserTables('!',<f-args>)
command! DBIColumnsFrmTbl :call dbiclient#selectColumnsTable('!',1)

command! -range DBIExecute :<line1>,<line2>call dbiclient#dBExecRangeSQLDoAuto()
command! -range DBIExecuteSemicolon :<line1>,<line2>call dbiclient#dBExecRangeSQLDo(g:dbiclient_sql_delimiter1)
command! -range DBIExecuteSlash :<line1>,<line2>call dbiclient#dBExecRangeSQLDo(g:dbiclient_sql_delimiter2)

"command! -range DBICreateInsert :<line1>,<line2>call dbiclient#createInsertRange()
"command! -bang -range DBICreateUpdate :<line1>,<line2>call dbiclient#createUpdateRange('<bang>')
"command! -bang -range DBICreateDelete :<line1>,<line2>call dbiclient#createDeleteRange('<bang>')

augroup dbiclient
    au!
    "autocmd VimEnter * DBIJobStart 9001
    autocmd VimLeavePre * DBIJobStopAll
augroup END

let &cpo = s:cpo_save
unlet s:cpo_save
