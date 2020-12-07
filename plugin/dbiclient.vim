scriptencoding utf-8

if exists('g:loaded_dbiclient') || v:version < 802
    finish
endif
let g:loaded_dbiclient = 1

let s:cpo_save = &cpo
set cpo&vim

" default 
let g:dbiclient_debugflg               = get(g:,'dbiclient_debugflg', 0)
let g:dbiclient_rootPath               = get(g:,'dbiclient_rootPath', expand('~') . '/.temp/dbiclient')
let g:dbiclient_perlmPath              = get(g:,'dbiclient_perlmPath', fnamemodify(expand('<sfile>:h') . '/../rplugin/perl/socket.pl',':p'))
let g:dbiclient_col_delimiter_align    = get(g:,'dbiclient_col_delimiter_align', "|")
let g:dbiclient_col_delimiter          = get(g:,'dbiclient_col_delimiter', "\t")
let g:dbiclient_sql_delimiter1         = get(g:,'dbiclient_sql_delimiter1', ';')
let g:dbiclient_sql_delimiter2         = get(g:,'dbiclient_sql_delimiter2', '/')
let g:dbiclient_null                   = get(g:,'dbiclient_null', '')
let g:dbiclient_linesep                = get(g:,'dbiclient_linesep', "\n")
let g:dbiclient_surround               = get(g:,'dbiclient_surround', '')
let g:dbiclient_new_window_hight       = get(g:,'dbiclient_new_window_hight', '12')
let g:dbiclient_previewwindow          = get(g:,'dbiclient_previewwindow', 1)
let g:dbiclient_perl_binmode           = get(g:,'dbiclient_perl_binmode', 'utf8')
let g:dbiclient_buffer_encoding        = get(g:,'dbiclient_buffer_encoding', 'utf8')
let g:dbiclient_disp_remarks           = get(g:,'dbiclient_disp_remarks', 1)
let g:dbiclient_prelinesep             = get(g:,'dbiclient_prelinesep', '<<CRR>>')
let g:dbiclient_hist_cnt               = get(g:,'dbiclient_hist_cnt', 1000)
let g:dbiclient_testdata_fixedmap      = get(g:,'dbiclient_testdata_fixedmap', {})
let g:Dbiclient_call_after_connected   = get(g:,'Dbiclient_call_after_connected', {-> dbiclient#userTablesMain()})
let g:dbiclient_disp_headerline        = get(g:,'dbiclient_disp_headerline', 1)

" connect opt default 
let g:dbiclient_connect_opt_columninfoflg     = get(g:,'dbiclient_connect_opt_columninfoflg', 0)
let g:dbiclient_connect_opt_primarykeyflg     = get(g:,'dbiclient_connect_opt_primarykeyflg', 1)
let g:dbiclient_connect_opt_table_name        = get(g:,'dbiclient_connect_opt_table_name', '')
let g:dbiclient_connect_opt_table_type        = get(g:,'dbiclient_connect_opt_table_type', '')
let g:dbiclient_connect_opt_schema_flg        = get(g:,'dbiclient_connect_opt_schema_flg', 0)
let g:dbiclient_connect_opt_schema_list       = get(g:,'dbiclient_connect_opt_schema_list', [])
let g:dbiclient_connect_opt_history_data_flg  = get(g:,'dbiclient_connect_opt_history_data_flg', 0)
let g:dbiclient_connect_opt_envdict           = get(g:,'dbiclient_connect_opt_envdict', {})

command! DBIJobList :call dbiclient#joblist()
command! DBIClose :call dbiclient#jobStopNext()
command! DBIHistory :call dbiclient#dbhistoryCmd()
command! DBITables :call dbiclient#userTablesMain()

command! -nargs=1 DBISetSecurePassword :call dbiclient#setSecurePassword(<f-args>)

command! DBICommit :call dbiclient#commit()
command! DBIRollback :call dbiclient#rollback()

command! -bang -range -nargs=? DBISelect :<line1>,<line2>call dbiclient#selectRangeSQL('',"<bang>" == '!' ? 0 : 1,<f-args>)
command! -bang -range -nargs=? DBISelectSemicolon :<line1>,<line2>call dbiclient#selectRangeSQL(g:dbiclient_sql_delimiter1,"<bang>" == '!' ? 0 : 1,<f-args>)
command! -bang -range -nargs=? DBISelectSlash :<line1>,<line2>call dbiclient#selectRangeSQL(g:dbiclient_sql_delimiter2,"<bang>" == '!' ? 0 : 1,<f-args>)
command! -bang -nargs=? -complete=customlist,dbiclient#getTables DBISelectFrom :call dbiclient#selectTable("<bang>" == '!' ? 0 : 1,1,<q-args>)

command! -nargs=? -complete=customlist,dbiclient#getTables DBIColumnsTable :call dbiclient#selectColumnsTable(1,1,<q-args>)

command! -bang -range DBIExecute :<line1>,<line2>call dbiclient#dBExecRangeSQLDo('',"<bang>")
command! -bang -range DBIExecuteSemicolon :<line1>,<line2>call dbiclient#dBExecRangeSQLDo(g:dbiclient_sql_delimiter1,"<bang>")
command! -bang -range DBIExecuteSlash :<line1>,<line2>call dbiclient#dBExecRangeSQLDo(g:dbiclient_sql_delimiter2,"<bang>")


let &cpo = s:cpo_save
unlet s:cpo_save

