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
if !exists('g:dbiclient_col_delimiter_align')
    let g:dbiclient_col_delimiter_align    = "|"
endif
if !exists('g:dbiclient_col_delimiter')
    let g:dbiclient_col_delimiter    = "\t"
endif
if !exists('g:dbiclient_sql_delimiter1')
    let g:dbiclient_sql_delimiter1   = ';'
endif
if !exists('g:dbiclient_sql_delimiter2')
    let g:dbiclient_sql_delimiter2   = "\/"
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
if !exists('g:dbiclient_previewwindow')
    let g:dbiclient_previewwindow = 0
endif
if !exists('g:dbiclient_perl_binmode')
    let g:dbiclient_perl_binmode     = 'utf8'
endif
if !exists('g:dbiclient_buffer_encoding')
    let g:dbiclient_buffer_encoding  = 'utf8'
endif
if !exists('g:dbiclient_disp_remarks')
    let g:dbiclient_disp_remarks  = 1
endif
if !exists('g:dbiclient_prelinesep')
    let g:dbiclient_prelinesep  = '<<CRR>>'
endif
if !exists('g:dbiclient_hist_cnt')
    let g:dbiclient_hist_cnt  = 1000
endif

command! DBIJobList :call dbiclient#joblist()
command! -nargs=* DBISetSecurePassword :call dbiclient#setSecurePassword(<f-args>)

command! DBICommit :call dbiclient#commit()
command! DBIRollback :call dbiclient#rollback()
command! -nargs=? DBICancel :call dbiclient#cancel(<f-args>)

command! DBIHistoryAll :call dbiclient#dbhistoryAllCmd()

command! -bang -range -nargs=? DBISelect :<line1>,<line2>call dbiclient#selectRangeSQL(g:dbiclient_sql_delimiter1,"<bang>" == '!' ? 0 : 1,<f-args>)
command! -bang -range -nargs=? DBISelectSlash :<line1>,<line2>call dbiclient#selectRangeSQL(g:dbiclient_sql_delimiter2,"<bang>" == '!' ? 0 : 1,<f-args>)
command! -bang -nargs=? DBISelectTable :call dbiclient#selectTable("<bang>" == '!' ? 0 : 1,1,<f-args>)
command! -bang -nargs=? DBIReload :call dbiclient#reloadMain("<bang>" == '!' ? 0 : 1,<f-args>)
command! -nargs=? DBIColumnsTable :call dbiclient#selectColumnsTable(1,1,<q-args>)

command! -bang -range DBIExecute :<line1>,<line2>call dbiclient#dBExecRangeSQLDo(g:dbiclient_sql_delimiter1,"<bang>")
command! -bang -range DBIExecuteSlash :<line1>,<line2>call dbiclient#dBExecRangeSQLDo(g:dbiclient_sql_delimiter2,"<bang>")


let &cpo = s:cpo_save
unlet s:cpo_save

