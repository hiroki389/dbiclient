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
    let g:dbiclient_sql_delimiter2   = '^\s*\/'
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
if !exists('g:dbiclient_testdata_fixedmap')
    let g:dbiclient_testdata_fixedmap  = {}
endif
if !exists('g:dbiclient_call_after_connected')
    let g:Dbiclient_call_after_connected  = {-> dbiclient#userTablesMain()}
endif

" connect opt default 
if !exists('g:dbiclient_connect_opt_columninfoflg')
    let g:dbiclient_connect_opt_columninfoflg  = 0
endif
if !exists('g:dbiclient_connect_opt_primarykeyflg')
    let g:dbiclient_connect_opt_primarykeyflg  = 1
endif
if !exists('g:dbiclient_connect_opt_table_name')
    let g:dbiclient_connect_opt_table_name  = ''
endif
if !exists('g:dbiclient_connect_opt_table_type')
    let g:dbiclient_connect_opt_table_type  = ''
endif
if !exists('g:dbiclient_connect_opt_schema_flg')
    let g:dbiclient_connect_opt_schema_flg  = 0
endif
if !exists('g:dbiclient_connect_opt_schema_list')
    let g:dbiclient_connect_opt_schema_list  = []
endif
if !exists('g:dbiclient_connect_opt_history_data_flg')
    let g:dbiclient_connect_opt_history_data_flg  = 0
endif
if !exists('g:dbiclient_connect_opt_envdict')
    let g:dbiclient_connect_opt_envdict  = {}
endif

command! DBIJobList :call dbiclient#joblist()
command! DBIClose :call dbiclient#jobStopNext()
command! DBIHistory :call dbiclient#dbhistoryCmd()
command! DBITables :call dbiclient#userTablesMain()

command! -nargs=1 DBISetSecurePassword :call dbiclient#setSecurePassword(<f-args>)

command! DBICommit :call dbiclient#commit()
command! DBIRollback :call dbiclient#rollback()
command! -nargs=? DBICancel :call dbiclient#cancel(<f-args>)

command! DBIHistoryAll :call dbiclient#dbhistoryAllCmd()

command! -bang -range -nargs=? DBISelect :<line1>,<line2>call dbiclient#selectRangeSQL('',"<bang>" == '!' ? 0 : 1,<f-args>)
command! -bang -range -nargs=? DBISelectSemicolon :<line1>,<line2>call dbiclient#selectRangeSQL(g:dbiclient_sql_delimiter1,"<bang>" == '!' ? 0 : 1,<f-args>)
command! -bang -range -nargs=? DBISelectSlash :<line1>,<line2>call dbiclient#selectRangeSQL(g:dbiclient_sql_delimiter2,"<bang>" == '!' ? 0 : 1,<f-args>)
command! -bang -nargs=1 -complete=customlist,dbiclient#getTables DBISelectFrom :call dbiclient#selectTable("<bang>" == '!' ? 0 : 1,1,<f-args>)

command! -bang -nargs=? DBIReload :call dbiclient#reloadMain("<bang>" == '!' ? 0 : 1,<f-args>)
command! -nargs=? -complete=customlist,dbiclient#getTables DBIColumnsTable :call dbiclient#selectColumnsTable(1,1,<q-args>)

command! -bang -range DBIExecute :<line1>,<line2>call dbiclient#dBExecRangeSQLDo('',"<bang>")
command! -bang -range DBIExecuteSemicolon :<line1>,<line2>call dbiclient#dBExecRangeSQLDo(g:dbiclient_sql_delimiter1,"<bang>")
command! -bang -range DBIExecuteSlash :<line1>,<line2>call dbiclient#dBExecRangeSQLDo(g:dbiclient_sql_delimiter2,"<bang>")


let &cpo = s:cpo_save
unlet s:cpo_save

