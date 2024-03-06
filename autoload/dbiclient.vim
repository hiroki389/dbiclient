"vim9script
scriptencoding utf-8

if !exists('g:loaded_dbiclient') || v:version < 802
    finish
endif

let s:cpo_save = &cpo
set cpo&vim

let s:loaded = 0
let s:sendexprList = []
let s:bufferList = []
let s:bufferList2 = []
let s:currentBuf = -1
let s:f = dbiclient#funclib#new()
let s:f2 = dbiclient#funclib#new2()
let s:Filepath = vital#dbiclient#new().import('System.Filepath')
let s:Stream = vital#dbiclient#new().import('Stream')
let s:dbi_job_port = -1
let s:limitrows = 1000
let s:jobs = {}
let s:params = {}
let s:hardparseDict = {}
let s:lastparse = {}
let s:shadowpass = ''
let s:msg = {
            \'EO01': 'The specified buffer was not found.',
            \'EO02': 'The specified file($1) was not found.',
            \'EO03': 'The specified table($1) was not found.',
            \'EO04': 'A database error has occurred.($1)',
            \'IO05': '$1',
            \'IO07': 'Please connect to the database.($1)',
            \'IO08': 'It is closed port $1.',
            \'IO09': '$1 updated.',
            \'EO10': 'It could not the performed for multiple tables.',
            \'EO11': 'An initial error has occurred. setRootPath({rootpath}) $1',
            \'EO12': 'An initial error has occurred. setPerlmPath({perlmpath}) $1',
            \'IO13': 'Commit',
            \'IO14': 'Rollback',
            \'IO15': 'Success',
            \'EO16': 'It could not the performed for alignFlg.',
            \'EO17': 'It could not the performed for bufname.',
            \'IO18': 'Already job port on running $1.',
            \'IO19': 'Please start to the socket.pl.',
            \'IO20': 'It is running sql on server.',
            \'EO21': 'No table alias has been entered.',
            \}

let s:tab_placefolder = '\V<<#TAB#>>'

let s:connect_opt_table_name = 'connect_opt_table_name'
let s:connect_opt_table_type = 'connect_opt_table_type'
let s:connect_opt_schema_flg = 'connect_opt_schema_flg'
let s:connect_opt_columninfoflg = 'connect_opt_columninfoflg'
let s:connect_opt_primarykeyflg = 'connect_opt_primarykeyflg'
let s:connect_opt_envdict = 'connect_opt_envdict'
let s:connect_opt_debuglog = 'connect_opt_debuglog'
let s:connect_opt_schema_list = 'connect_opt_schema_list'
let s:connect_opt_limitrows = 'connect_opt_limitrows'
let s:connect_opt_encoding = 'connect_opt_encoding'
let s:connect_opt_history_data_flg = 'connect_opt_history_data_flg'
let s:history_data = {}

let s:nmap_job_CH = '<CR>'
let s:nmap_job_ST = 'ms'
let s:nmap_job_TA = 'mt'
let s:nmap_job_HI = 'mh'

let s:nmap_result_AL = 'ma'
let s:nmap_result_ED = 'me'
let s:nmap_result_BN = 'mn'
let s:nmap_result_BP = 'mp'
let s:nmap_result_BD = 'md'
let s:nmap_result_GR = 'mg'
let s:nmap_result_OR = 'mo'
let s:nmap_result_DI = 'mid'
let s:nmap_result_RE = 'mr'
let s:nmap_result_LI = 'mll'
let s:nmap_result_SE = 'ms'
let s:nmap_result_IJ = 'mji'
let s:nmap_result_LJ = 'mjl'
let s:nmap_result_WH = 'mw'
let s:vmap_result_DE = '<C-D>'
let s:vmap_result_IN = '<C-I>'
let s:vmap_result_UP = '<C-U>'

let s:nmap_do_PR = 'me'
let s:nmap_do_BN = 'mn'
let s:nmap_do_BP = 'mp'
let s:nmap_do_BD = 'md'

let s:nmap_table_SQ = '<CR>'
let s:nmap_table_CT = 'mc'
let s:nmap_table_TT = 'mt'
let s:nmap_table_TW = 'mw'

let s:nmap_history_PR = '<CR>'
let s:nmap_history_RE = 'mr'
"let s:nmap_history_SQ = 'me'
let s:nmap_history_DD = 'md'

let s:nmap_edit_SQ = '<CR>'
let s:nmap_select_SQ = '<CR>'
let s:nmap_where_SQ = '<CR>'
let s:nmap_ijoin_SQ = '<CR>'
let s:nmap_group_SQ = '<CR>'
let s:nmap_order_SQ = '<CR>'

function dbiclient#setSecurePassword(name) abort
    return s:setSecurePassword(a:name)
endfunction

function dbiclient#connect_secure(port, dsn, user, passwordName, ...) abort
    return s:connect_secure(a:port, a:dsn, a:user, a:passwordName, get(a:, 1, {}))
endfunction

function dbiclient#connect(port, dsn, user, pass, ...) abort
    return s:connect(a:port, a:dsn, a:user, a:pass, get(a:, 1, {}))
endfunction

function dbiclient#sqllog() abort
    return s:sqllog()
endfunction

function dbiclient#joblist() abort
    return s:joblist(1)
endfunction

function dbiclient#jobStopAll() abort
    return s:jobStopAll()
endfunction

function dbiclient#kill_job(...) abort
    return s:kill_job(get(a:, 1, s:getCurrentPort()))
endfunction

function dbiclient#selectRangeSQL(alignFlg, ...) range abort
    return s:selectRangeSQL(a:alignFlg, get(a:, 1, s:getLimitrows()))
endfunction

function dbiclient#dBExecRangeSQLDo(bang) range abort
    return s:dBExecRangeSQLDo(a:bang, 1)
endfunction

function dbiclient#dBExecRangeSQLDoNoSplit(bang) range abort
    return s:dBExecRangeSQLDo(a:bang, 0)
endfunction

function dbiclient#getQuery(sql, limitrows, opt) abort
    return s:getQuery(a:sql, a:limitrows, a:opt, s:getCurrentPort())
endfunction

function dbiclient#getQuerySync(sql, callback, limitrows, opt) abort
    return s:getQuerySync(a:sql, a:callback, a:limitrows, a:opt, s:getCurrentPort())
endfunction

function dbiclient#getQuerySyncSimple(sql, bufname) abort
    return s:getQuerySync(a:sql, 's:cb_outputResultEasyAlign', s:getLimitrows(), {'reloadBufname':a:bufname}, s:getCurrentPort())
endfunction

function dbiclient#getQueryAsyncSimple(sql) abort
    return s:getQueryAsyncSimple(a:sql)
endfunction

function dbiclient#commit() abort
    return s:commit()
endfunction

function dbiclient#rollback() abort
    return s:rollback()
endfunction

function dbiclient#set(key, value) abort
    return s:set(a:key, a:value)
endfunction

function dbiclient#dBCommandMain(command) abort
    return s:dBCommandMain(a:command)
endfunction

function dbiclient#dBCommandAsync(command, callback, port) abort
    return s:dBCommandAsync(a:command, a:callback, a:port)
endfunction

function dbiclient#alignMain(preCr) abort
    return s:alignMain(a:preCr)
endfunction

function dbiclient#selectTable(alignFlg, wordFlg, ...) abort
    let table = get(a:, 1, '')
    return s:selectTable(a:alignFlg, a:wordFlg, table)
endfunction

function dbiclient#getTables(lead, line, pos) abort
    let port = s:getCurrentPort()
    let lead = substitute(a:lead, '\v(^|[^0-9]|[0-9]+)\zs', '\\v.{-}\\V', 'g')
    return filter(get(get(s:params, port, {}), 'table_list', [])[:], {_, x -> x =~ ('^\V' .. lead) })
endfunction

function dbiclient#getTypes(lead, line, pos) abort
    let port = s:getCurrentPort()
    let lead = substitute(a:lead, '\v(^|[^0-9]|[0-9]+)\zs', '\\v.{-}\\V', 'g')
    return filter(get(get(s:params, port, {}), 'table_type', [])[:], {_, x -> x =~ ('^\V' .. lead) })
endfunction

function dbiclient#selectColumnsTable(alignFlg, wordFlg, ...) abort
    let table = get(a:, 1, '')
    return s:selectColumnsTable(a:alignFlg, a:wordFlg, table)
endfunction

function dbiclient#putSql(sql) abort
    call s:putSql(a:sql)
endfunction

function dbiclient#userTablesMain() abort
    let port = s:getCurrentPort()
    return s:userTablesMain(port)
endfunction

function dbiclient#jobStopNext() abort
    let port = s:getCurrentPort()
    return s:jobStopNext(port)
endfunction

function dbiclient#dbhistoryCmd() abort
    let port = s:getCurrentPort()
    return s:dbhistoryCmd(port)
endfunction

function dbiclient#getSqlPrimarykeys(tableNm) abort
    let table = s:getTableNm(1, a:tableNm)
    let port = s:getCurrentPort()
    let primaryKeys = s:getPrimaryKeys(table, port)
    let sql = 'SELECT ' .. join(primaryKeys, ', ') .. ' FROM ' .. table
    return sql
endfunction

function dbiclient#createTestdata(tableNm) abort
    let table = s:getTableNm(1, a:tableNm)
    let port = s:getCurrentPort()
    let cols = s:getColumns(table, port)
    let res  = "INSERT INTO "
    let res ..= table
    let res ..= "("
    let res ..= join(cols, ', ')
    let res ..= ")VALUES("
    let res ..= join(map(cols, {i, x -> "'" .. get(g:dbiclient_testdata_fixedmap, x, i) .. "'" }), ', ')
    let res ..= ");"
    return res
endfunction

function dbiclient#getColumnsTableCmn(table)
    if empty(trim(a:table))
        return {}
    endif
    let cmd= []
    let ymdhms=strftime("%Y%m%d%H%M%S",localtime())
    let opt = {
                \'noaddhistory' : 1
                \,'column_info' : 1
                \,'tableNm'     : a:table}
    return dbiclient#getQuery('',-1,opt)
endfunction

function dbiclient#createInsert(keys, vallist, tableNm) abort
    return s:createInsert(a:keys, a:vallist, [], 0, a:tableNm)
endfunction

function dbiclient#createDeleteInsertSql(...) range abort
    let limitrows = get(a:, 1, s:getLimitrows())
    let sqls = join(getline(a:firstline, a:lastline),"\n")->split('\v;\s*($|\n)')
    let bufname = "ScratchCreateDeleteInsert"
    let bufnr = s:aboveNewBuffer(bufname)
    for sql in sqls
        if trim(sql) != ''
            let res = dbiclient#getQuery(sql ,limitrows,{})
            if has_key(res ,'data')
                if filereadable(res.data.tempfile .. '.err')
                    throw readfile(res.data.tempfile .. '.err')->join(g:dbiclient_prelinesep)
                elseif empty(get(res, 'cols', []))
                    throw 'empty'
                else
                    let tmp = readfile(res.data.tempfile)->join(g:dbiclient_prelinesep)
                    let list = tmp->substitute('\v"(.|' .. g:dbiclient_prelinesep .. '){-}"', {m -> s:trim_surround(substitute(s:trim_surround_CRLF(m[0]), '\V' .. g:dbiclient_prelinesep, g:dbiclient_prelinesep2,'g'))}, 'g')->split(g:dbiclient_prelinesep)
                    let param  = dbiclient#funclib#List(list).foldl({x -> s:f.zip(get(res, 'cols', []), s:split(x, g:dbiclient_col_delimiter))}, []).value()
                    let row = s:createDelete(param, param, res.data.tableNm, s:getCurrentPort())
                    call s:appendbufline(bufnr, '$', row)
                    call s:appendbufline(bufnr, '$', [''])
                    let row = dbiclient#createInsert(res.cols, param, res.data.tableNm)
                    call s:appendbufline(bufnr, '$', row)
                    call s:appendbufline(bufnr, '$', [''])
                endif
            endif
        endif
    endfor
endfunction

function dbiclient#getHardparseDict() abort
    return s:lastparse
endfunction

function dbiclient#cancel() abort
    call s:cancel(s:getCurrentPort())
endfunction

function dbiclient#clearCache() abort
    let port = s:getCurrentPort()
    let connInfo = get(s:params, port, {})
    let schema = s:getuser(connInfo)
    for file in split(glob(s:Filepath.join(s:getRootPath(), 'dictionary/' .. schema .. '_*')), "\n")
        call delete(file)
    endfor
endfunction

function dbiclient#openbuf() abort
    if bufexists(s:currentBuf)
        if g:dbiclient_previewwindow
            let cwid = s:getwidCurrentTab(s:currentBuf)
            silent! wincmd P
            if !getbufvar(s:bufnr('%'), '&previewwindow')
                bo new
                silent! setlocal previewwindow
            endif
        else
            bo new
        endif
        exe 'b ' .. s:currentBuf
        call s:sethl(bufnr('%'))
    endif
endfunction

function dbiclient#sethl(bufnr) abort
    call s:sethl(a:bufnr)
endfunction

def s:bufnr(bufname: any): any
    if empty(bufname)
        return -1
    else
        return bufnr(bufname)
    endif
enddef

function s:bufdel(port, cbufnr) abort
    "let bufnr = s:bufsearch(reverse(get(get(s:params, a:port, {}), 'buflist', [])[:]), a:cbufnr)
    let bufnr = s:bufsearch(reverse(map(s:bufferList2[:], {_, x -> x[1]})), a:cbufnr)
    if bufnr == -1
        let bufnr = s:bufsearch(map(s:bufferList2[:], {_, x -> x[1]}), a:cbufnr)
        if bufnr == -1
            let bufnr = a:cbufnr
        endif
    endif
    let s:currentBuf = bufnr
    exe 'b ' .. bufnr
    call s:sethl(bufnr('%'))
    silent! exe 'bwipeout! ' .. a:cbufnr
endfunction

function s:bufnext(port, cbufnr) abort
    "let bufnr = s:bufsearch(get(get(s:params, a:port, {}), 'buflist', []), a:cbufnr)
    let bufnr = s:bufsearch(map(s:bufferList2[:], {_, x -> x[1]}), a:cbufnr)
    if bufnr != -1
        let s:currentBuf = bufnr
        exe 'b ' .. bufnr
        call s:sethl(bufnr('%'))
    endif
endfunction

function s:bufprev(port, cbufnr) abort
    "let bufnr = s:bufsearch(reverse(get(get(s:params, a:port, {}), 'buflist', [])[:]), a:cbufnr)
    let bufnr = s:bufsearch(reverse(map(s:bufferList2[:], {_, x -> x[1]})), a:cbufnr)
    if bufnr != -1
        let s:currentBuf = bufnr
        exe 'b ' .. bufnr
        call s:sethl(bufnr('%'))
    endif
endfunction

function s:addbufferlist(port, bufnr) abort
    let idx = s:bufindexsearch(s:bufferList2, s:currentBuf)
    if idx == -1 || idx == len(s:bufferList2) - 1
        let bufferList2Tmp1 = s:bufferList2[:]
        let bufferList2Tmp2 = []
    else
        let bufferList2Tmp1 = s:bufferList2[0:idx]
        let bufferList2Tmp2 = s:bufferList2[idx + 1:]
    endif
    call add(bufferList2Tmp1, [a:port, a:bufnr])
    let s:bufferList2 = extend(bufferList2Tmp1, bufferList2Tmp2)
    let s:currentBuf = a:bufnr
endfunction

function s:bufindexsearch(buflist, cbufnr) abort
    let idx = 0
    for [port, bufnr] in a:buflist
        if bufnr == a:cbufnr
            return idx
        endif
        let idx += 1
    endfor
    return -1
endfunction

function s:bufsearch(buflist, cbufnr) abort
    let flg = 0
    for bufnr in a:buflist
        if bufnr == a:cbufnr
            let flg = 1
            continue
        endif
        if flg
            if bufexists(bufnr) && !empty(getbufvar(bufnr, 'dbiclient_bufmap'))
                return bufnr
            endif
        endif
    endfor
    return -1
endfunction

function s:debugLog(msg) abort
    if g:dbiclient_debugflg
        let datetime = strftime("%Y/%m/%d %H:%M:%S")
        echohl WarningMsg
        echom datetime .. ' ' .. string(a:msg)
        echohl None
    endif
endfunction

function s:deleteHistoryCmd(port) abort
    let sqlpath = s:getHistoryPathCmd(a:port)
    if !filereadable(sqlpath)
        return
    endif
    let sqllist = s:readfile(sqlpath)
    let limit = g:dbiclient_hist_cnt * -1
    if len(sqllist) > limit * -1
        for val in sqllist[0:limit - 1]
            sandbox silent! let cmd = eval(matchstr(val, '\v.{-}\t\zs.*'))
            if type(cmd) ==# v:t_dict
                if filereadable(cmd.data.tempfile)
                    call delete(cmd.data.tempfile)
                endif
                if filereadable(cmd.data.tempfile .. '.err')
                    call delete(cmd.data.tempfile .. '.err')
                endif
            endif
        endfor
        call writefile(sqllist[limit:], sqlpath)
    endif
endfunction

function s:deleteHistory(sqlpath, no, removefile) abort
    let sqlpath = a:sqlpath
    let no = a:no
    if !filereadable(sqlpath)
        return
    endif
    let sqllist = s:readfile(sqlpath)
    try
        sandbox silent! let cmd = eval(matchstr(sqllist[no], '\v.{-}\t\zs.*'))
    catch /./
        let sqllist = filter(sqllist, {_, x -> x =~? '\v^(.{-})DSN:(.{-})SQL:'})
        call writefile(sqllist, sqlpath)
        return
    endtry
    if a:removefile && type(cmd) ==# v:t_dict
        if filereadable(cmd.data.tempfile)
            call delete(cmd.data.tempfile)
        endif
        if filereadable(cmd.data.tempfile .. '.err')
            call delete(cmd.data.tempfile .. '.err')
        endif
    endif
    call remove(sqllist, no)
    call writefile(sqllist, sqlpath)
endfunction

function s:loadQueryHistoryCmd(port) abort
    call s:debugLog('loadQueryHistoryCmd:start')
    let sqlpath = s:getHistoryPathCmd(a:port)
    if !filereadable(sqlpath)
        call s:debugLog('loadQueryHistoryCmd:end(empty)')
        let s:history_data[sqlpath] = []
        return []
    endif
    let list = s:readfileTakeRows(sqlpath, g:dbiclient_hist_cnt * -1)
    "let list = map(list, {_, x -> substitute(x, '\V{DELIMITER_CR}', "\n", 'g')})
    "let list = filter(list, {_, x -> x =~? '\v^.{-}DSN:.{-}SQL:'})
    call s:debugLog('loadQueryHistoryCmd:end')
    return list
endfunction

function s:getHistoryPathCmd(port) abort
    let port = a:port
    let connInfo = get(s:params, port, {})
    let dsn = matchstr(get(connInfo, 'dsn', ''), '\v\s*\zs\w+')
    let user = s:getuser(connInfo)
    let sqlpath = s:Filepath.join(s:getRootPath(), "history_cmd_" .. dsn .. '_' .. user)
    return sqlpath
endfunction

function s:getRootPath() abort
    return g:dbiclient_rootPath
endfunction

function s:getPerlmPath() abort
    return g:dbiclient_perlmPath
endfunction

function s:sqllog() abort
    let ymd = strftime("%Y%m%d", localtime())
    let logfile= 'socket_' .. ymd .. '.log'
    bo new
    exe 'e ' .. s:Filepath.join(s:getRootPath(), logfile)
endfunction

function s:error1CurrentPort() abort
    let port = s:getCurrentPort()
    return s:error1(port)
endfunction

function s:error0(port) abort
    let port = a:port

    if !has_key(s:params, port) || get(s:params[port], 'connect', 9) !=# 1
        call s:echoMsg('IO07', port)
        return 1
    endif
    return 0
endfunction

function s:error1(port) abort
    let port = a:port

    call filter(s:sendexprList, {_, x -> s:ch_statusOk(x[1])})
    let sendexprList = filter(s:sendexprList[:], {_, x -> x[0] ==# port})
    if len(sendexprList) > 0
        call s:echoMsg('IO20')
        return 1
    endif
    return s:error0(port)
endfunction

function s:error2CurrentBuffer(port) abort
    return s:error2(a:port, s:bufnr('%'))
endfunction

function s:error2(port, bufnr) abort
    let port = a:port
    let bufnr = a:bufnr
    let dbiclient_bufmap = getbufvar(bufnr, 'dbiclient_bufmap', {})
    let connInfo = s:getconninfo(dbiclient_bufmap)
    let hashKey1 = get(get(s:params, port, {}), 'hashKey', '1')
    let hashKey2 = get(connInfo, 'hashKey', '2')
    if hashKey1 !=# hashKey2
        call s:echoMsg('IO07', port)
        return 1
    endif
    call filter(s:sendexprList, {_, x -> s:ch_statusOk(x[1])})
    let sendexprList = filter(s:sendexprList[:], {_, x -> x[0] ==# port})
    if len(sendexprList) > 0
        call s:echoMsg('IO20')
        return 1
    endif
    if s:error1(port)
        return 1
    endif
    return 0
endfunction

function s:error3(...) abort
    let port = get(a:, 1, s:getCurrentPort())
    let bufnr = s:bufnr('%')
    let dbiclient_bufmap = getbufvar(bufnr, 'dbiclient_bufmap', {})
    if empty(dbiclient_bufmap) || empty(get(dbiclient_bufmap, "cols", []))
        call s:echoMsg('EO01')
        return 1
    endif
    return 0
endfunction

function s:getDblinkName(sql) abort
    call s:debugLog('getDblinkName')
    let sql = s:getSqlLine(s:getSqlLineDelComment(a:sql))
    let dblink = matchstr(sql, '\v<from>\s+[^[:space:]@]+\@\zs[^[:space:]]+')
    return dblink
endfunction

function s:getTableName(sql, table) abort
    if !empty(a:table)
        return a:table
    endif
    call s:debugLog('getTableName')
    let sql = s:getSqlLine(s:getSqlLineDelComment(a:sql))
    let table = get(get(s:getTableJoinList(sql), 0, {}), 'tableNm', '')
    let table = substitute(table, '"', '', 'g')
    if table ==# ""
        return ''
    else
        return table
    endif
endfunction

function s:getTableJoinList(sql) abort
    call s:debugLog('getTableJoinList')
    let sql = s:getSqlLine(s:getSqlLineDelComment(a:sql))
    let regex = '\v\c\s+%(from|join)\s+([[:alnum:]_$#.]+|".{-}")%((\s+as)?\s+([^[:space:]]+|<on>|<using>))?'
    let suba = substitute(sql, regex .. '\zs', '\n', 'g')
    let table = dbiclient#funclib#List(s:split(suba, "\n")).matchstr('\v\c\s+%(from|join)\s+\zs([[:alnum:]_$#.]+|".{-}")%((\s+as)?\s+([^[:space:]]+))?\ze').value()
    let table = map(table, {_, x -> split(x, ',') })->flattennew()
    let table = filter(table, {_, x -> x !~# '\v^\s*[_$#.]+\s*$'})
    let table = map(table, {_, x -> split(x, '\v[[:space:]]+') })
    let table = map(table, {_, x -> {'tableNm':get(x, 0, ''), 'AS':get(x, 1, '') =~? '\v(<on>|<where>|<group>|<order>|<join>|<left>|<right>|<inner>|<cross>|<natural>|<having>|<union>|<minus>|<except>|<using>|<as>|<of>)' ? '' : get(x, 1, '')}})
    if empty(table)
        return []
    else
        return table
    endif
endfunction

function s:getTableJoinListUniq(sql) abort
    return uniq(sort(map(s:getTableJoinList(a:sql), {_, x -> x.tableNm})))
endfunction

function s:getPrimaryKeys(tableNm, port) abort
    let opt={'tableNm':a:tableNm, 'column_info_data':1}
    return get(s:getQuery('', -1, opt, a:port), 'primary_key', [])
endfunction

function s:getColumns(tableNm, port) abort
    let cols = get(get(s:params, a:port, {}), a:tableNm, [])
    if !has_key(get(s:params, a:port, {}), a:tableNm)
        let s:params[a:port][a:tableNm] = []
        let opt = {'tableNm':a:tableNm, 'column_info_data':1}
        let cols = get(s:getQuery('', -1, opt, a:port),'column_info',[])->map({_,x -> x.COLUMN_NAME})
        if empty(cols)
            let cols = get(s:getQuery('SELECT * FROM ' .. a:tableNm, 0, {}, a:port),'cols',[])
        endif
        if !empty(cols)
            let s:params[a:port][a:tableNm] = cols
        endif
    endif
    return cols[:]
endfunction

function s:putSql(sql) abort
    exe 'norm o' .. a:sql
endfunction

function s:getDefinedKeyValue(sql) abort
    let ret = {}
    let regexp='\v\c^\s*%(def|define)\s+([[:alnum:]_]+)\s*\=(.*)$'
    if a:sql =~? regexp
        let key = substitute(a:sql, regexp, '\1', '')
        let val = substitute(a:sql, regexp, '\2', '')
        let ret[key]=val
    endif
    return ret
endfunction

function s:doDeleteInsert() abort
    let port = s:getPort()
    if s:error1CurrentPort() || s:error3()
        return
    endif
    let bufnr = s:bufnr('%')
    let dbiclient_disp_headerline = g:dbiclient_disp_headerline ? 1 : 0
    let firstline = getbufvar(bufnr, 'dbiclient_col_line', 0) + dbiclient_disp_headerline + 1
    let lastline = line('$')
    let list = getline(firstline, lastline)
    let tmp = list->join(g:dbiclient_prelinesep)
    let list = tmp->substitute('\v"(.|' .. g:dbiclient_prelinesep .. '){-}"', {m -> s:trim_surround(substitute(s:trim_surround_CRLF(m[0]), '\V' .. g:dbiclient_prelinesep, g:dbiclient_prelinesep2,'g'))}, 'g')->split(g:dbiclient_prelinesep)
    let offset = getbufvar(s:bufnr('%'), 'dbiclient_col_line', 0)
    let remarkrow = getbufvar(s:bufnr('%'), 'dbiclient_remarks_flg', 0)
    let beforeList = getbufvar(s:bufnr('%'), 'dbiclient_lines', {})[firstline - offset + remarkrow : lastline - offset + remarkrow]
    let tmp2 = map(deepcopy(beforeList), {_, line -> substitute(line, g:dbiclient_prelinesep, '', 'g')})->join(g:dbiclient_prelinesep)
    let beforeList = tmp2->substitute('\v"(.|' .. g:dbiclient_prelinesep .. '){-}"', {m -> s:trim_surround(substitute(s:trim_surround_CRLF(m[0]), g:dbiclient_prelinesep, g:dbiclient_prelinesep2,'g'))}, 'g')->split(g:dbiclient_prelinesep)
    let dbiclient_bufmap = getbufvar(bufnr, 'dbiclient_bufmap', {})
    if get(dbiclient_bufmap, 'hasnext', 1) ==# 1
        return
    endif
    if dbiclient_bufmap.alignFlg
        let list = map(list, {_, line -> join(map(split(line, g:dbiclient_col_delimiter_align), {_, x -> trim(x)}), g:dbiclient_col_delimiter)})
    endif
    let cols = dbiclient_bufmap.cols
    let as = get(get(s:getTableJoinList(get(get(dbiclient_bufmap, 'data', {}), 'sql', '')), 0, {}), 'AS', '')
    let tableNm = dbiclient_bufmap.data.tableNm
    let where = get(get(get(dbiclient_bufmap, 'opt', {}), 'extend', {}), 'where', '')
    let param  = dbiclient#funclib#List(list).foldl({x -> s:f.zip(cols, s:split(x, g:dbiclient_col_delimiter))}, []).value()
    let param2 = dbiclient#funclib#List(beforeList).foldl({x -> s:f.zip(cols, s:split(x, g:dbiclient_col_delimiter))}, []).value()
    let createInsert = s:createInsert(cols, param, param2, dbiclient_bufmap.alignFlg, tableNm)
    let list2 = extend(['DELETE FROM ' .. tableNm .. ' ' .. as .. ' ' .. where .. g:dbiclient_sql_delimiter1], createInsert)
    let sqllist = s:splitSql(list2[:], 1)
    call s:dBCommandAsync({"doText":list2[:], "do":sqllist}, 's:cb_do', port)
endfunction

function s:createInsert(keys, vallist, beforevallist, alignFlg, tableNm) abort
    if a:tableNm ==# ""
        return []
    endif
    let result=[]
    let cols = join(a:keys, ", ")
    let i=0
    for items in a:vallist
        let beforedict = dbiclient#funclib#List(get(a:beforevallist, i, [])).foldl({x -> {x[0]:substitute(x[1], "'" , "''", 'g')}}, {}).value()
        let dict = dbiclient#funclib#List(items).foldl({x -> {x[0]:substitute(x[1], "'" , "''", 'g')}}, {}).value()
        if a:alignFlg
            let collist = dbiclient#funclib#List(items)
                        \.fmap({item -> trim(get(dict, item[0], '')) !=# trim(get(beforedict, item[0], '')) || !has_key(beforedict, item[0]) ? get(dict, item[0], '') : get(beforedict, item[0], '')})
                        \.foldl({item -> item}, []).value()
        else
            let collist = dbiclient#funclib#List(items).foldl({item -> item[1]}, []).value()
        endif
        let res  = "INSERT INTO "
        let res ..= a:tableNm
        let res ..= "("
        let res ..= cols
        let res ..= ")VALUES("
        let collist = map(collist, {_, x -> s:trim_surround(x)})
        call add(result, res .. join(map(collist, {_, xs -> "'" .. substitute(xs, "'", "''", 'g') .. "'"}), ", ")->substitute('\V' .. g:dbiclient_prelinesep2, "' || " .. g:dbiclient_dblinesep .. " || '",'g') .. ");")
        let i += 1
    endfor
    return result
endfunction

function s:createInsertRange() range abort
    let port = s:getCurrentPort()
    if s:isDisableline(a:firstline, a:lastline)
        return
    endif
    let bufname = "ScratchCreateInsert"
    let list = getline(a:firstline, a:lastline)
    let tmp = list->join(g:dbiclient_prelinesep)
    let list = tmp->substitute('\v"(.|' .. g:dbiclient_prelinesep .. '){-}"', {m -> s:trim_surround(substitute(s:trim_surround_CRLF(m[0]), '\V' .. g:dbiclient_prelinesep, g:dbiclient_prelinesep2,'g'))}, 'g')->split(g:dbiclient_prelinesep)
    let offset = getbufvar(s:bufnr('%'), 'dbiclient_col_line', 0)
    let remarkrow = getbufvar(s:bufnr('%'), 'dbiclient_remarks_flg', 0)
    let beforeList = getbufvar(s:bufnr('%'), 'dbiclient_lines', {})[a:firstline - offset + remarkrow : a:lastline - offset + remarkrow]
    let tmp2 = map(deepcopy(beforeList), {_, line -> substitute(line, g:dbiclient_prelinesep, '', 'g')})->join(g:dbiclient_prelinesep)
    let beforeList = tmp2->substitute('\v"(.|' .. g:dbiclient_prelinesep .. '){-}"', {m -> s:trim_surround(substitute(s:trim_surround_CRLF(m[0]), g:dbiclient_prelinesep, g:dbiclient_prelinesep2,'g'))}, 'g')->split(g:dbiclient_prelinesep)
    let dbiclient_bufmap = getbufvar(s:bufnr('%'), 'dbiclient_bufmap', {})
    if dbiclient_bufmap.alignFlg
        let list = map(list, {_, line -> join(map(split(line, g:dbiclient_col_delimiter_align), {_, x -> trim(x)}), g:dbiclient_col_delimiter)})
    endif
    if empty(list)
        return
    endif
    let cols = dbiclient_bufmap.cols
    let tableNm = dbiclient_bufmap.data.tableNm
    let bufnr = s:bufnr(bufname)
    if s:gotoWinCurrentTab(bufnr) ==# -1
        let bufnr = s:aboveNewBuffer(bufname)
    endif
    call s:deletebufline(bufnr, 1, '$')
    let param  = dbiclient#funclib#List(list).foldl({x -> s:f.zip(cols, s:split(x, g:dbiclient_col_delimiter))}, []).value()
    let param2 = dbiclient#funclib#List(beforeList).foldl({x -> s:f.zip(cols, s:split(x, g:dbiclient_col_delimiter))}, []).value()
    call s:appendbufline(bufnr, '$', s:createInsert(cols, param, param2, dbiclient_bufmap.alignFlg, tableNm))
endfunction

function s:trim_surround(val) abort
    if !empty(g:dbiclient_surround)
        return substitute(substitute(a:val, '^\V' .. g:dbiclient_surround, '', ''), '\V' .. g:dbiclient_surround .. '\v$', '', '')
    else
        return a:val
    endif
endfunction

function s:trim_surround_CRLF(val) abort
    if a:val =~ '\V' .. g:dbiclient_prelinesep
        return substitute(a:val, '\v^"|"$', '', 'g')
    else
        return a:val
    endif
endfunction

function s:createUpdate(vallist, beforevallist, tableNm, alignFlg, port) abort
    call s:debugLog('createUpdate start')
    call s:debugLog('getPrimaryKeys start')
    let keys = s:getPrimaryKeys(a:tableNm, a:port)
    call s:debugLog('getPrimaryKeys end')
    if a:tableNm ==# ""
        return []
    endif
    let result=[]
    let i=0
    for items in a:vallist
        let beforedict = dbiclient#funclib#List(get(a:beforevallist, i, [])).foldl({x -> {x[0]:substitute(x[1], "'" , "''", 'g')}}, {}).value()
        let dict = dbiclient#funclib#List(items).foldl({x -> {x[0]:substitute(x[1], "'" , "''", 'g')}}, {}).value()
        let res  = "UPDATE " .. a:tableNm .. " SET "
        let collist = dbiclient#funclib#List(items)
                    \.filter({item -> a:alignFlg ? trim(get(dict, item[0], '')) !=# trim(get(beforedict, item[0], '')) : get(dict, item[0], '') !=# get(beforedict, item[0], '')})
                    \.foldl({item -> item[0] .. ' = ' .. "'" .. s:trim_surround(item[1]) .. "'"}, []).value()
        if len(collist) > 0
            let res  ..= join(collist, ', ')->s:trim_surround_CRLF()->substitute('\V' .. g:dbiclient_prelinesep2, "' || " .. g:dbiclient_dblinesep .. " || '", 'g')
        else
            let res  ..= '<*>'
        endif
        if(len(keys) > 0)
            let diffList = keys[:]->filter({_, key -> trim(s:trim_surround(get(beforedict, key, '<*>'))) !=# trim(s:trim_surround(get(dict, key, '<*>')))})->map({_, key -> trim(s:trim_surround(get(beforedict, key, '<*>'))) .. ' != ' .. trim(s:trim_surround(get(dict, key, '<*>')))})
            if diffList->len() > 0
                let res  = '/* Change primary key */ ' .. res
            endif
            let res ..= {key -> ' WHERE ' .. key .. ' = ' .. "'" .. s:trim_surround(get(beforedict, key, '<*>')) .. "'"}(keys[0])
            let res ..= join(dbiclient#funclib#List(keys[1:]).foldl({key -> ' AND ' .. key .. ' = ' .. "'" .. s:trim_surround(get(beforedict, key, '<*>')) .. "'"}, []).value())
        else
            let res ..= ' WHERE <*>'
        endif
        call add(result, res .. ";")
        let i += 1
    endfor
    call s:debugLog('createUpdate end')
    return result
endfunction

function s:createUpdateRange() range abort
    let port = s:getCurrentPort()
    if s:isDisableline(a:firstline, a:lastline)
        return
    endif
    if s:error1CurrentPort() || s:error3()
        return
    endif
    let bufname = "ScratchCreateUpdate"
    let list = getline(a:firstline, a:lastline)
    let tmp = list->join(g:dbiclient_prelinesep)
    let list = tmp->substitute('\v"(.|' .. g:dbiclient_prelinesep .. '){-}"', {m -> s:trim_surround(substitute(s:trim_surround_CRLF(m[0]), g:dbiclient_prelinesep, g:dbiclient_prelinesep2,'g'))}, 'g')->split(g:dbiclient_prelinesep)
    let offset = getbufvar(s:bufnr('%'), 'dbiclient_col_line', 0)
    let remarkrow = getbufvar(s:bufnr('%'), 'dbiclient_remarks_flg', 0)
    let beforeList = getbufvar(s:bufnr('%'), 'dbiclient_lines', {})[a:firstline - offset + remarkrow : a:lastline - offset + remarkrow]
    let tmp2 = map(deepcopy(beforeList), {_, line -> substitute(line, g:dbiclient_prelinesep, '', 'g')})->join(g:dbiclient_prelinesep)
    let beforeList = tmp2->substitute('\v"(.|' .. g:dbiclient_prelinesep .. '){-}"', {m -> s:trim_surround(substitute(s:trim_surround_CRLF(m[0]), g:dbiclient_prelinesep, g:dbiclient_prelinesep2,'g'))}, 'g')->split(g:dbiclient_prelinesep)
    let dbiclient_bufmap = getbufvar(s:bufnr('%'), 'dbiclient_bufmap', {})
    if dbiclient_bufmap.alignFlg
        let list = map(list, {_, line -> join(map(split(line, g:dbiclient_col_delimiter_align), {_, x -> trim(x)}), g:dbiclient_col_delimiter)})
    endif
    if empty(list)
        return
    endif
    let cols = dbiclient_bufmap.cols
    let tableNm = dbiclient_bufmap.data.tableNm
    let bufnr = s:bufnr(bufname)
    if s:gotoWinCurrentTab(bufnr) ==# -1
        let bufnr = s:aboveNewBuffer(bufname)
    endif
    call s:deletebufline(bufnr, 1, '$')
    let param  = dbiclient#funclib#List(list).foldl({x -> s:f.zip(cols, s:split(x, g:dbiclient_col_delimiter))}, []).value()
    let param2 = dbiclient#funclib#List(beforeList).foldl({x -> s:f.zip(cols, s:split(x, g:dbiclient_col_delimiter))}, []).value()
    call s:appendbufline(bufnr, '$', s:createUpdate(param, param2, tableNm, dbiclient_bufmap.alignFlg, port))
endfunction

function s:createDelete(vallist, beforevallist, tableNm, port) abort
    call s:debugLog('getPrimaryKeys start')
    let keys = s:getPrimaryKeys(a:tableNm, a:port)
    call s:debugLog('getPrimaryKeys end')
    if a:tableNm ==# ""
        return []
    endif
    let result=[]
    let i=0
    for items in a:vallist
        let beforedict = dbiclient#funclib#List(get(a:beforevallist, i, [])).foldl({x -> {x[0]:substitute(x[1], "'" , "''", 'g')}}, {}).value()
        let dict = dbiclient#funclib#List(items).foldl({x -> {x[0]:x[1]}}, {}).value()
        let res  = "DELETE FROM " .. a:tableNm
        if(len(keys) > 0)
            let diffList = keys[:]->filter({_, key -> trim(s:trim_surround(get(beforedict, key, '<*>'))) !=# trim(s:trim_surround(get(dict, key, '<*>')))})->map({_, key -> trim(s:trim_surround(get(beforedict, key, '<*>'))) .. ' != ' .. trim(s:trim_surround(get(dict, key, '<*>')))})
            if diffList->len() > 0
                let res  = '/* Change primary key */ ' .. res
            endif
            let res ..= {key -> ' WHERE ' .. key .. ' = ' .. "'" .. s:trim_surround(get(dict, key, '<*>')) .. "'"}(keys[0])
            let res ..= join(dbiclient#funclib#List(keys[1:]).foldl({key -> ' AND ' .. key .. ' = ' .. "'" .. s:trim_surround(get(dict, key, '<*>')) .. "'"}, []).value())
        else
            let res ..= ' WHERE <*>'
        endif
        call add(result, res .. ";")
        let i += 1
    endfor
    return result
endfunction

function s:createDeleteRange() range abort
    let port = s:getCurrentPort()
    if s:isDisableline(a:firstline, a:lastline)
        return
    endif
    if s:error1CurrentPort() || s:error3()
        return
    endif
    let bufname = "ScratchCreateDelete"
    let list = getline(a:firstline, a:lastline)
    let tmp = list->join(g:dbiclient_prelinesep)
    let list = tmp->substitute('\v"(.|' .. g:dbiclient_prelinesep .. '){-}"', {m -> s:trim_surround(substitute(s:trim_surround_CRLF(m[0]), g:dbiclient_prelinesep, g:dbiclient_prelinesep2,'g'))}, 'g')->split(g:dbiclient_prelinesep)
    let offset = getbufvar(s:bufnr('%'), 'dbiclient_col_line', 0)
    let remarkrow = getbufvar(s:bufnr('%'), 'dbiclient_remarks_flg', 0)
    let beforeList = getbufvar(s:bufnr('%'), 'dbiclient_lines', {})[a:firstline - offset + remarkrow : a:lastline - offset + remarkrow]
    let tmp2 = map(deepcopy(beforeList), {_, line -> substitute(line, g:dbiclient_prelinesep, '', 'g')})->join(g:dbiclient_prelinesep)
    let beforeList = tmp2->substitute('\v"(.|' .. g:dbiclient_prelinesep .. '){-}"', {m -> s:trim_surround(substitute(s:trim_surround_CRLF(m[0]), g:dbiclient_prelinesep, g:dbiclient_prelinesep2,'g'))}, 'g')->split(g:dbiclient_prelinesep)
    let dbiclient_bufmap = getbufvar(s:bufnr('%'), 'dbiclient_bufmap', {})
    if dbiclient_bufmap.alignFlg
        let list = map(list, {_, line -> join(map(split(line, g:dbiclient_col_delimiter_align), {_, x -> trim(x)}), g:dbiclient_col_delimiter)})
    endif
    if empty(list)
        return
    endif
    let cols = dbiclient_bufmap.cols
    let tableNm = dbiclient_bufmap.data.tableNm
    let bufnr = s:bufnr(bufname)
    if s:gotoWinCurrentTab(bufnr) ==# -1
        let bufnr = s:aboveNewBuffer(bufname)
    endif
    call s:deletebufline(bufnr, 1, '$')
    let param = dbiclient#funclib#List(list).foldl({x -> s:f.zip(cols, s:split(x, g:dbiclient_col_delimiter))}, []).value()
    let param2 = dbiclient#funclib#List(beforeList).foldl({x -> s:f.zip(cols, s:split(x, g:dbiclient_col_delimiter))}, []).value()
    call s:appendbufline(bufnr, '$', s:createDelete(param, param2, tableNm, port))
endfunction

def s:joblist(moveFlg: any)
    var cbufnr = s:bufnr('%')
    s:init()
    var port: number = s:getCurrentPort()
    filter(s:sendexprList, ((_, x) => s:ch_statusOk(x[1])))
    def Dbinfo(port2: any): any
        var msgList = []
        var connInfo = get(s:params, port2, {})
        add(msgList, ['PID', '=' .. get(connInfo, 'process', '')])
        add(msgList, ['SCHEMA', '=' .. s:getuser(connInfo)])
        add(msgList, ['DSN', '=' .. s:getdsn(connInfo.dsn)])
        add(msgList, ['STATUS', '=' .. s:ch_open2status(port2)])
        add(msgList, ['RUNNING', '=' .. join(map(filter(s:sendexprList[:], ((_, x) => x[0] ==# port2)), ((_, x) => string(x[1]))), ', ')])
        var msg2 = 'Info:'
        msg2 ..= s:f2.Foldl(((x, y) => x .. y), "", map(msgList, ((_, val) => ' [' .. val[0] ..  val[1] .. ']')))
        return msg2
    enddef
    var list = map(keys(s:params)->map(((_, z) => str2nr(z))), ((_, x) => (port ==# x ? '*' : '') .. x .. ' ' .. Dbinfo(x)))
    var bufname = 'DBIJobList'
    var bufnrNm = s:bufnr(bufname)
    var save_cursor = getcurpos()
    if (moveFlg && s:f.getwidCurrentTab(bufnrNm) ==# -1) || (!moveFlg && s:f.getwid(bufnrNm) ==# -1)
        bufnrNm = s:enewBuffer(bufname)
        s:f.noreadonly(bufnrNm)
        save_cursor = getcurpos()
    else
        s:gotoWinCurrentTab(bufnrNm)
        save_cursor = getcurpos()
        s:f.noreadonly(bufnrNm)
        s:deletebufline(bufnrNm, 1, '$')
    endif
    if getbufvar(bufnrNm, '&previewwindow')
        setbufvar(bufnrNm, '&previewwindow', 0)
    endif
    s:setnmap(bufnrNm, get(g:, 'dbiclient_nmap_job_CH', s:nmap_job_CH), ':<C-u>call <SID>chgjob(matchstr(getline("."), ''\v^\*?\zs\d+''), 1)<CR>')
    s:setnmap(bufnrNm, get(g:, 'dbiclient_nmap_job_ST', s:nmap_job_ST), ':<C-u>call <SID>jobStopNext(matchstr(getline("."), ''\v^\*?\zs\d+''))<CR>')
    s:setnmap(bufnrNm, get(g:, 'dbiclient_nmap_job_TA', s:nmap_job_TA), ':<C-u>call <SID>userTablesMain(matchstr(getline("."), ''\v^\*?\zs\d+''))<CR>')
    s:setnmap(bufnrNm, get(g:, 'dbiclient_nmap_job_HI', s:nmap_job_HI), ':<C-u>call <SID>dbhistoryCmd(matchstr(getline("."), ''\v^\*?\zs\d+''))<CR>')
    s:setallmap(bufnrNm)
    var msgList = []
    add(msgList, [get(g:, 'dbiclient_nmap_job_CH', s:nmap_job_CH), ':' .. 'CHANGE'])
    add(msgList, [get(g:, 'dbiclient_nmap_job_ST', s:nmap_job_ST), ':' .. 'STOP'])
    add(msgList, [get(g:, 'dbiclient_nmap_job_TA', s:nmap_job_TA), ':' .. 'TABLES'])
    add(msgList, [get(g:, 'dbiclient_nmap_job_HI', s:nmap_job_HI), ':' .. 'HISTORY'])
    var info = '"Quick Help<nmap> :'
    info ..= s:f2.Foldl(((x, y) => x .. y), "", map(msgList, ((_, val) => ' [' .. val[0] .. val[1] .. ']')))
    s:appendbufline(bufnrNm, '$', info)
    s:appendbufline(bufnrNm, '$', list)
    setpos('.', save_cursor)
    if !moveFlg
        s:gotoWin(cbufnr)
    endif
    s:f.readonly(bufnrNm)
    var matchadds = []
    add(matchadds, ['Comment', '\v^".{-}:'])
    add(matchadds, ['Identifier', '^\*.*'])
    add(matchadds, ['String', '\v%1l^".{-}:\zs.*$'])
    add(matchadds, ['Function', '\v%1l( \[)@<=.{-}(\:)@='])
    add(matchadds, ['ErrorMsg', 'fail'])
    setbufvar(bufnrNm, 'dbiclient_matches', matchadds)
    s:sethl(bufnrNm)
enddef

function s:updateStatus(moveFlg) abort
    let cport = s:getCurrentPort()
    for bufnr in uniq(sort(s:bufferList))
        let ro = getbufvar(bufnr, '&readonly', 0)
        call s:f.noreadonly(bufnr)
        let tupleList = getbufvar(bufnr, 'dbiclient_tupleList', [])
        if bufexists(bufnr) && !empty(tupleList)
            let tuple = tupleList[0]
            let list = tuple.Get2()
            let list = filter(list[:], {_, x -> x[0] !=# 'STATUS'})

            let connInfo = get(get(getbufvar(bufnr, 'dbiclient_bufmap', {}), 'data', {}), 'connInfo', {})
            if has_key(s:params, get(connInfo, 'port', ''))
                let status = s:ch_open2status(connInfo.port)
            else
                let status = 'closed'
            endif
            if get(connInfo, 'port', '') ==# cport && cport !=# -1
                call add(list, ['STATUS', '=' .. status .. '*'])
            else
                call add(list, ['STATUS', '=' .. status])
            endif
            let tuple = s:Tuple(tuple.Get1(), list)
            let tupleList[0] = tuple
            call setbufvar(bufnr, 'dbiclient_tupleList', tupleList)

            let maxsize = max(map(deepcopy(tupleList), {_, x -> len(x.Get1())}))
            let row = 1
            for tuple in tupleList
                let info = tuple.Get1() .. (repeat(' ', maxsize - len(tuple.Get1())) .. ' :')
                let info ..= s:f2.Foldl({x, y -> x .. y}, "", map(tuple.Get2(), {_, val -> ' [' .. val[0] .. val[1] .. ']'}))
                call s:setbufline(bufnr, row, info)
                let row += 1
            endfor
        endif
        if ro
            call s:f.readonly(bufnr)
        endif
    endfor
    if s:f.getwid(s:bufnr('DBIJobList')) !=# -1
        call s:joblist(a:moveFlg)
    endif
endfunction

function s:chgjob(port, moveFlg) abort
    let s:dbi_job_port = a:port
    call s:updateStatus(a:moveFlg)
endfunction

function s:jobNext() abort
    let keys = sort(keys(s:params))
    let index = min(filter(keys[:], {i, p -> p ==# s:getCurrentPort()}))
    let port = get(keys, index + 1, get(keys, 0, -1))
    if port !=# -1
        call s:chgjob(port, 0)
    endif
endfunction

function s:setSecurePassword(name) abort
    let shadowpath = s:Filepath.join(s:getRootPath(), 'SECPASS_') .. a:name
    if filereadable(shadowpath)
        if toupper(s:input('Confirm deletion of file<' .. shadowpath .. '> [(y)es, (n)o] ', '')) ==# 'Y'
            call delete(shadowpath)
        else
            return
        endif
    endif
    keepjumps silent! exe 'bwipeout! ' .. shadowpath
    redraw
    redrawstatus
    keepjumps silent! exe 'e ' .. shadowpath
    keepjumps X
    keepjumps silent! exe 'b#'
    redrawstatus
    keepjumps let pass = inputsecret('Enter DB password:')
    keepjumps silent! exe 'b#'
    keepjumps call setline(1, 'shadow:' .. pass)
    keepjumps silent! write
    let bufnr = bufnr('%')
    keepjumps silent! exe 'b#'
    keepjumps silent! exe "bwipeout! " .. bufnr
endfunction

function s:getUnusedPort() abort
    let port = -1
    for p in range(49152, 65535)
        if !s:ch_statusStrOk(s:ch_open2status(p))
            return p
        endif
    endfor
    throw "oops"
endfunction

function s:connect_secure(port, dsn, user, passwordName, opt) abort
    let pass = '' 
    let opt = a:opt
    let shadowpath = s:Filepath.join(s:getRootPath(), 'SECPASS_') .. a:passwordName
    if filereadable(shadowpath) 
        silent! keepjumps exe 'bo new ' .. shadowpath
        let pass = matchstr(getline(1), '^shadow:\zs.*')
        keepjumps bwipeout!
        if empty(pass)
            redraw
            echohl WarningMsg
            echo 'Password is incorrect'
            echohl None
            return
        endif
        call s:connect(a:port, a:dsn, a:user, pass, opt)
    endif
endfunction

def s:connect(port: any, dsn: string, user: string, pass: string, opt2: any)
    s:init()
    var port2 = empty(port) ? s:getUnusedPort() : port
    var limitrows2 = get(opt2, s:connect_opt_limitrows, s:limitrows)
    var encoding2 = get(opt2, s:connect_opt_encoding, 'utf8')
    s:dbi_job_port = port2
    var portStr = string(port2)
    def Cb_jobout2(ch2: any, msg2: any)
        if msg2 ==# portStr
            s:connect_base(dsn, user, pass, limitrows2, encoding2, opt2)
            s:loadQueryHistoryCmd(port2)
        endif
    enddef
    def Cb_joberr2(ch2: any, msg2: any)
        s:kill_job(port2)
        redraw
        echohl ErrorMsg
        echom iconv(string(msg2), get(get(s:params, portStr, {}), 'encoding', &enc), g:dbiclient_buffer_encoding)
        echohl None
    enddef

    if has_key(s:params, portStr) && get(opt2, 'reconnect', 0) ==# 0
        opt2.reconnect = 1
        s:jobStop(port2)
        s:connect(port2, dsn, user, pass, opt2)
        return
    endif
    if portStr !~# '\v^[[0-9]+$'
        throw 'port error ' .. portStr
    endif
    if !has_key(s:params, portStr) && s:ch_statusStrOk(s:ch_open2status(port2))
        s:echoMsg('IO18', port2)
        return
    endif
    var logpath = s:getRootPath()
    var cmdlist = ['perl', s:getPerlmPath(), port2, logpath, g:dbiclient_perl_binmode, get(opt2, s:connect_opt_debuglog, 0)]
    s:debugLog(join(cmdlist, ' '))
    if has_key(opt2, 'reconnect')
        opt2.reconnect = 0
    endif
    s:jobs[portStr] = job_start(cmdlist, {
                  'err_cb': Cb_joberr2,
                  'stoponexit': '',
                  'out_cb': Cb_jobout2
                 })
    s:params[portStr] = {}
    s:params[portStr].port = port2
enddef

function s:kill_job(port) abort
    let port = a:port
    if !has_key(s:params, port)
        return
    endif
    let channel = ch_open('localhost:' .. port)
    if s:ch_statusOk(channel)
        let result = s:ch_evalexpr(channel, {"kill" : 1} , {"timeout":30000})
        call s:ch_close(channel)
    else
    endif
    if has_key(s:jobs, port)
        call remove(s:jobs, port)
    endif
    if has_key(s:params, port)
        call remove(s:params, port)
    endif
    if s:f.getwid(s:bufnr('DBIJobList')) !=# -1
        call s:joblist(0)
    endif
endfunction

function s:jobStopAll() abort
    for [port, job] in items(s:params)
        call s:jobStop(port)
    endfor
endfunction

function s:jobStopNext(port) abort
    let port = a:port
    let save_cursor = getcurpos()
    let cport = s:getCurrentPort()
    call s:jobStop(port)
    if port ==# cport
        call s:jobNext()
    else
        call s:chgjob(cport, 0)
    endif
    call s:updateStatus(0)
    call setpos('.', save_cursor)
endfunction

function s:jobStop(port) abort
    call filter(s:sendexprList, {_, x -> s:ch_statusOk(x[1])})
    if len(filter(s:sendexprList[:], {_, x -> x[0] ==# a:port})) > 0
        call s:echoMsg('IO05', 'running channel ' .. string(s:sendexprList))
        return 0
    endif
    let port = a:port
    if empty(s:params)
        return 0
    endif
    let s:dbi_job_port=-1
    if has_key(s:params, port)
        call s:kill_job(port)
        if has_key(s:jobs, port)
            call remove(s:jobs, port)
        endif
        if has_key(s:params, port)
            call remove(s:params, port)
        endif
        for file in split(glob(s:Filepath.join(s:getRootPath(), '*.lock')), "\n")
            let port2 = fnamemodify(file, ':p:t:r')
            if port ==# port2
                call delete(file)
            endif
        endfor
    endif
    if s:f.getwid(s:bufnr('DBIJobList')) !=# -1
        call s:joblist(0)
    endif
    return 1
endfunction

function s:cancel(port) abort
    let port = a:port
    if empty(s:params)
        return 0
    endif
    if has_key(s:jobs, port)
        call filter(s:sendexprList, {_, x -> s:ch_statusOk(x[1])})
        let sendexprList = filter(s:sendexprList[:], {_, x -> x[0] ==# port})
        if len(sendexprList) > 0
            call job_stop(s:jobs[port], 'int')
        endif
    endif
endfunction

function s:selectRangeSQL(alignFlg, limitrows) range abort
    let port = s:getCurrentPort()
    if s:error1CurrentPort()
        return {}
    endif

    let limitrows = a:limitrows
    let list = s:f.getRangeCurList(getpos("'<"), getpos("'>"))
    if empty(list)
        return
    endif
    let regexp='\v\c^\s*%(def|define)\s+([[:alnum:]_]+)\s*\=(.*)$'
    let deflist = filter(list[:], {_, x -> x =~? regexp})
    let sqllist = filter(list[:], {_, x -> x !~# regexp})
    let defineDict = s:f2.Foldl({x, y -> extend(x, y)}, {}, map(deflist[:], {_, x -> s:getDefinedKeyValue(x)}))
    let defineKeys = join(uniq(sort(keys(defineDict))), '|')

    let sqllist = s:splitSql(sqllist, 0)
    let sqllist = map(sqllist, {_, x -> substitute(x, '\v\c\&\&(%(' .. defineKeys .. ')>\.?)' , {m -> get(defineDict, matchstr(m[1], '\v^.{-}\ze\.?$'), m[0])}, 'g')})

    if len(sqllist) > 10
        redraw
        echohl ErrorMsg
        echo 'You cannot execute more than 10 sql at the same time.'
        echohl None
        return {}
    endif
    if s:error1(port)
        return {}
    endif
    let save_dbiclient_previewwindow = g:dbiclient_previewwindow
    if len(sqllist) > 1
        let g:dbiclient_previewwindow = 0
        let ymdhmss = strftime("%Y%m%d%H%M%S", localtime()) .. reltime()[1][-4:] .. split(reltimestr(reltime()), '\.')[1]
        let opt = {}
        let bufname='ResultRows_' .. s:getuser(s:params[port]) .. '_' .. port .. '_' .. ymdhmss
        let [bufnr, cbufnr] = s:belowPeditBuffer(bufname)
        let opt.reloadBufname = bufname
        let opt.reloadBufnr = bufnr
        let opt.nonowloading = 1
        let tupleList = []
        let msgList = []
        let connInfo = get(s:params, port, {})
        let status = s:getStatus(port, connInfo)
        call add(msgList, ['PID', '=' .. get(connInfo, 'process', '')])
        call add(msgList, ['PORT', '=' .. port])
        call add(msgList, ['SCHEMA', '=' .. s:getuser(connInfo)])
        call add(msgList, ['DSN', '=' .. s:getdsn(connInfo.dsn)])
        call add(msgList, ['STATUS', '=' .. (connInfo.port ==# s:getCurrentPort() ? status .. '*' : status)])
        call add(tupleList, s:Tuple('"Connection info', msgList))
        let matchadds=[]
        call add(matchadds, ['Comment', '\v%1l^".{-}:'])
        call add(matchadds, ['String', '\v%1l^".{-}:\zs.*$'])
        call add(matchadds, ['Function', '\v%1l( \[)@<=.{-}(\=)@='])
        let maxsize = max(map(deepcopy(tupleList), {_, x -> len(x.Get1())}))
        for tuple in tupleList
            let info = tuple.Get1() .. (repeat(' ', maxsize - len(tuple.Get1())) .. ' :')
            let info ..= s:f2.Foldl({x, y -> x .. y}, "", map(tuple.Get2(), {_, val -> ' [' .. val[0] .. val[1] .. ']'}))
            call s:appendbufline(bufnr, '$', [info])
        endfor
        if !empty(matchadds)
            call setbufvar(bufnr, 'dbiclient_matches', matchadds)
            call s:sethl(bufnr)
        endif
        for sql in sqllist
            let channel = s:getQueryAsync(trim(sql), 's:cb_outputResultMany', limitrows, opt, port)
        endfor
    else
        if len(sqllist) > 0
            let channel = s:getQueryAsync(trim(sqllist[0]), s:callbackstr(a:alignFlg), limitrows, {}, port)
        endif
    endif
    let g:dbiclient_previewwindow = save_dbiclient_previewwindow
endfunction

function s:cb_outputResultMany(ch, dict) abort
    call s:ch_close(a:ch)
    let opt = get(a:dict.data, 'opt', {})
    let starttime = localtime()
    let port = get(a:dict.data.connInfo, 'port')
    let opt = get(a:dict.data, 'opt', {})
    let ymdhmss = strftime("%Y%m%d%H%M%S", localtime()) .. reltime()[1][-4:] .. split(reltimestr(reltime()), '\.')[1]
    let bufname = get(a:dict.data, 'reloadBufname', '')
    let bufnr = s:bufnr(get(a:dict.data, 'reloadBufnr', -1))
    let lines = s:readfile(a:dict.data.tempfile)
    let cols = get(a:dict, 'cols',[])
    let colsstr = join(cols, "\t")
    let columnsRemarks = s:getColumnsTableRemarks(get(a:dict, 'column_info', []))
    let headstr = ""
    if g:dbiclient_disp_remarks
        let head = map(cols[:], {i, x -> get(columnsRemarks, x, '')})
        if !empty(filter(head[:], {_, x -> x !=# ''}))
            let headstr = join(head, "\t")
        endif
    endif
    let table = a:dict.data.tableNm
    let tableRemarks = ''
    for table in split(a:dict.data.tableJoinNm, ' ')
        let remarks = get(s:getTableRemarks(get(a:dict, 'table_info', [])), table, '')
        if g:dbiclient_disp_remarks && !empty(remarks)
            let tableRemarks .= table .. ' (' .. remarks .. ') '
        else
            let remarks = get(s:getTableRemarks(get(a:dict, 'table_info', [])), toupper(table), '')
            if g:dbiclient_disp_remarks && !empty(remarks)
                let tableRemarks .= table .. ' (' .. remarks .. ') '
            else
                let tableRemarks .= table .. ' '
            endif
        endif
    endfor
    let tmp = s:getSqlLine(a:dict.data.sql)
    let tmp = (strdisplaywidth(tmp) > 2000 ? strcharpart(tmp,0,2000) .. '...' : tmp)
    let surr='\V'
    let lines = map(lines[:], {_, line -> substitute(substitute(line, surr .. s:getprelinesep() .. '\v|\V' .. s:getprelinesep() .. surr, '', 'g'), s:tab_placefolder, "\t", 'g')})
    call appendbufline(bufnr, '$', [tmp])
    if !empty(tableRemarks)
        call appendbufline(bufnr, '$', [tableRemarks])
    endif
    if !empty(headstr)
        call appendbufline(bufnr, '$', [headstr])
    endif
    if !empty(colsstr)
        call appendbufline(bufnr, '$', [colsstr])
    endif
    if !empty(lines)
        call appendbufline(bufnr, '$', lines)
    endif
    call appendbufline(bufnr, '$', [''])
    return 0
endfunction

function s:split(str, delim) abort
    return split(a:str, a:delim, '1')
endfunction

function s:echoMsg(id, ...) abort
    let msg = get(s:msg, a:id)
    for i in range(a:0)
        let msg = substitute(msg, '\V$' .. (i+1), escape(a:000[i], '\&'), '')
    endfor
    redraw
    if a:id[0:0] ==# 'E'
        echohl ErrorMsg
    elseif a:id[0:0] ==# 'I'
        echohl Normal
    else
        echohl WarningMsg
    endif
    echo msg
    echohl None
endfunction

function s:dBExecRangeSQLDo(bang, splitFlg) range abort
    let port = s:getCurrentPort()
    let list = s:f.getRangeCurList(getpos("'<"), getpos("'>"))
    if empty(trim(join(list)))
        return
    endif
    let regexp='\v\c^\s*%(def|define)\s+([[:alnum:]_]+)\s*\=(.*)$'
    let deflist = filter(list[:], {_, x -> x =~? regexp})
    let sqllist = filter(list[:], {_, x -> x !~# regexp})
    let defineDict = s:f2.Foldl({x, y -> extend(x, y)}, {}, map(deflist[:], {_, x -> s:getDefinedKeyValue(x)}))
    let defineKeys = join(uniq(sort(keys(defineDict))), '|')

    if a:splitFlg
        let sqllist = s:splitSql(sqllist, 1)
    else
        let sqllist = [join(sqllist, "\n")]
    endif
    let sqllist = map(sqllist, {_, x -> substitute(x, '\v\c\&\&(%(' .. defineKeys .. ')>\.?)' , {m -> get(defineDict, matchstr(m[1], '\v^.{-}\ze\.?$'), m[0])}, 'g')})
    call s:dBCommandAsync({"doText":list[:], "do":sqllist, "continue":(a:bang ==# '!' ? 1 : 0)}, 's:cb_do', port)
endfunction

def s:splitSql(sqllist: list<string>, doFlg: number): list<string>
    var delim: string = g:dbiclient_sql_delimiter1
    if len(filter(sqllist[:], (_, x) => trim(x) ==# g:dbiclient_sql_delimiter2)) > 0
        delim = g:dbiclient_sql_delimiter2
    endif
    var list = sqllist[:]
    list = filter(list, (_, x) => !empty(trim(x)))
    var sql = join(list, "\n")
    if doFlg && delim ==# g:dbiclient_sql_delimiter2
        var ret1 = []
        var start = 0
        while start > -1
            var msp = matchstrpos(sql, '\v^.{-}\n\s*\' .. delim .. '\s*(\n|$)', start)
            if msp[2] > -1
                call add(ret1, substitute(trim(msp[0]), '\v\' .. delim .. '\s*%$', '', ''))
            else
                call add(ret1, substitute(trim(sql[start : ]), '\v\' .. delim .. '\s*%$', '', ''))
            endif
            start = msp[2]
        endwhile
        return filter(ret1, (_, x) => !empty(trim(x)))
    else
        if sql =~? '\v^\_s*(insert|update|delete|merge|replace|create|alter|grant|revoke|with)'
            return s:split(sql, '\v' .. delim .. '\s*(\n|$)')->filter(((_, x) => !empty(trim(x))))
        else
            var parsedata = s:parseSQL2(sql)
            return parsedata.splitSql3(parsedata, delim)
        endif
    endif
enddef

function s:getQuerySync(sql, callback, limitrows, opt, port) abort
    let data = s:getQuery(a:sql, a:limitrows, a:opt, a:port)
    return funcref(a:callback)({}, data)
endfunction

def s:getQuery(sql: any, limitrows2: any, opt2: any, port2: any): any
    var ret2 = {}
    if s:error1(port2)
        return ret2
    endif
    var schemtableNm = s:getTableName(sql, get(opt2, 'tableNm', ''))
    var tableNm = matchstr(schemtableNm, '\v^(.{-}\.)?\zs.*')
    var schem = matchstr(schemtableNm, '\v\zs^(.{-})\ze\..*')
    var tableJoinNm = join(s:getTableJoinListUniq(sql), " ")
    var tableJoinNmWithAs = s:getTableJoinList(sql)
    var channel = ch_open('localhost:' .. port2)
    if !s:ch_statusOk(channel)
        return ret2
    endif
    var param = {
                "sql": sql,
                "tableNm": tableNm,
                "schem": schem,
                "tableJoinNm": tableJoinNm,
                "tableJoinNmWithAs": tableJoinNmWithAs,
                "cols": [],
                'connInfo': s:params[port2],
                "limitrows": limitrows2,
                'linesep': get(opt2, 'linesep', g:dbiclient_linesep),
                'surround': get(opt2, 'surround', g:dbiclient_surround),
                'null': get(opt2, 'null', g:dbiclient_null),
                'table_info': get(opt2, 'table_info', 0),
                'column_info': get(opt2, 'column_info', 0),
                'column_info_data': get(opt2, 'column_info_data', 0),
                'single_table': get(opt2, 'single_table', ''),
                'reloadBufname': get(opt2, 'reloadBufname', ''),
                'reloadBufnr': get(opt2, 'reloadBufnr', -1),
                'tempfile': s:tempname()
    }
    var result = s:ch_evalexpr(channel, param, {"timeout": 30000})
    if s:f.getwid(s:bufnr('DBIJobList')) !=# -1
        s:joblist(0)
    endif
    if type(result) ==# v:t_dict
        s:ch_close(channel)
        ret2 = result
        def DictGetData(): any
            return s:getData(ret2)
        enddef
        ret2.GetData = DictGetData
        return ret2
    else
        s:ch_close(channel)
        return ret2
    endif
enddef

function s:getData(dbiclient_bufmap) abort
    let result = a:dbiclient_bufmap
    if filereadable(result.data.tempfile) && has_key(result, 'cols')
        let contents = filter(s:readfile(result.data.tempfile), {_, x -> x !~# '\v^\s*$'})
        let cols = result.cols
        return map(contents, {_, line -> s:f2.Foldl({x, y -> extend(x, y)}, {}, map(split(line, '\t', 1), {i, x -> {cols[i]:x}}))})
    else
        return []
    endif
endfunction

function s:getQueryAsyncSimple(sql) abort
    let port = s:getCurrentPort()
    if s:error1(port)
        return {}
    endif
    return s:getQueryAsync(a:sql, 's:cb_outputResultEasyAlign', -1, {'noaddhistory':1}, port)
endfunction

function s:getQueryAsync(sql, callback, limitrows, opt, port) abort
    if s:error0(a:port)
        return {}
    endif

    let sql = a:sql
    let schemtableNm = s:getTableName(a:sql, get(a:opt, 'tableNm', ''))
    let tableNm = matchstr(schemtableNm, '\v^(.{-}\.)?\zs.*')
    let schem = matchstr(schemtableNm, '\v\zs^(.{-})\ze\..*')
    let tableJoinNm = join(s:getTableJoinListUniq(sql), " ")
    let tableJoinNmWithAs = s:getTableJoinList(a:sql)
    let cols = []
    for item in tableJoinNmWithAs
        let prefix = empty(item.AS) ? item.tableNm .. '.' : item.AS .. '.'
        if empty(prefix) && len(tableJoinNmWithAs) > 1
            let prefix = item.tableNm .. '.'
        endif
        let cols = extend(cols, map(s:getColumns(item.tableNm, a:port), {_, x -> prefix .. x}))
    endfor
    let channel = ch_open('localhost:' .. a:port)
    if !s:ch_statusOk(channel)
        return {}
    endif
    let ymdhmss = strftime("%Y%m%d%H%M%S", localtime()) .. reltime()[1][-4:] .. split(reltimestr(reltime()), '\.')[1]
    let bufname = get(a:opt, 'reloadBufname', 'Result_' .. s:getuser(s:params[a:port]) .. '_' .. a:port .. '_' .. ymdhmss)
    let bufnr = s:bufnr(get(a:opt, 'reloadBufnr', s:bufnr(bufname)))

    let ro = getbufvar(bufnr, '&readonly', 0)
    if s:f.getwid(bufnr) ==# -1
        let [bufnr, cbufnr] = s:belowPeditBuffer(bufname)
        call add(s:bufferList, bufnr)
        call s:addbufferlist(a:port, bufnr)
    else
        call s:f.noreadonly(bufnr)
        if !get(a:opt, 'nonowloading', 0)
            call s:deletebufline(bufnr, 1, '$')
            call setbufvar(bufnr, 'dbiclient_bufmap', {})
            call setbufvar(bufnr, 'dbiclient_col_line', 0)
            call setbufvar(bufnr, 'dbiclient_header', [])
            call setbufvar(bufnr, 'dbiclient_lines', [])
            call setbufvar(bufnr, 'dbiclient_matches', [])
            call setbufvar(bufnr, 'dbiclient_nmap', [])
            call setbufvar(bufnr, 'dbiclient_vmap', [])
        endif
        let cbufnr = bufnr('%')
    endif
    if sql !=# ''
        call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_result_WH', s:nmap_result_WH),      ':<C-u>call <SID>bufCopy()<CR>:<C-u>call <SID>where()<CR>')
        call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_result_RE', s:nmap_result_RE),      ':<C-u>call <SID>bufCopy()<CR>:<C-u>call <SID>reload(<SID>bufnr("%"), "", 1)<CR>')
        call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_result_LI', s:nmap_result_LI),      ':<C-u>call <SID>bufCopy()<CR>:<C-u>call <SID>reloadLimit(<SID>bufnr("%"), "", <SID>input("LIMIT:", <SID>getLimitrowsaBuffer()))<CR>')
        call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_result_SE', s:nmap_result_SE),      ':<C-u>call <SID>bufCopy()<CR>:<C-u>call <SID>select()<CR>')
        call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_result_IJ', s:nmap_result_IJ),      ':<C-u>call <SID>bufCopy()<CR>:<C-u>call <SID>ijoin("INNER")<CR>')
        call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_result_LJ', s:nmap_result_LJ),      ':<C-u>call <SID>bufCopy()<CR>:<C-u>call <SID>ijoin("LEFT")<CR>')
        call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_result_GR', s:nmap_result_GR),      ':<C-u>call <SID>bufCopy()<CR>:<C-u>call <SID>group()<CR>')
        call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_result_OR', s:nmap_result_OR),      ':<C-u>call <SID>bufCopy()<CR>:<C-u>call <SID>order()<CR>')
        call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_result_AL', s:nmap_result_AL),      ':<C-u>call <SID>align(!get(b:dbiclient_bufmap, "alignFlg", 0), <SID>bufnr("%"), <SID>getprelinesep())<CR>')
        call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_result_DI', s:nmap_result_DI),      ':<C-u>call <SID>doDeleteInsert()<CR>')
        call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_result_ED', s:nmap_result_ED),      ':<C-u>call <SID>bufCopy()<CR>:<C-u>call <SID>editSql()<CR>')
        call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_result_BN', s:nmap_result_BN),      ':<C-u>call <SID>bufnext(' .. a:port .. ', <SID>bufnr("%"))<CR>')
        call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_result_BP', s:nmap_result_BP),      ':<C-u>call <SID>bufprev(' .. a:port .. ', <SID>bufnr("%"))<CR>')
        call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_result_BD', s:nmap_result_BD),      ':<C-u>call <SID>bufdel(' .. a:port .. ', <SID>bufnr("%"))<CR>')
        call s:setvmap(bufnr, get(g:, 'dbiclient_vmap_result_IN', s:vmap_result_IN),  ':call <SID>createInsertRange()<CR>')
        call s:setvmap(bufnr, get(g:, 'dbiclient_vmap_result_DE', s:vmap_result_DE),  ':call <SID>createDeleteRange()<CR>')
        call s:setvmap(bufnr, get(g:, 'dbiclient_vmap_result_UP', s:vmap_result_UP),  ':call <SID>createUpdateRange()<CR>')
    elseif get(a:opt, 'column_info', 0) ==# 1
        call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_result_BN', s:nmap_result_BN),      ':<C-u>call <SID>bufnext(' .. a:port .. ', <SID>bufnr("%"))<CR>')
        call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_result_BP', s:nmap_result_BP),      ':<C-u>call <SID>bufprev(' .. a:port .. ', <SID>bufnr("%"))<CR>')
        call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_result_BD', s:nmap_result_BD),      ':<C-u>call <SID>bufdel(' .. a:port .. ', <SID>bufnr("%"))<CR>')
    elseif get(a:opt, 'table_info', 0) ==# 1
        call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_table_SQ', s:nmap_table_SQ), ':<C-u>call <SID>selectTableOfList(<SID>getTableNameSchem(<SID>getPort()), <SID>getPort())<CR>')
        call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_table_CT', s:nmap_table_CT), ':<C-u>call <SID>count(<SID>getTableNameSchem(<SID>getPort()), <SID>getPort())<CR>')
        call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_table_TW', s:nmap_table_TW), ':<C-u>call <SID>userTables(b:dbiclient_bufmap.alignFlg , <SID>input("TABLE_NAME:", get(<SID>getParams(), "table_name", "")) , get(<SID>getParams(), "tabletype", "")                        , <SID>getPort())<CR>')
        call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_table_TT', s:nmap_table_TT), ':<C-u>call <SID>userTables(b:dbiclient_bufmap.alignFlg , get(<SID>getParams(), "table_name", "")                        , <SID>input("TABLE_TYPE:", get(<SID>getParams(), "tabletype", "")) , <SID>getPort())<CR>')
    endif
    if !get(a:opt, 'nonowloading', 0)
        call s:appendbufline(bufnr, '$', ['Now loading...'])
    endif
    if !empty(get(a:opt, 'reloadBufname', ''))
        call s:debugLog('reloadBufname')
        call s:gotoWin(bufnr)
    endif
    exe 'autocmd CursorMoved <buffer=' .. bufnr .. '> :call s:PopupColInfo()'
    if ro
        call s:f.readonly(bufnr)
    endif
    if !g:dbiclient_previewwindow
        call s:gotoWin(bufnr)
    endif
    let param = {
                \"opt"            : a:opt
                \, "sql"           : sql
                \, "tableNm"       : tableNm
                \, "schem"         : schem
                \, "tableJoinNm"   : tableJoinNm
                \, "tableJoinNmWithAs"   : tableJoinNmWithAs
                \, "cols"   : cols
                \, "limitrows"     : a:limitrows
                \, 'linesep'       : get(a:opt , 'linesep' , g:dbiclient_linesep)
                \, 'surround'      : get(a:opt , 'surround' , g:dbiclient_surround)
                \, 'null'          : get(a:opt , 'null' , g:dbiclient_null)
                \, 'prelinesep'    : s:getprelinesep()
                \, 'table_info'    : get(a:opt , 'table_info' , 0)
                \, 'column_info'   : get(a:opt , 'column_info' , 0)
                \, 'column_info_data'   : get(a:opt, 'column_info_data', 0)
                \, 'table_name'    : get(a:opt , 'table_name' , '')
                \, 'tabletype'     : get(a:opt , 'tabletype' , '')
                \, 'single_table'  : get(a:opt , 'single_table' , '')
                \, 'reloadBufname' : bufname
                \, 'reloadBufnr'   : bufnr
                \, 'callbackstr'   : a:callback
                \, 'connInfo'      : s:params[a:port]
                \, 'tempfile'      : s:tempname()}
    let param.setnmaps = getbufvar(bufnr, 'dbiclient_nmap', [])
    let param.setvmaps = getbufvar(bufnr, 'dbiclient_vmap', [])
    call s:ch_sendexpr(channel, param , {"callback": funcref(a:callback)}, bufnr)
    return channel
endfunction

function s:commit() abort
    let port = s:getCurrentPort()
    call s:dBCommandAsync({"commit":"1", "nodisplay":1}, 's:cb_do', port)
endfunction

function s:rollback() abort
    let port = s:getCurrentPort()
    call s:dBCommandAsync({"rollback":"1", "nodisplay":1}, 's:cb_do', port)
endfunction

function s:set(key, value) abort
    let ret = s:dBCommandMain({'setkey':a:key, 'setvalue':a:value})
    return ret
endfunction

function s:dbclose(port) abort
    let port = a:port
    if s:error1(port)
        return {}
    endif
    let ret = s:dBCommand(port, {"close":"1"})
    let s:params[port].connect = 0
    return ret
endfunction

function s:connect_base(dsn, user, pass, limitrows, encoding, opt) abort
    let port = s:getCurrentPort()
    let opt = a:opt
    let user = empty(a:user) ? '' : a:user
    let dsn = substitute(a:dsn , '\v^\s*', '', '')
    if has_key(s:params, port)
        let s:params[port]={}
        let s:params[port].datasource = substitute(dsn , '\v^\s*', '', '')
        let s:params[port].user = user
        let s:params[port].hashKey = sha256(dsn .. a:user .. a:pass)
        let s:params[port].limitrows = a:limitrows
        let s:params[port].port = port
        let s:params[port].encoding = a:encoding
        let s:params[port].dsn = dsn
        let s:params[port].columninfoflg = get(opt, s:connect_opt_columninfoflg, g:dbiclient_connect_opt_columninfoflg)
        let s:params[port].primarykeyflg = get(opt, s:connect_opt_primarykeyflg, g:dbiclient_connect_opt_primarykeyflg)
        let s:params[port].table_name = get(opt, s:connect_opt_table_name, g:dbiclient_connect_opt_table_name)
        let s:params[port].tabletype = get(opt, s:connect_opt_table_type, g:dbiclient_connect_opt_table_type)
        let s:params[port].schema_flg = get(opt, s:connect_opt_schema_flg, g:dbiclient_connect_opt_schema_flg)
        let s:params[port].schema_list = get(opt, s:connect_opt_schema_list, g:dbiclient_connect_opt_schema_list)
        let s:params[port].history_data_flg = get(opt, s:connect_opt_history_data_flg, g:dbiclient_connect_opt_history_data_flg)
        let s:params[port].envdict = get(opt, s:connect_opt_envdict, g:dbiclient_connect_opt_envdict)
        let s:params[port].process = job_info(s:jobs[port]).process
        let command = deepcopy(s:params[port])
        let command.pass = a:pass
        let ret = s:dBCommandNoChk(port, command)
        let s:params[port].connect = get(ret, 'status', 9)
        if s:params[port].connect ==# 1
            call g:Dbiclient_call_after_connected()
        elseif s:params[port].connect ==# 9
            echoerr ret.message
        endif
        let lockfilepath = s:Filepath.join(s:getRootPath(), port .. '.lock')
        call writefile([string(s:params[port])], lockfilepath)
    else
        call s:echoMsg('IO19', port)
    endif
    "call s:deleteHistoryCmd(port)
    call s:chgjob(port, 0)
endfunction

function s:dBCommandNoChk(port, command) abort
    let port = a:port
    let channel = ch_open('localhost:' .. port)
    let errret = {}
    let errret.message = 'channel:' .. channel
    if !s:ch_statusOk(channel)
        return errret
    endif
    let command = a:command
    let command.tempfile = s:tempname()
    let result = s:ch_evalexpr(channel, command, {"timeout":60000})
    if s:ch_statusOk(channel)
        if type(result) ==# v:t_dict
            call s:ch_close(channel)
            return result
        else
            call s:ch_close(channel)
            return errret
        endif
    else
        return errret
    endif
endfunction

function s:ch_sendexpr(handle, expr, opt, bufnr) abort
    let result = ch_sendexpr(a:handle, a:expr, a:opt)
    call add(s:sendexprList, [a:expr.connInfo.port, a:handle, a:bufnr])
    if s:f.getwid(s:bufnr('DBIJobList')) !=# -1
        call s:joblist(0)
    endif
    return result
endfunction

function s:ch_evalexpr(handle, expr, opt) abort
    let result = ch_evalexpr(a:handle, a:expr, a:opt)
    return result
endfunction

function s:dBCommand(port, command) abort
    if s:error1(a:port)
        return {}
    endif
    return s:dBCommandNoChk(a:port, a:command)
endfunction

function s:dBCommandMain(command) abort
    let port = s:getCurrentPort()
    return s:dBCommand(port, a:command)
endfunction

function s:dBCommandAsync(command, callback, port) abort
    let port = a:port
    if s:error1(port)
        return {}
    endif
    if has_key(a:command, 'do') && len(get(a:command, 'do', [])) ==# 0
        return {}
    endif
    let channel = ch_open('localhost:' .. port)
    if !s:ch_statusOk(channel)
        return {}
    endif
    let command = a:command
    let command.tempfile = s:tempname()
    let command.connInfo = s:params[port]
    let bufnr = -1
    if get(command, "nodisplay", 0) !=# 1 
        let ymdhmss = strftime("%Y%m%d%H%M%S", localtime()) .. reltime()[1][-4:] .. split(reltimestr(reltime()), '\.')[1]
        let bufname='Result_' .. s:getuser(s:params[a:port]) .. '_' .. port .. '_' .. ymdhmss
        let bufnr = s:bufnr(bufname)
        let ro = getbufvar(bufnr, '&readonly', 0)
        if s:f.getwid(bufnr) ==# -1
            let [bufnr, cbufnr] = s:belowPeditBuffer(bufname)
            call add(s:bufferList, bufnr)
            call s:addbufferlist(port, bufnr)
        else
            call s:f.noreadonly(bufnr)
            call s:deletebufline(bufnr, 1, '$')
            call setbufvar(bufnr, 'dbiclient_bufmap', {})
            call setbufvar(bufnr, 'dbiclient_col_line', 0)
            call setbufvar(bufnr, 'dbiclient_header', [])
            call setbufvar(bufnr, 'dbiclient_lines', [])
            call setbufvar(bufnr, 'dbiclient_matches', [])
            call setbufvar(bufnr, 'dbiclient_nmap', [])
            call setbufvar(bufnr, 'dbiclient_vmap', [])
            let cbufnr = bufnr('%')
        endif
        call s:appendbufline(bufnr, '$', ['Now loading...'])
        "exe 'autocmd BufDelete,BufWipeout,QuitPre,BufUnload <buffer=' .. bufnr .. '> :call s:cancel(' .. a:port .. ',' .. bufnr .. ')'
        if ro
            call s:f.readonly(bufnr)
        endif
        if !g:dbiclient_previewwindow
            call s:gotoWin(bufnr)
        endif
        let command.reloadBufname = bufname
        let command.reloadBufnr = bufnr
        let command.setnmaps = getbufvar(bufnr, 'dbiclient_nmap', [])
        let command.setvmaps = getbufvar(bufnr, 'dbiclient_vmap', [])
    endif

    call s:ch_sendexpr(channel, command, {"callback": funcref(a:callback)}, bufnr)
endfunction

function s:cb_do(ch, dict) abort
    let starttime = localtime()
    let port = get(a:dict.data.connInfo, 'port')
    let connInfo = get(a:dict.data, 'connInfo')
    call s:ch_close(a:ch)
    let bufnr = s:bufnr(get(get(a:dict, 'data', {}), 'reloadBufnr', -1))
    let ro = getbufvar(bufnr, '&readonly', 0)
    let matchadds=[]
    if has_key(a:dict, 'commit')
        if get(a:dict, "status", 9) ==# 1
            call s:echoMsg('IO13')
        endif
    elseif has_key(a:dict, 'rollback')
        if get(a:dict, "status", 9) ==# 1
            call s:echoMsg('IO14')
        endif
    else
        let ymdhms = strftime("%Y%m%d%H%M%S", localtime())
        let bufname = get(a:dict.data, 'reloadBufname', '')
        if get(a:dict, 'restoreFlg', 0) ==# 1
            let bufnr = s:bufnr(bufname)
        endif
        if s:f.getwid(bufnr) ==# -1
            let [bufnr, cbufnr] = s:belowPeditBuffer(bufname)
            let a:dict.data.reloadBufnr = bufnr
            call add(s:bufferList, bufnr)
            call s:addbufferlist(port, bufnr)
        else
            call s:f.noreadonly(bufnr)
            call s:deletebufline(bufnr, 1, '$')
            call setbufvar(bufnr, 'dbiclient_bufmap', {})
            call setbufvar(bufnr, 'dbiclient_col_line', 0)
            call setbufvar(bufnr, 'dbiclient_header', [])
            call setbufvar(bufnr, 'dbiclient_lines', [])
            call setbufvar(bufnr, 'dbiclient_matches', [])
            call setbufvar(bufnr, 'dbiclient_nmap', [])
            call setbufvar(bufnr, 'dbiclient_vmap', [])
            let cbufnr = bufnr('%')
        endif
        call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_do_PR', s:nmap_do_PR), ':<C-u>call <SID>editSqlDo()<CR>')
        call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_do_BN', s:nmap_do_BN), ':<C-u>call <SID>bufnext(' .. port .. ', <SID>bufnr("%"))<CR>')
        call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_do_BP', s:nmap_do_BP), ':<C-u>call <SID>bufprev(' .. port .. ', <SID>bufnr("%"))<CR>')
        call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_do_BD', s:nmap_do_BD), ':<C-u>call <SID>bufdel(' .. port .. ', <SID>bufnr("%"))<CR>')
        call s:setallmap(bufnr)
        let status = s:getStatus(port, connInfo)
        let tupleList = []
        let msgList = []
        call add(msgList, ['PID', '=' .. get(connInfo, 'process', '')])
        call add(msgList, ['PORT', '=' .. port])
        call add(msgList, ['SCHEMA', '=' .. s:getuser(connInfo)])
        call add(msgList, ['DSN', '=' .. s:getdsn(connInfo.dsn)])
        call add(msgList, ['STATUS', '=' .. (connInfo.port ==# s:getCurrentPort() ? status .. '*' : status)])
        call add(tupleList, s:Tuple('"Connection info', msgList))
        let msgList = []
        call add(msgList, ['COUNT', '=' .. get(a:dict, 'cnt', -1)])
        call add(msgList, ['START', '=' .. get(a:dict, 'startdate', '')])
        call add(msgList, ['END', '=' .. get(a:dict, 'enddate', '')])
        call add(msgList, ['SQL', '=' .. get(a:dict, 'sqltime', 0) .. 'ms'])
        call add(tupleList, s:Tuple('"Response info', msgList))
        let msgList = []
        call add(msgList, [get(g:, 'dbiclient_nmap_do_PR', s:nmap_do_PR), ':SQL_PREVIEW'])
        call add(msgList, [get(g:, 'dbiclient_nmap_do_BN', s:nmap_do_BN), ':NEXTBUF'])
        call add(msgList, [get(g:, 'dbiclient_nmap_do_BP', s:nmap_do_BP), ':PREVBUF'])
        call add(msgList, [get(g:, 'dbiclient_nmap_do_BD', s:nmap_do_BD), ':DELBUF'])
        call add(tupleList, s:Tuple('"Quick Help<nmap>', msgList))
        call setbufvar(bufnr, 'dbiclient_tupleList', tupleList)
        let maxsize = max(map(deepcopy(tupleList), {_, x -> len(x.Get1())}))
        for tuple in tupleList
            let info = tuple.Get1() .. (repeat(' ', maxsize - len(tuple.Get1())) .. ' :')
            let info ..= s:f2.Foldl({x, y -> x .. y}, "", map(tuple.Get2(), {_, val -> ' [' .. val[0] .. val[1] .. ']'}))
            call s:appendbufline(bufnr, '$', [info])
        endfor
        call add(matchadds, ['Comment', '\v%1l^".{-}:'])
        call add(matchadds, ['Comment', '\v%2l^".{-}:'])
        call add(matchadds, ['String', '\v%1l^".{-}:\zs.*$'])
        call add(matchadds, ['String', '\v%2l^".{-}:\zs.*$'])
        call add(matchadds, ['Function', '\v%1l( \[)@<=.{-}(\=)@='])
        call add(matchadds, ['Function', '\v%2l( \[)@<=.{-}(\=)@='])
        call add(matchadds, ['Comment', '\v%3l^".{-}:'])
        call add(matchadds, ['String', '\v%3l^".{-}:\zs.*$'])
        call add(matchadds, ['Function', '\v%3l( \[)@<=.{-}(\:)@='])
        let i = 0
        let strlines = s:readfile(a:dict.data.tempfile)
        call s:appendbufline(bufnr, '$', strlines)

        if get(a:dict, "status", 9) ==# 1
            let lines = map(s:readfile(a:dict.data.tempfile .. '.err'), {_, str -> substitute(str, '\v at (( at )@!.)*$', '', 'g')})
            call map(lines, {i, x -> iconv(x, get(connInfo, 'encoding', &enc), g:dbiclient_buffer_encoding)})
            if !empty(lines)
                call s:appendbufline(bufnr, '$', lines)
            endif
        endif
    endif
    if get(a:dict, "status", 9) !=# 9 && get(a:dict, 'restoreFlg', 0) !=# 1 && !empty(get(a:dict.data, 'do', []))
        let path = s:getHistoryPathCmd(port)
        let bufVals=[]
        let datetime = strftime("%Y-%m-%d %H:%M:%S ")
        let dsn = get(connInfo, 'dsn', '')
        let user = s:getuser(connInfo)
        let connStr = user .. '@' .. dsn

        let sql = substitute(s:getSqlLine(string(get(a:dict.data, 'do', ''))), '\t', ' ', 'g')
        let sql = (strdisplaywidth(sql) > 300 ? strcharpart(sql,0,300) .. '...' : sql) .. "\t"
        let dbiclient_bufmap = a:dict
        call add(bufVals, string(dbiclient_bufmap))

        "let lastnum = str2nr(get(s:history_data[path], -1, '')->matchstr('\v^[0-9]+\ze ')) + 1
        "let ww = [printf('%04d', lastnum) .. ' ' .. datetime .. 'DSN:' .. connStr .. ' SQL:' .. sql .. ' ' .. join(bufVals, '{DELIMITER_CR}')]
        let ww = [datetime .. 'DSN:' .. connStr .. ' SQL:' .. sql .. ' ' .. join(bufVals, '{DELIMITER_CR}')]
        call writefile(ww, path, 'a')
        call add(s:history_data[path], ww[0])
        if s:params[port].history_data_flg ==# 0 && filereadable(a:dict.data.tempfile)
            call delete(a:dict.data.tempfile)
        endif
        if s:params[port].history_data_flg ==# 0 && filereadable(a:dict.data.tempfile .. '.err')
            call delete(a:dict.data.tempfile .. '.err')
        endif
    endif
    let endttime = localtime()
    if bufnr !=# -1
        let tupleList = getbufvar(bufnr, 'dbiclient_tupleList', [])
        let maxsize = max(map(deepcopy(tupleList), {_, x -> len(x.Get1())}))
        let tuple = tupleList[1]
        let msgList = tuple.Get2()
        call add(msgList, ['VIM', '=' .. (endttime - starttime) .. 'sec'])
        let tuple = s:Tuple(tuple.Get1(), msgList)
        let tupleList[1] = tuple
        let info = tuple.Get1() .. (repeat(' ', maxsize - len(tuple.Get1())) .. ' :')
        let info ..= s:f2.Foldl({x, y -> x .. y}, "", map(tuple.Get2(), {_, val -> ' [' .. val[0] .. val[1] .. ']'}))
        call s:setbufline(bufnr, 2, info)
        call setbufvar(bufnr, 'dbiclient_tupleList', tupleList)
        call setbufvar(bufnr, 'dbiclient_bufmap', deepcopy(a:dict))
        if !empty(matchadds)
            call setbufvar(bufnr, 'dbiclient_matches', matchadds)
            call s:sethl(bufnr)
        endif
    endif
    "call s:debugLog(a:dict)
    if s:f.getwid(s:bufnr('DBIJobList')) !=# -1
        call s:joblist(0)
    endif
    if ro
        call s:f.readonly(bufnr)
    endif
endfunction

function s:getStatus(port, connInfo) abort
    let hashKey1 = get(get(s:params, a:port, {}), 'hashKey', '1')
    let hashKey2 = get(a:connInfo, 'hashKey', '2')
    if hashKey1 ==# hashKey2
        let status = s:ch_open2status(a:port)
    else
        let status = 'closed'
    endif
    return status
endfunction

function s:cb_outputResultCmn(ch, dict, bufnr) abort
    let port = get(a:dict.data.connInfo, 'port')
    let connInfo = get(a:dict.data, 'connInfo')
    let bufnr = a:bufnr
    call s:ch_close(a:ch)

    let status = s:getStatus(port, connInfo)
    let opt = get(a:dict.data, 'opt', {})
    let tupleList = []
    let msgList = []
    call add(msgList, ['PID', '=' .. get(connInfo, 'process', '')])
    call add(msgList, ['PORT', '=' .. port])
    call add(msgList, ['SCHEMA', '=' .. s:getuser(connInfo)])
    call add(msgList, ['DSN', '=' .. s:getdsn(connInfo.dsn)])
    call add(msgList, ['STATUS', '=' .. (connInfo.port ==# s:getCurrentPort() ? status .. '*' : status)])
    call add(tupleList, s:Tuple('"Connection info', msgList))
    let msgList = []
    call add(msgList, ['COUNT', '=' .. get(a:dict, 'cnt', -1)])
    call add(msgList, ['LIMIT', '=' .. get(a:dict.data, 'limitrows', -1)])
    call add(msgList, ['START', '=' .. get(a:dict, 'startdate', '')])
    call add(msgList, ['END', '=' .. get(a:dict, 'enddate', '')])
    call add(msgList, ['SQL', '=' .. get(a:dict, 'sqltime', 0) .. 'ms'])
    call add(msgList, ['FETCH', '=' .. get(a:dict, 'fetchtime', 0) .. 'ms'])
    call add(msgList, ['COLUMN', '=' .. get(a:dict, 'columntime', 0) .. 'ms'])
    call add(tupleList, s:Tuple('"Response info', msgList))
    let matchadds=[]
    call add(matchadds, ['Comment', '\v%1l^".{-}:'])
    call add(matchadds, ['Comment', '\v%2l^".{-}:'])
    call add(matchadds, ['String', '\v%1l^".{-}:\zs.*$'])
    call add(matchadds, ['String', '\v%2l^".{-}:\zs.*$'])
    call add(matchadds, ['Function', '\v%1l( \[)@<=.{-}(\=)@='])
    call add(matchadds, ['Function', '\v%2l( \[)@<=.{-}(\=)@='])
    let dbiclient_col_line = -1
    let dbiclient_remarks_flg = 0

    let parseSQL = s:parseSQL(a:dict.data.sql, get(a:dict.data, 'cols', [])[:])
    let a:dict.data.single_table = get(parseSQL, 'table', '')
    if !empty(get(parseSQL, 'ijoin', ''))
        let a:dict.data.single_table = substitute(a:dict.data.single_table, '\v\s.*', '', '')
    endif
    if get(a:dict, "status", 9) !=# 2
        if get(a:dict.data, 'sql', '') !=# ''
            call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_do_BN', s:nmap_do_BN), ':<C-u>call <SID>bufnext(' .. port .. ', <SID>bufnr("%"))<CR>')
            call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_do_BP', s:nmap_do_BP), ':<C-u>call <SID>bufprev(' .. port .. ', <SID>bufnr("%"))<CR>')
            call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_do_BD', s:nmap_do_BD), ':<C-u>call <SID>bufdel(' .. port .. ', <SID>bufnr("%"))<CR>')
            let list1=[]
            let msgList = []
            let singleTableFlg = !empty(get(get(a:dict, 'data', {}), 'single_table', ''))
            if singleTableFlg
                call add(msgList, [get(g:, 'dbiclient_nmap_result_SE', s:nmap_result_SE), ':SELECT'])
                call add(msgList, [get(g:, 'dbiclient_nmap_result_IJ', s:nmap_result_IJ), ':IJOIN'])
                call add(msgList, [get(g:, 'dbiclient_nmap_result_LJ', s:nmap_result_LJ), ':LJOIN'])
                call add(msgList, [get(g:, 'dbiclient_nmap_result_WH', s:nmap_result_WH), ':WHERE'])
                call add(msgList, [get(g:, 'dbiclient_nmap_result_OR', s:nmap_result_OR), ':ORDER'])
                call add(msgList, [get(g:, 'dbiclient_nmap_result_GR', s:nmap_result_GR), ':GROUP'])
                if get(a:dict, 'hasnext', 1) ==# 0
                    call add(msgList, [get(g:, 'dbiclient_nmap_result_DI', s:nmap_result_DI), ':DELETE INSERT'])
                endif
            endif
            call add(msgList, [get(g:, 'dbiclient_nmap_result_RE', s:nmap_result_RE), ':RELOAD'])
            call add(msgList, [get(g:, 'dbiclient_nmap_result_LI', s:nmap_result_LI), ':LIMIT'])
            call add(msgList, [get(g:, 'dbiclient_nmap_result_AL', s:nmap_result_AL), ':ALIGN'])
            call add(msgList, [get(g:, 'dbiclient_nmap_result_ED', s:nmap_result_ED), ':EDIT'])
            call add(msgList, [get(g:, 'dbiclient_nmap_result_BN', s:nmap_result_BN), ':NEXTBUF'])
            call add(msgList, [get(g:, 'dbiclient_nmap_result_BP', s:nmap_result_BP), ':PREVBUF'])
            call add(msgList, [get(g:, 'dbiclient_nmap_result_BD', s:nmap_result_BD), ':DELBUF'])

            let nmapkeylist = map(getbufvar(bufnr, 'dbiclient_nmap', [])[:], {_, x -> x[0]})
            let msgList2 = []
            for msg in msgList
                if index(nmapkeylist, msg[0]) != -1
                    call add(msgList2, msg)
                endif
            endfor
            call add(tupleList, s:Tuple('"Quick Help<nmap>', msgList2))
            call add(matchadds, ['Comment', '\v%3l^".{-}:'])
            call add(matchadds, ['String', '\v%3l^".{-}:\zs.*$'])
            call add(matchadds, ['Function', '\v%3l( \[)@<=.{-}(\:)@='])

            let msgList = []
            call add(msgList, [get(g:, 'dbiclient_vmap_result_IN', s:vmap_result_IN), ':INSERT'])
            call add(msgList, [get(g:, 'dbiclient_vmap_result_UP', s:vmap_result_UP), ':UPDATE'])
            call add(msgList, [get(g:, 'dbiclient_vmap_result_DE', s:vmap_result_DE), ':DELETE'])

            let vmapkeylist = map(getbufvar(bufnr, 'dbiclient_vmap', [])[:], {_, x -> x[0]})
            let msgList2 = []
            for msg in msgList
                if index(vmapkeylist, msg[0]) != -1
                    call add(msgList2, msg)
                endif
            endfor
            call add(tupleList, s:Tuple('"Quick Help<vmap>', msgList2))
            call add(matchadds, ['Comment', '\v%4l^".{-}:'])
            call add(matchadds, ['String', '\v%4l^".{-}:\zs.*$'])
            call add(matchadds, ['Function', '\v%4l( \[)@<=.{-}(\:)@='])
        elseif get(a:dict.data, 'table_info', 0) ==# 1
            let msgList = []
            call add(msgList, [get(g:, 'dbiclient_nmap_table_SQ', s:nmap_table_SQ), ':SQL'])
            call add(msgList, [get(g:, 'dbiclient_nmap_table_CT', s:nmap_table_CT), ':COUNT'])
            call add(msgList, [get(g:, 'dbiclient_nmap_table_TW', s:nmap_table_TW), ':TABLE_NAME'])
            call add(msgList, [get(g:, 'dbiclient_nmap_table_TT', s:nmap_table_TT), ':TABLE_TYPE'])
            call add(tupleList, s:Tuple('"Quick Help', msgList))
            call add(matchadds, ['Comment', '\v%3l^".{-}:'])
            call add(matchadds, ['String', '\v%3l^".{-}:\zs.*$'])
            call add(matchadds, ['Function', '\v%3l( \[)@<=.{-}(\:)@='])
            let data = s:getData(a:dict)
            if empty(s:params[port].tabletype) && empty(s:params[port].table_name)
                let s:params[port].table_list = uniq(sort(map(data[:], {_, x -> get(x, 'TABLE_NAME', '')})))
                let s:params[port].table_type = uniq(sort(map(data[:], {_, x -> get(x, 'TABLE_TYPE', '')})))
            endif
        elseif get(a:dict.data, 'column_info', 0) ==# 1
            let msgList = []
            call add(msgList, [get(g:, 'dbiclient_nmap_result_BN', s:nmap_result_BN), ':NEXTBUF'])
            call add(msgList, [get(g:, 'dbiclient_nmap_result_BP', s:nmap_result_BP), ':PREVBUF'])
            call add(msgList, [get(g:, 'dbiclient_nmap_result_BD', s:nmap_result_BD), ':DELBUF'])
            call add(tupleList, s:Tuple('"Quick Help', msgList))
            call add(matchadds, ['Comment', '\v%3l^".{-}:'])
            call add(matchadds, ['String', '\v%3l^".{-}:\zs.*$'])
            call add(matchadds, ['Function', '\v%3l( \[)@<=.{-}(\:)@='])
        endif
    endif
    let disableline = []
    call setbufvar(bufnr, 'dbiclient_tupleList', tupleList)
    let maxsize = max(map(deepcopy(tupleList), {_, x -> len(x.Get1())}))
    for tuple in tupleList
        let info = tuple.Get1() .. (repeat(' ', maxsize - len(tuple.Get1())) .. ' :')
        let info ..= s:f2.Foldl({x, y -> x .. y}, "", map(tuple.Get2(), {_, val -> ' [' .. val[0] .. val[1] .. ']'}))
        call s:appendbufline(bufnr, '$', [info])
        call add(disableline, s:endbufline(bufnr))
    endfor
    if get(a:dict, "status", 9) ==# 1

        if get(opt, "nosql", 0) ==# 0 && !empty(a:dict.data.sql)
            let tmp = s:getSqlLine(a:dict.data.sql)
            let tmp = (strdisplaywidth(tmp) > 2000 ? strcharpart(tmp,0,2000) .. '...' : tmp)
            call s:appendbufline(bufnr, '$', [tmp])
            call add(disableline, s:endbufline(bufnr))
            call s:appendbufline(bufnr, '$', [substitute(tmp, '.', '-', 'g')])
            call add(disableline, s:endbufline(bufnr))
        endif
        if get(opt, "notablenm", 0) ==# 0 && !empty(a:dict.data.tableJoinNm)
            let table = a:dict.data.tableNm
            let tableRemarks = ''
            for table in split(a:dict.data.tableJoinNm, ' ')
                let remarks = get(s:getTableRemarks(get(a:dict, 'table_info', [])), table, '')
                if g:dbiclient_disp_remarks && !empty(remarks)
                    let tableRemarks .= table .. ' (' .. remarks .. ') '
                else
                    let remarks = get(s:getTableRemarks(get(a:dict, 'table_info', [])), toupper(table), '')
                    if g:dbiclient_disp_remarks && !empty(remarks)
                        let tableRemarks .= table .. ' (' .. remarks .. ') '
                    else
                        let tableRemarks .= table .. ' '
                    endif
                endif
            endfor
            call s:appendbufline(bufnr, '$', [tableRemarks])
            call add(matchadds, ['Identifier', '\v%' .. (s:endbufline(bufnr)) .. 'l\V' .. tableRemarks])
            call add(disableline, s:endbufline(bufnr))
        endif
        let cols = get(a:dict, 'cols',[])
        if get(opt, "nocols", 0) ==# 0 && !empty(cols)
            let columnsRemarks = s:getColumnsTableRemarks(get(a:dict, 'column_info', []))
            let columnsPopupInfo = s:getColumnsPopupInfo(get(a:dict, 'column_info', []))
            let a:dict.data.columnsPopupInfo = columnsPopupInfo
            if g:dbiclient_disp_remarks
                let head = map(cols[:], {i, x -> get(columnsRemarks, x, '')})
                if !empty(filter(head[:], {_, x -> x !=# ''}))
                    let headstr = join(head, "\t")
                    call s:appendbufline(bufnr, '$', [headstr])
                    call add(disableline, s:endbufline(bufnr))
                    let dbiclient_remarks_flg = 1
                    if len(head) > 0
                    endif
                    if !empty(get(a:dict, 'maxcols', []))
                        call map(a:dict.maxcols, {i, size -> strdisplaywidth(head[i]) > size ? strdisplaywidth(head[i]) : size})
                    endif
                endif
            endif
            let colsstr = join(cols, "\t")
            call s:appendbufline(bufnr, '$', [colsstr])
            call add(disableline, s:endbufline(bufnr))
            if dbiclient_col_line ==# -1
                let dbiclient_col_line = s:endbufline(bufnr)
            endif
            if len(cols) > 0
            endif
            if len(get(a:dict, 'primary_key', [])) > 0
                let matchkeys = get(a:dict, 'primary_key', [])[:]
                call add(matchadds, ['Title', '\v%' .. (s:endbufline(bufnr)) .. 'l' .. '(' .. join(map(sort(matchkeys, {x, y -> len(x) ==# len(y) ? 0 : len(x) < len(y) ? 1 : -1}), {_, x -> '<\V' .. x .. '\v>'}), '|') .. ')'])
            endif
            if g:dbiclient_disp_headerline
                let border = join(map(get(a:dict,'maxcols',[])[:], {_, x -> repeat('-', x)}), "\t")
                call s:appendbufline(bufnr, '$', [border])
                call add(disableline, s:endbufline(bufnr))
            endif
        endif
        if get(a:dict.data, 'column_info', 0) ==# 1
            if len(get(a:dict, 'primary_key', [])) > 0
                let matchkeys = get(a:dict, 'primary_key', [])[:]
                call add(matchadds, ['Title', '\v' .. '(' .. join(map(sort(matchkeys, {x, y -> len(x) ==# len(y) ? 0 : len(x) < len(y) ? 1 : -1}), {_, x -> '<\V' .. x .. '\v>'}), '|') .. ')'])
            endif
        endif
        let lines = s:readfile(a:dict.data.tempfile)
        if g:dbiclient_col_delimiter !=# "\t"
            call s:appendbufline(bufnr, '$', substitute(lines, '\t' , g:dbiclient_col_delimiter, 'g'))
        else
            call s:appendbufline(bufnr, '$', lines)
        endif

    elseif get(a:dict, "status", 9) ==# 2
        let sql = a:dict.data.sql
        let lines = s:readfile(a:dict.data.tempfile)
        call s:appendbufline(bufnr, '$', lines)
    else
        let lines = s:readfile(a:dict.data.tempfile)
        call s:appendbufline(bufnr, '$', lines)
    endif
    if get(a:dict, "status", 9) ==# 1
        let lines = map(s:readfile(a:dict.data.tempfile .. '.err'), {_, str -> substitute(str, '\v at (( at )@!.)*$', '', 'g')})
        call map(lines, {i, x -> iconv(x, get(connInfo, 'encoding', &enc), g:dbiclient_buffer_encoding)})
        if !empty(lines)
            call s:appendbufline(bufnr, '$', lines)
        endif
    endif
    let dbiclient_bufmap = deepcopy(a:dict)
    let dbiclient_bufmap.opt = opt
    if has_key(dbiclient_bufmap.opt, 'reloadBufname')
        call remove(dbiclient_bufmap.opt, 'reloadBufname')
    endif
    if has_key(dbiclient_bufmap.opt, 'reloadBufnr')
        call remove(dbiclient_bufmap.opt, 'reloadBufnr')
    endif
    let cols = get(dbiclient_bufmap.data, 'cols', [])[:]
    if empty(cols)
        let cols = get(dbiclient_bufmap, 'cols', [])[:]
    endif
    let precols = get(dbiclient_bufmap.opt, 'precols', [])[:]
    let updateColsFlg = !(join(cols) == join(precols))
    if empty(get(dbiclient_bufmap.opt, 'where', [])) || updateColsFlg
        let maxcol = max(map(cols[:], {_, x -> strdisplaywidth(x)}))
        let where = map(cols[:], {_, x -> x .. repeat(' ' , maxcol - strdisplaywidth(x) +1) .. '| ='})
    endif
    if empty(get(dbiclient_bufmap.opt, 'ijoin', [])) || updateColsFlg
        let maxcol = max(map(cols[:], {_, x -> strdisplaywidth(x)}))
        let ijoin = map(cols[:], {_, x -> x .. repeat(' ' , maxcol - strdisplaywidth(x) +1) .. '| ='})
    endif
    if empty(get(dbiclient_bufmap.opt, 'extend', [])) || updateColsFlg
        let dbiclient_bufmap.opt.extend={}
        let dbiclient_bufmap.opt.extend.select = get(parseSQL, 'select', '')
        let dbiclient_bufmap.opt.extend.table = get(parseSQL, 'table', '')
        let dbiclient_bufmap.opt.extend.from = get(parseSQL, 'from', '')
        let dbiclient_bufmap.opt.extend.dblink = get(parseSQL, 'dblink', '')
        let dbiclient_bufmap.opt.extend.ijoin = get(parseSQL, 'ijoin', '')
        let dbiclient_bufmap.opt.extend.where = get(parseSQL, 'where', '')
        let dbiclient_bufmap.opt.extend.order = get(parseSQL, 'order', '')
        let dbiclient_bufmap.opt.extend.group = get(parseSQL, 'group', '')
        let dbiclient_bufmap.opt.extend.having = get(parseSQL, 'having', '')

        if !updateColsFlg && !empty(get(dbiclient_bufmap.opt, 'where', []))
            let where = dbiclient_bufmap.opt.where[:]
        endif

        call s:debugLog('parseSQLwhere')
        let parsedata = s:parseSQL2(a:dict.data.sql)
        let parseSQLwhere = substitute(substitute(parsedata.getMaintype(parsedata, 'WHERE'), '\v\c^\s*<where>\s*', '', ''), '\n', ' ', 'g')
        let andlist = []
        if parseSQLwhere !~? '\v\c(<or>)'
            let andlist = split(parseSQLwhere, '\v\c<and>')
            let colsRegex = '\v\c^\s*(' .. join(map(cols[:], {_, x -> '<\V' .. x}), '\v>|') .. '\v)\zs'
            try
                let parseSQLwhereList = map(andlist[:], {_, x -> map(split(trim(x), colsRegex), {_, xx -> trim(xx)})})
            catch /./
                let parseSQLwhereList = []
            endtry
            let parseSQLwhereDict = s:f2.Foldl({x, y -> extend(x, y)}, {}, map(parseSQLwhereList, {i, xx -> get(xx, 1, '') ==# '' ? {} : {toupper(get(xx, 0, '')) : get(xx, 1, '')}}))
        endif
        if !empty(andlist) && len(andlist) ==# len(items(parseSQLwhereDict))
            let where = map(where, {_, x -> has_key(parseSQLwhereDict, toupper(matchstr(x, '\v^.{-}\ze\s*\|'))) ? matchstr(x, '\v^.{-}\s*\|\s*') .. get(parseSQLwhereDict, toupper(matchstr(x, '\v^.{-}\ze\s*\|')), '') : x})
        else
            let extendWhere = substitute(get(dbiclient_bufmap.opt.extend, 'where', ''), '\v\c^\s*<where>\s*', '', '')

            call filter(where, {i, x -> !(i ==# 0 && x =~? '\v^\s*\(')})
            if !empty(extendWhere)
                call insert(where, '(' .. matchstr(extendWhere, '\v^\s*\(\zs.*\ze\)\s*$|^\s*\zs.*\ze\s*$') .. ')', 0)
            endif
        endif

        let dbiclient_bufmap.opt.ijoin = ijoin
        let dbiclient_bufmap.opt.where = where

        let F1 = {x -> matchstr(x, '\v^\s*\zs.+\ze\s*')}
        let F2 = {x -> trim(substitute(matchstr(x, '\v^\s*\zs.+\ze\s*'), '\v(ASC|DESC)\s*$', '', ''))}

        let selectStr = map(split(matchstr(substitute(dbiclient_bufmap.opt.extend.select, '\n', ' ', 'g'), '\v\c<select> \zs.{-}\ze\s*$'), '\v\s*,\s*'), {_, x -> trim(x)})
        let selectStr = filter(selectStr, {_, x -> x !=# '*'})
        let dbiclient_bufmap.opt.select = {}
        let dbiclient_bufmap.opt.select.selectdict = s:f2.Foldl({x, y -> extend(x, y)}, {}, map(selectStr[:], {i, x -> {F1(x) : i+1}}))
        let dbiclient_bufmap.opt.select.selectdictstr = s:f2.Foldl({x, y -> extend(x, y)}, {}, map(selectStr[:], {i, x -> {F1(x) : '*' .. (i+1) .. ' ' .. F1(x)}}))
        let dbiclient_bufmap.opt.select.selectdictAscDesc = s:f2.Foldl({x, y -> extend(x, y)}, {}, map(selectStr[:], {i, x -> {F1(x) : 0}}))
        let dbiclient_bufmap.opt.select.selectUnmatchCols = uniq(sort(filter(selectStr[:], {i, x -> match(cols, '\V' .. substitute(trim(x), '\\', '\\\\', 'g')) == -1})))

        let orderStr = map(split(matchstr(substitute(dbiclient_bufmap.opt.extend.order, '\n', ' ', 'g'), '\v\c<order>\s+<by> \zs.{-}\ze\s*$'), '\v\s*,\s*'), {_, x -> trim(x)})
        let dbiclient_bufmap.opt.order = {}
        let dbiclient_bufmap.opt.order.selectdict = s:f2.Foldl({x, y -> extend(x, y)}, {}, map(orderStr[:], {i, x -> {F2(x) : i+1}}))
        let dbiclient_bufmap.opt.order.selectdictstr = s:f2.Foldl({x, y -> extend(x, y)}, {}, map(orderStr[:], {i, x -> {F2(x) : (x =~? '\v\c<desc>' ? '[DESC]' : '[ASC]') .. (i+1) .. ' ' .. F2(x)}}))
        let dbiclient_bufmap.opt.order.selectdictAscDesc = s:f2.Foldl({x, y -> extend(x, y)}, {}, map(orderStr[:], {i, x -> {F2(x) : x =~? '\v\c<desc>' ? 1 : 0}}))
        let dbiclient_bufmap.opt.order.selectUnmatchCols = uniq(sort(filter(orderStr[:], {i, x -> match(cols, '\V' .. substitute(trim(substitute(x, '\v\c\s+(<desc>|<asc>)', '', '')), '\\', '\\\\', 'g')) == -1})))

        let groupStr = map(split(matchstr(substitute(dbiclient_bufmap.opt.extend.group, '\n', ' ', 'g'), '\v\c<group>\s+<by> \zs.{-}\ze\s*$'), '\v\s*,\s*'), {_, x -> trim(x)})
        let dbiclient_bufmap.opt.group = {}
        let dbiclient_bufmap.opt.group.selectdict = s:f2.Foldl({x, y -> extend(x, y)}, {}, map(groupStr[:], {i, x -> {F1(x) : i+1}}))
        let dbiclient_bufmap.opt.group.selectdictstr = s:f2.Foldl({x, y -> extend(x, y)}, {}, map(groupStr[:], {i, x -> {F1(x) : '*' .. (i+1) .. ' ' .. F1(x)}}))
        let dbiclient_bufmap.opt.group.selectdictAscDesc = s:f2.Foldl({x, y -> extend(x, y)}, {}, map(groupStr[:], {i, x -> {F1(x) : 0}}))
        let dbiclient_bufmap.opt.group.selectUnmatchCols = uniq(sort(filter(groupStr[:], {i, x -> match(cols, '\V' .. substitute(trim(x), '\\', '\\\\', 'g')) == -1})))
    endif
    if get(a:dict, "status", 9) !=# 9 && get(a:dict, 'restoreFlg', 0) !=# 1 && !empty(get(a:dict.data, 'sql', ''))
        let path = s:getHistoryPathCmd(port)
        let bufVals=[]
        let datetime = strftime("%Y-%m-%d %H:%M:%S ")
        let dsn = get(connInfo, 'dsn', '')
        let user = s:getuser(connInfo)
        let connStr = user .. '@' .. dsn

        let sql = substitute(s:getSqlLine(get(a:dict.data, 'sql', '')), '\t', ' ', 'g')
        let sql = (strdisplaywidth(sql) > 300 ? strcharpart(sql,0,300) .. '...' : sql) .. "\t"
        call add(bufVals, string(dbiclient_bufmap))

        "let lastnum = str2nr(get(s:history_data[path], -1, '')->matchstr('\v^[0-9]+\ze ')) + 1
        "let ww = [printf('%04d', lastnum) .. ' ' .. datetime .. 'DSN:' .. connStr .. ' SQL:' .. sql .. ' ' .. join(bufVals, '{DELIMITER_CR}')]
        let ww = [datetime .. 'DSN:' .. connStr .. ' SQL:' .. sql .. ' ' .. join(bufVals, '{DELIMITER_CR}')]
        call writefile(ww, path, 'a')
        call add(s:history_data[path], ww[0])
        if s:params[port].history_data_flg ==# 0 && filereadable(a:dict.data.tempfile)
            call delete(a:dict.data.tempfile)
        endif
        if s:params[port].history_data_flg ==# 0 && filereadable(a:dict.data.tempfile .. '.err')
            call delete(a:dict.data.tempfile .. '.err')
        endif
    endif
    if get(a:dict, "status", 9) ==# 9
        let winid = s:f.getwid(bufnr)
        let disableline = range(line('$', winid))
    endif
    call setbufvar(bufnr, 'dbiclient_bufmap', dbiclient_bufmap)
    call setbufvar(bufnr, 'dbiclient_col_line', dbiclient_col_line)
    call setbufvar(bufnr, 'dbiclient_remarks_flg', dbiclient_remarks_flg)
    call setbufvar(bufnr, 'dbiclient_disableline', disableline)
    call s:setallmap(bufnr)
    if !empty(matchadds)
        call setbufvar(bufnr, 'dbiclient_matches', matchadds)
        call s:sethl(bufnr)
    endif
endfunction

function s:cb_outputResult(ch, dict) abort
    let starttime = localtime()
    let port = get(a:dict.data.connInfo, 'port')
    let opt = get(a:dict.data, 'opt', {})
    let ymdhmss = strftime("%Y%m%d%H%M%S", localtime()) .. reltime()[1][-4:] .. split(reltimestr(reltime()), '\.')[1]
    let bufname = get(a:dict.data, 'reloadBufname', '')
    let bufnr = s:bufnr(get(a:dict.data, 'reloadBufnr', -1))
    if get(a:dict, 'restoreFlg', 0) ==# 1
        let bufnr = s:bufnr(bufname)
    endif
    let ro = getbufvar(bufnr, '&readonly', 0)
    if s:f.getwid(bufnr) ==# -1
        let [bufnr, cbufnr] = s:belowPeditBuffer(bufname)
        let a:dict.data.reloadBufnr = bufnr
        call add(s:bufferList, bufnr)
        call s:addbufferlist(port, bufnr)
    else
        call s:f.noreadonly(bufnr)
        call s:deletebufline(bufnr, 1, '$')
        call setbufvar(bufnr, 'dbiclient_bufmap', {})
        call setbufvar(bufnr, 'dbiclient_col_line', 0)
        call setbufvar(bufnr, 'dbiclient_header', [])
        call setbufvar(bufnr, 'dbiclient_lines', [])
        call setbufvar(bufnr, 'dbiclient_matches', [])
        call setbufvar(bufnr, 'dbiclient_nmap', [])
        call setbufvar(bufnr, 'dbiclient_vmap', [])
        let cbufnr = bufnr('%')
    endif
    call setbufvar(bufnr, 'dbiclient_nmap', get(a:dict.data, 'setnmaps', []))
    call setbufvar(bufnr, 'dbiclient_vmap', get(a:dict.data, 'setvmaps', []))
    call s:cb_outputResultCmn(a:ch, a:dict, bufnr)
    let dbiclient_bufmap = getbufvar(bufnr, 'dbiclient_bufmap', {})
    let dbiclient_bufmap.alignFlg = 0
    if get(a:dict, "status", 9) ==# 1
        call s:align(0, bufnr, s:getprelinesep())
    endif
    let endttime = localtime()
    let tupleList = getbufvar(bufnr, 'dbiclient_tupleList', [])
    let maxsize = max(map(deepcopy(tupleList), {_, x -> len(x.Get1())}))
    let tuple = tupleList[1]
    let msgList = tuple.Get2()
    call add(msgList, ['VIM', '=' .. (endttime - starttime) .. 'sec'])
    let tuple = s:Tuple(tuple.Get1(), msgList)
    let tupleList[1] = tuple
    let info = tuple.Get1() .. (repeat(' ', maxsize - len(tuple.Get1())) .. ' :')
    let info ..= s:f2.Foldl({x, y -> x .. y}, "", map(tuple.Get2(), {_, val -> ' [' .. val[0] .. val[1] .. ']'}))
    call s:setbufline(bufnr, 2, info)
    call setbufvar(bufnr, 'dbiclient_tupleList', tupleList)
    let dbiclient_header = getbufvar(bufnr, 'dbiclient_header', [])
    if !empty(dbiclient_header)
        let dbiclient_header[1] = info
    endif
    if s:f.getwid(s:bufnr('DBIJobList')) !=# -1
        call s:joblist(0)
    endif
    if ro
        call s:f.readonly(bufnr)
    endif
    return 0
endfunction

function s:cb_outputResultEasyAlign(ch, dict) abort
    let starttime = localtime()
    let port = get(a:dict.data.connInfo, 'port')
    let opt = get(a:dict.data, 'opt', {})
    let ymdhmss = strftime("%Y%m%d%H%M%S", localtime()) .. reltime()[1][-4:] .. split(reltimestr(reltime()), '\.')[1]
    let bufname = get(a:dict.data, 'reloadBufname', '')
    let bufnr = s:bufnr(get(a:dict.data, 'reloadBufnr', -1))
    if get(a:dict, 'restoreFlg', 0) ==# 1
        let bufnr = s:bufnr(bufname)
    endif
    let ro = getbufvar(bufnr, '&readonly', 0)
    if s:f.getwid(bufnr) ==# -1
        let [bufnr, cbufnr] = s:belowPeditBuffer(bufname)
        let a:dict.data.reloadBufnr = bufnr
        call add(s:bufferList, bufnr)
        call s:addbufferlist(port, bufnr)
    else
        call s:f.noreadonly(bufnr)
        call s:deletebufline(bufnr, 1, '$')
        call setbufvar(bufnr, 'dbiclient_bufmap', {})
        call setbufvar(bufnr, 'dbiclient_col_line', 0)
        call setbufvar(bufnr, 'dbiclient_header', [])
        call setbufvar(bufnr, 'dbiclient_lines', [])
        call setbufvar(bufnr, 'dbiclient_matches', [])
        call setbufvar(bufnr, 'dbiclient_nmap', [])
        call setbufvar(bufnr, 'dbiclient_vmap', [])
        let cbufnr = bufnr('%')
    endif
    call setbufvar(bufnr, 'dbiclient_nmap', get(a:dict.data, 'setnmaps', []))
    call setbufvar(bufnr, 'dbiclient_vmap', get(a:dict.data, 'setvmaps', []))
    call s:cb_outputResultCmn(a:ch, a:dict, bufnr)
    let dbiclient_bufmap = getbufvar(bufnr, 'dbiclient_bufmap', {})
    let dbiclient_bufmap.alignFlg = 1
    if get(a:dict, "status", 9) ==# 1
        if s:endbufline(bufnr) >= 100000
            redraw
            echohl WarningMsg
            echo 'It did not "align" because it took a long time to display.'
            echohl None
            call s:align(0, bufnr, s:getprelinesep())
        else
            call s:align(1, bufnr, s:getprelinesep())
        endif
    endif
    let endttime = localtime()
    let tupleList = getbufvar(bufnr, 'dbiclient_tupleList', [])
    let maxsize = max(map(deepcopy(tupleList), {_, x -> len(x.Get1())}))
    let tuple = tupleList[1]
    let msgList = tuple.Get2()
    call add(msgList, ['VIM', '=' .. (endttime - starttime) .. 'sec'])
    let tuple = s:Tuple(tuple.Get1(), msgList)
    let tupleList[1] = tuple
    let info = tuple.Get1() .. (repeat(' ', maxsize - len(tuple.Get1())) .. ' :')
    let info ..= s:f2.Foldl({x, y -> x .. y}, "", map(tuple.Get2(), {_, val -> ' [' .. val[0] .. val[1] .. ']'}))
    call s:setbufline(bufnr, 2, info)
    call setbufvar(bufnr, 'dbiclient_tupleList', tupleList)
    let dbiclient_header = getbufvar(bufnr, 'dbiclient_header', [])
    if !empty(dbiclient_header)
        let dbiclient_header[1] = info
    endif
    if s:f.getwid(s:bufnr('DBIJobList')) !=# -1
        call s:joblist(0)
    endif
    if ro
        call s:f.readonly(bufnr)
    endif
    return 0
endfunction

function s:align(alignFlg, bufnr, preCr) abort
    let bufnr = a:bufnr
    let dbiclient_bufmap = getbufvar(bufnr, 'dbiclient_bufmap', {})
    if empty(dbiclient_bufmap) || empty(get(dbiclient_bufmap, "cols", []))
        return
    endif
    let colsize = len(dbiclient_bufmap.cols)
    let save_cursor = getcurpos()
    let dbiclient_bufmap.alignFlg = a:alignFlg
    let dbiclient_lines = getbufvar(bufnr, 'dbiclient_lines', [])
    let dbiclient_header = getbufvar(bufnr, 'dbiclient_header', [])
    let remarkrow = getbufvar(bufnr, 'dbiclient_remarks_flg', 0)
    let dbiclient_col_line = getbufvar(bufnr, 'dbiclient_col_line', 0) - remarkrow
    if empty(dbiclient_lines)
        let dbiclient_header = getbufline(bufnr, 0, dbiclient_col_line - 1)
        let dbiclient_lines = getbufline(bufnr, dbiclient_col_line, '$')
    endif
    call s:deletebufline(bufnr, 1, '$')
    call s:appendbufline(bufnr, '$', dbiclient_header)
    let dbiclient_lines_tmp = dbiclient_lines[:]
    if a:alignFlg ==# 1
        call s:appendbufline(bufnr, '$', dbiclient_lines_tmp)
        call s:alignLinesCR(bufnr, s:getprelinesep())
        let dbiclient_lines_tmp = getbufline(bufnr, dbiclient_col_line, '$')
        call s:deletebufline(bufnr, 1, '$')
        call s:appendbufline(bufnr, '$', dbiclient_header)
        let surr='\V' .. (empty(g:dbiclient_surround) ? '"' : g:dbiclient_surround)
        let dbiclient_lines_tmp = map(dbiclient_lines_tmp, {_, line -> substitute(line, surr .. a:preCr .. '\v|\V' .. a:preCr .. surr, '', 'g')})
        if !empty(get(dbiclient_bufmap, 'maxcols', []))
            let lines = s:getalignlist2(dbiclient_lines_tmp, dbiclient_bufmap.maxcols)
        else
            let lines = s:getalignlist(dbiclient_lines_tmp)
        endif
        let headstr = get(lines, 0, '')
        if !empty(get(dbiclient_bufmap, 'maxcols', []))
            let border = join(map(dbiclient_bufmap.maxcols[:], {_, x -> repeat('-', x)}), '-+-')
        else
            let border = join(map(split(headstr, g:dbiclient_col_delimiter_align), {_, x -> repeat('-', strdisplaywidth(x))}), '+')
        endif
        if g:dbiclient_disp_headerline
            let lines[1 + remarkrow] = border 
        endif
    else
        let surr='\V'
        let dbiclient_lines_tmp = map(dbiclient_lines_tmp, {_, line -> substitute(substitute(line, surr .. a:preCr .. '\v|\V' .. a:preCr .. surr, '', 'g'), s:tab_placefolder, "\t", 'g')})
        let lines = dbiclient_lines_tmp
    endif
    call s:appendbufline(bufnr, '$', lines)
    if dbiclient_bufmap.alignFlg
    endif
    call setbufvar(bufnr, 'dbiclient_header',  dbiclient_header)
    call setbufvar(bufnr, 'dbiclient_lines',  dbiclient_lines)
    call setpos('.', save_cursor)
endfunction

function s:rpad(x, n, c) abort
    let len = a:n - strdisplaywidth(a:x)
    return a:x .. repeat(a:c, a:n - strdisplaywidth(a:x))
endfunction

def s:alignLinesCR(bufnr1: number, preCr: string)
    var cbufnr = s:bufnr('%')
    var cwid = s:getwidCurrentTab(cbufnr)
    s:gotoWin(bufnr1)
    var curpos = 1
    var save_cursor = getcurpos()
    norm gg
    var surr = '\V' .. (empty(g:dbiclient_surround) ? '"' : g:dbiclient_surround)
    var regexS = '\v(^|\t)\V' .. preCr .. surr .. '\v\zs(\_[^\t]){-}\ze\V' .. surr .. preCr .. '\v(\t|$)'
    var regexE = '\v(^|\t)\V' .. preCr .. surr .. '\v\zs(\_[^\t]){-}\V' .. surr .. preCr .. '\v\ze(\t|$)'
    var posS = [0]
    var posE = [0]
    var save_posS = []
    try
        posS = searchpos(regexS, 'c')
        save_posS = getcurpos()
        posE = searchpos(regexE, 'ce')
    catch /./
        posS = [0]
        posE = [0]
        exe '%s/' .. preCr .. '//g'
    endtry
    var flg1 = 0
    s:debugLog('alignCr:start')
    while posS[0] !=# 0
        if posS[0] !=# posE[0]
            var strS = getbufline(bufnr1, posS[0])[0]
            var strE = getbufline(bufnr1, posE[0])[0]
            if posE[0] - posS[0] > 1
                for pos in range(posS[0] + 1, posE[0] - 1)
                    strS = strS .. "<<CRLF>>" .. getbufline(bufnr1, pos)[0]
                endfor
            endif
            s:deletebufline(bufnr1, (posS[0] + 1), (posE[0]))
            s:setbufline(bufnr1, posS[0], strS .. "<<CRLF>>" .. strE)
            setpos('.', save_posS)
            searchpos('\V' .. preCr .. surr .. '\v(\_[^\t]){-}\V' .. surr .. preCr, 'e')
            flg1 = 1
        endif
        posS = searchpos(regexS, 'c')
        save_posS = getcurpos()
        posE = searchpos(regexE, 'ce')
    endwhile
    s:debugLog('alignCr:end')
    s:debugLog('alignCrReplace:start')
    if flg1 ==# 1
        s:alignLinesCRsetpos(bufnr1, curpos)
    endif
    s:debugLog('alignCrReplace:end')
    setpos('.', save_cursor)
    if cwid != -1
        win_gotoid(cwid)
        s:debugLog('win_gotoid:[' .. s:bufnr('%') .. ',' .. cwid .. ']')
    else
        s:gotoWin(cbufnr)
    endif
enddef

def s:alignLinesCRsetpos(bufnr1: number, curpos: number)
    var ret1 = []
    for colval in getbufline(bufnr1, curpos, '$')->map(((_, x) => split(x, "\t", 1)))
        var lines = []
        var emptyline = map(colval[:], ((_, x) => ''))
        add(lines, colval[:])
        var colval2 = map(colval[:], ((_, x) => split(x, '<<CRLF>>')))
        var index = filter(map(colval2[:], ((i, x) => [i, len(x)])), ((_, x) => x[1] > 1))
        var max = max(map(index[:], ((_, x) => x[1])))
        if max > 1
            extend(lines, map(range(max - 1), ((_, x) => emptyline[:])))
            for id in index
                for i in range(id[1])
                    lines[i][id[0]] = colval2[id[0]][i]
                endfor
            endfor
        endif
        add(ret1, lines)
    endfor

    s:debugLog('alignCrReplace>:start')
    var i = curpos
    for lines in ret1
        for line in lines
            s:setbufline(bufnr1, i, join(line, "\t"))
            i += 1
        endfor
    endfor
    s:debugLog('alignCrReplace>:end')
enddef

def s:alignMain(preCr: string)
    var bufnr1 = s:bufnr(get(get(getbufvar(s:bufnr('%'), 'dbiclient_bufmap', {}), 'data', {}), 'reloadBufnr', s:bufnr('%')))
    s:alignLinesCR(bufnr1, a:preCr)
    var dbiclient_bufmap = getbufvar(bufnr1, 'dbiclient_bufmap', {})
    var lines = []
    if !empty(dbiclient_bufmap) && !empty(get(dbiclient_bufmap, 'maxcols', []))
        lines = s:getalignlist2(getbufline(bufnr1, 0, '$'), dbiclient_bufmap.maxcols)
    else
        lines = s:getalignlist(getbufline(bufnr1, 0, '$'))
    endif
    var i = 1
    for line in lines
        s:setbufline(bufnr1, i, line)
        i += 1
    endfor
enddef

def s:getalignlist2(lines: list<string>, maxCols: list<number>): list<string>
    if empty(lines)
        return []
    endif
    s:debugLog('align:start')
    var colsize = len(split(lines[0], g:dbiclient_col_delimiter, 1))
    s:debugLog('align:lines ' .. len(lines))
    var lines3 = []
    lines3 = mapnew(lines, ((_, x) => mapnew(split(x, g:dbiclient_col_delimiter, 1), ((_, xx) => substitute(xx, s:tab_placefolder, "\t", 'g')))))
    s:debugLog('align:copy')
    s:debugLog('align:maxCols' .. string(maxCols))
    var lines4 = []
    lines4 = mapnew(lines3, ((_, cols) => colsize ==# len(cols) ? join(mapnew(cols, ((i, col) => col .. repeat(' ', maxCols[i] + 1 - strdisplaywidth(col)))), g:dbiclient_col_delimiter_align .. ' ') : join(cols, g:dbiclient_col_delimiter)))
    s:debugLog('align:end')
    return lines4
enddef

function s:getalignlist(lines) abort
    if empty(a:lines)
        return []
    endif
    let colsize = len(split(a:lines[0], g:dbiclient_col_delimiter, 1))
    let maxsize = 200000/colsize
    call s:debugLog('align:start:maxsize ' .. maxsize)
    let lines = a:lines[:maxsize]
    call s:debugLog('align:lines ' .. len(lines))
    let lines2 = a:lines[maxsize+1:]
    call s:debugLog('align:lines2 ' .. len(lines2))
    let lines = map(lines , {_, x -> map(split(x, g:dbiclient_col_delimiter, 1), {_, x -> substitute(x, s:tab_placefolder, "\t", 'g')})})
    call s:debugLog('align:copy')
    let linesLen = map(deepcopy(lines), {_, x -> map(x, {_, y -> strdisplaywidth(y)})})
    call s:debugLog('align:linesLen')
    let maxCols = copy(linesLen[0])
    call map(copy(linesLen), {_, cols -> map(maxCols, {i, col -> colsize ==# len(cols) && col < cols[i] ? cols[i] : col})})
    call s:debugLog('align:maxCols' .. string(maxCols))
    let lines = map(lines, {_, cols -> colsize ==# len(cols) ? join(map(cols, {i, col -> col .. repeat(' ', maxCols[i] + 1 - strdisplaywidth(col))}), g:dbiclient_col_delimiter_align .. ' ') : join(cols, g:dbiclient_col_delimiter)})
    call s:debugLog('align:end')
    return extend(lines, lines2)
endfunction

function s:selectTableOfList(schemtable, port) abort
    if s:isDisableline() || s:error2CurrentBuffer(a:port)
        return
    endif
    call s:selectTableCmn(1, a:schemtable, a:port)
endfunction

function s:selectTable(alignFlg, wordFlg, table) abort
    let port = s:getCurrentPort()
    call s:selectTableCmn(a:alignFlg, s:getTableNm(a:wordFlg, a:table), port, s:getLimitrows())
endfunction

function s:selectTableCmn(alignFlg, table, port, ...) abort
    if empty(trim(a:table))
        return
    endif
    if s:error1(a:port)
        return {}
    endif
    let limitrows = get(a:, 1, s:getLimitrows())
    let list = ['SELECT * FROM ' .. a:table]
    call s:getQueryAsync(join(list, "\n"), s:callbackstr(a:alignFlg), limitrows, {'single_table':matchstr(a:table, '\v^\s*\zs.{-}\ze\s*')}, a:port)
endfunction

function s:editHistory(str) abort
    let port = s:getPort()
    if s:isDisableline()
        return
    endif
    let bufname = bufname('%') .. '_SQL_PREVIEW'
    let bufnr = s:aboveNewBuffer(bufname )
    let list = s:getSqlHistory(a:str)
    call s:appendbufline(bufnr, '$', list)
endfunction

function s:getSqlLineDelComment(sql) abort
    call s:debugLog('getSqlLineDelComment')
    if a:sql ==# ''
        return ''
    endif
    let port = s:getCurrentPort()
    let parsedata = s:parseSQL2(a:sql)
    return parsedata.getSqlLineDelComment1(parsedata)
endfunction

function s:getSqlLine(sql) abort
    if a:sql ==# ''
        return ''
    endif
    let ret = split(a:sql, "\n")
    let ret = join(map(ret, {_, x -> substitute(x, '\v(^\s*|\s*$)', '', 'g')}))
    return ret
endfunction


function s:selectHistory(port) abort
    let port = a:port
    if get(get(s:params, port, {}), 'connect', 9) !=# 1
        return
    endif
    let matchadds=[]
    "let list = map(s:loadQueryHistoryCmd(port), {_, x -> substitute(x, '\n', ' ', 'g')})
    let list = s:loadQueryHistoryCmd(port)
    let dsnlist = []
    let list = map(list, {_, x -> matchstr(x, '\v^\zs.{-}\zeDSN:') .. matchstr(x, '\v^.{-}SQL:\zs.{-}\ze\t')})
    let list = map(list, {_, x -> substitute(x, '\V{DELIMITER_CR}', " ", 'g')})
    let bufname='DB_HISTORY_CMD'
    let bufnr = s:bufnr(bufname)
    if s:f.getwidCurrentTab(bufnr) ==# -1
        let bufnr = s:enewBuffer(bufname)
        call s:f.noreadonly(bufnr)
    else
        call s:f.noreadonly(bufnr)
        call s:deletebufline(bufnr, 1, '$')
        call setbufvar(bufnr, 'dbiclient_bufmap', {})
    endif
    if getbufvar(bufnr, '&previewwindow')
        call setbufvar(bufnr, '&previewwindow', 0)
    endif
    call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_history_PR', s:nmap_history_PR), ':<C-u>call <SID>dbhistoryRestore(<SID>loadQueryHistoryCmd(<SID>getPort())[line(".")  - len(b:dbiclient_disableline) - 1])<CR>')
    "call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_history_SQ', s:nmap_history_SQ), ':call <SID>editHistory(<SID>loadQueryHistoryCmd(<SID>getPort())[line(".")  - len(b:dbiclient_disableline) - 1])<CR>')
    call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_history_RE', s:nmap_history_RE), ':call <SID>dbhistoryCmd(<SID>getPort())<CR>')
    "call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_history_DD', s:nmap_history_DD), ':<C-u>call <SID>deleteHistory(<SID>getHistoryPathCmd(<SID>getPort()), line(".")  - len(b:dbiclient_disableline) - 1, 1)<CR>:call <SID>dbhistoryCmd(<SID>getPort())<CR>')
    call s:setallmap(bufnr)

    let dbiclient_bufmap = {}
    let dbiclient_bufmap.data = {}
    let dbiclient_bufmap.data.connInfo = s:params[port]
    let disableline = []
    let tupleList = []
    let msgList = []
    call add(msgList, [get(g:, 'dbiclient_nmap_history_PR', s:nmap_history_PR), ':PREVIEW'])
    "call add(msgList, [get(g:, 'dbiclient_nmap_history_SQ', s:nmap_history_SQ), ':SQL_PREVIEW'])
    call add(msgList, [get(g:, 'dbiclient_nmap_history_RE', s:nmap_history_RE), ':RELOAD'])
    "call add(msgList, [get(g:, 'dbiclient_nmap_history_DD', s:nmap_history_DD), ':DELETE'])
    call add(tupleList, s:Tuple('"Quick Help<nmap>', msgList))
    let maxsize = max(map(deepcopy(tupleList), {_, x -> len(x.Get1())}))
    for tuple in tupleList
        let info = tuple.Get1() .. (repeat(' ', maxsize - len(tuple.Get1())) .. ' :')
        let info ..= s:f2.Foldl({x, y -> x .. y}, "", map(tuple.Get2(), {_, val -> ' [' .. val[0] .. val[1] .. ']'}))
        call s:appendbufline(bufnr, '$', [info])
        call add(disableline, line('$'))
    endfor
    call add(matchadds, ['Comment', '\v%1l^".{-}:'])
    call add(matchadds, ['String', '\v%1l^".{-}:\zs.*$'])
    call add(matchadds, ['Function', '\v%1l( \[)@<=.{-}(\:)@='])
    for [dsn, schema] in dsnlist
        if !empty(trim(dsn))
            call add(matchadds, ['Type', '\V' .. dsn])
        endif
        if !empty(trim(schema))
            call add(matchadds, ['String', '\V' .. schema])
        endif
    endfor
    call s:appendbufline(bufnr, '$', list)
    call setbufvar(bufnr, 'dbiclient_matches', matchadds)
    call setbufvar(bufnr, 'dbiclient_bufmap', dbiclient_bufmap)
    call setbufvar(bufnr, 'dbiclient_disableline', disableline)
    call s:sethl(bufnr)
    norm G
    call s:f.readonly(bufnr)
endfunction

function s:parseSQL(sql, cols) abort
    call s:debugLog('parseSQL')
    let data = s:parseSQL2(a:sql)
    let parseSQL={}
    let parseSQL.select=data.getMaintype(data, 'SELECT')
    let parseSQL.table=s:getTableName(a:sql, '')
    let parseSQL.from=data.getMaintype(data, 'FROM')
    let parseSQL.ijoin=data.getMaintype(data, 'JOIN')
    let parseSQL.where=data.getMaintype(data, 'WHERE')
    let parseSQL.group=data.getMaintype(data, 'GROUP')
    let parseSQL.order=data.getMaintype(data, 'ORDER')
    let parseSQL.having=data.getMaintype(data, 'HAVING')
    if len(data.getNotMaintype(data, '\v\c<(nop|select|from|join|where|group|order|having)>')) > 0
        return {}
    endif
    "call s:debugLog(string(parseSQL))
    return parseSQL
endfunction

def s:lex(sql: string): list<string>
    var tokenList = []
    var sqllist = split(sql, "\n")
    var i = 1
    for sql2 in sqllist
        var start = 0
        var regex  = '\v^\_s+|'
        regex ..= '\v^[qQ]''[<{(\[]\_.{-}[>})\]]''|'
        regex ..= '\v^[qQ]''(.)\_.{-}\1''|'
        regex ..= '\v^\/\*\_.{-}\*\/|'
        regex ..= '\v^%(--|#).{-}\ze%(\r\n|\r|\n|$)|'
        regex ..= '\v^''%(''''|[^'']|%(\r\n|\r|\n))*''|'
        regex ..= '\v^"%(""|[^"]|%(\r\n|\r|\n))*"|'
        regex ..= '\v^`%(``|[`"]|%(\r\n|\r|\n))*`|'
        regex ..= '\v^%([^[:punct:][:space:]]|[_$])+|'
        regex ..= '\v^[[:punct:]]\ze'
        var msp = []
        while start > -1
            msp = matchstrpos(sql2, regex, start)
            add(tokenList, msp[0])
            start = msp[2]
        endwhile
        if i != len(sqllist)
            add(tokenList, "\n")
        endif
        i += 1
    endfor
    return filter(tokenList, ((_, x) => x !~ '^$'))
enddef

def s:resolveToken(token: string): string
    var patternList = [['WHITESPACE',   '\v^\s+$'],
                 ['SINGLE-QUOTE', '\v^'''],
                 ['Q-QUOTE',      '\v^[qQ]'''],
                 ['DOUBLE-QUOTE', '\v^"'],
                 ['BACK-QUOTE',   '\v^\`'],
                 ['COMMENT',      '\v^(--|#|\/\*)'],
                 ['SEMICOLON',    '^\V' .. g:dbiclient_sql_delimiter1],
                 ['SLASH',        '^\V' .. g:dbiclient_sql_delimiter2],
                 ['CR',           '\v^\n'],
                 ['LO',           '\v^<and>|<or>|<in>|<between>|<is>|<not>'],
                 ['RW',           '\v^<null>|<as>|<by>|<into>|<on>'],
                 ['CLAUSE',       '\v^(<minus>|<except>|<union>|<fetch>|<offset>|<with>|<select>|<from>|<where>|<order>|<group>|<having>)$'],
                 ['JOIN',         '\v^(<join>|<outer>|<left>|<inner>|<right>|<cross>|<natural>|<full>)$'],
                 ['DOT',          '^\V.'],
                 ['COMMA',        '^\V,'],
                 ['AT',           '^\V@'],
                 ['EQ',           '^\V='],
                 ['LT',           '^\V<'],
                 ['GT',           '^\V>'],
                 ['LE',           '^\V<='],
                 ['GE',           '^\V>='],
                 ['NE',           '^\V<>'],
                 ['NE',           '^\V!='],
                 ['AMP',          '^\V&'],
                 ['BRACKET',      '^\V['],
                 ['BRACKET',      '^\V]'],
                 ['ASTER',        '^\V*'],
                 ['PARENTHESES',  '^\V('],
                 ['PARENTHESES',  '^\V)']]

    #for pattern in patternList
    #    if a:token =~? pattern[1]
    #        return pattern[0]
    #    endif
    #endfor
    #return 'TOKEN'
    var pattern = filter(patternList, (_, x) => token =~? x[1])
    return get(get(pattern, 0, []), 0, 'TOKEN')
enddef

def s:parseSQL2(sql1: string): dict<any>
    var dic = {}
    s:debugLog('sql:' .. sql1[0 : 100])
    s:debugLog('sha256 start')
    var hash = sha256(sql1)
    s:debugLog('sha256 end(' .. hash .. ')')
    var data = get(s:hardparseDict, hash, [])
    if empty(data)
        s:debugLog('lex start')
        var tokens = s:lex(sql1)
        s:debugLog('lex end')
        s:debugLog('parse start')
        s:debugLog('resolve start')
        var tokens2 = map(tokens[:], ((_, x: string) => [s:resolveToken(x), x]))
        s:debugLog('resolve end')
        data = s:parseSqlLogicR(tokens2, 0, 0)
        s:debugLog('parse end')
        s:hardparseDict[hash] = data
    endif
    dic.data = data

    def GetNotMaintype(data2: any, mtype: any): list<any>
        return filter(data2[:], ((_, x) => x[0] !~? mtype))
    enddef

    def GetMaintype(data2: any, mtype: any): list<any>
        return filter(data2[:], ((_, x) => x[0] =~? mtype))
    enddef

    def GetSql(data2: any): string
        return join(map(data2[:], ((_, x) => type(x[2]) ==# v:t_list ? GetSql(x[2]) : x[2])), '')
    enddef

    def GetSqlLineDelComment2(data2: any): string
        return join(map(filter(data2[:], ((_, x) => x[1] != 'COMMENT')), ((_, x) => type(x[2]) ==# v:t_list ? GetSql(x[2]) : x[2])), '')
    enddef

    def SplitSql2(data2: any, delim: string): list<string>
        var type = delim ==# g:dbiclient_sql_delimiter1 ? 'SEMICOLON' : delim ==# g:dbiclient_sql_delimiter2 ? 'SLASH' : ''
        var data3 = map(data2[:], ((i, x: list<any>) => x[1] ==# type ? i : -1))
        var indexes = filter(data3[:], ((_, x) => x != -1))
        add(indexes, 0)
        var ret1 = []
        var start = 0
        for i in indexes
            var sql = GetSql(data2[start : i - 1])
            if !empty(trim(sql))
                add(ret1, sql)
            endif
            start = i + 1
        endfor
        return ret1
    enddef

    def DictGetMaintype(self: dict<any>, mtype: any): any
        return GetSqlLineDelComment2(GetMaintype(self.data, mtype))
    enddef

    def DictGetNotMaintype(self: dict<any>, mtype: any): any
        return GetSqlLineDelComment2(GetNotMaintype(self.data, mtype))
    enddef

    def DictSplitSql3(self: dict<any>, delim: string): any
        var sql = SplitSql2(self.data, delim)
        return sql
    enddef

    def DictGetSqlLineDelComment1(self: dict<any>): any
        return GetSqlLineDelComment2(self.data)
    enddef
    dic.getMaintype = DictGetMaintype
    dic.getNotMaintype = DictGetNotMaintype
    dic.splitSql3 = DictSplitSql3
    dic.getSqlLineDelComment1 = DictGetSqlLineDelComment1
    s:lastparse = dic

    return dic
enddef

def s:lenR(list: list<any>): number
    return s:f2.Foldl(((x, y) => x + y), 0, map(list[:], ((_, x) => type(x) == v:t_list && type(get(x, 1, '')) == v:t_string && get(x, 1, '') =~? '^SUBS' ? s:lenR(get(x, 2, [])) : 1)))
enddef

def s:parseSqlLogicR(tokenList: list<any>, index1: number, subflg: number): list<any>
    var data = []
    var maintype = 'NOP'
    var index = index1
    while len(tokenList) > index
        var tokenName = tokenList[index][0]
        var token = tokenList[index][1]

        if tokenName ==# 'CLAUSE'
            if maintype =~ '\v\c<select>' && token !~ '\v\c<from>'
                maintype = maintype
            else
                maintype = toupper(token)
            endif
        endif
        if tokenName ==# 'JOIN'
            maintype = 'JOIN'
        endif

        if token ==# '('
            var subdata = s:parseSqlLogicR(tokenList, index + 1, subflg + 1)
            if !empty(subdata)
                var size = s:lenR(subdata)
                insert(subdata, [maintype, tokenName, '(', index])
                add(subdata, [maintype, tokenName, ')', index + size + 1])
                add(data, [maintype, 'SUBS' .. subflg, subdata])
                index += (size + 2)
                continue
            endif
        elseif subflg && token ==# ')'
            return data
        endif

        add(data, [maintype, tokenName, token, index])
        index += 1
    endwhile
    if subflg
        return []
    endif
    return data
enddef

function s:extendquery(alignFlg, extend, reloadflg) abort
    let [select, from, ijoin, where, order, group, having] = [get(a:extend, 'select', ''), get(a:extend, 'from', ''), get(a:extend, 'ijoin', ''), get(a:extend, 'where', ''), get(a:extend, 'order', ''), get(a:extend, 'group', ''), get(a:extend, 'having', '')]
    let port = s:getPort()
    if s:error2CurrentBuffer(port)
        return
    endif
    let bufnr = s:bufnr('%')
    let dbiclient_bufmap = getbufvar(bufnr, 'dbiclient_bufmap', {})
    let limitrows = dbiclient_bufmap.data.limitrows
    let select = trim(select) ==# '' ? 'SELECT *' : select
    let sql = join(filter(split(join([select, from, ijoin, where, group, having, order], "\n"), "\n"), {_, x -> trim(x) != ''}), "\n")
    let opt = dbiclient_bufmap.opt
    let opt.extend={}
    let opt.extend.select = select
    let opt.extend.from = from
    let opt.extend.ijoin = ijoin
    let opt.extend.where = where
    let opt.extend.order = order
    let opt.extend.group = group
    let opt.extend.having = having
    let dbiclient_bufmap.data.sql = sql

    "call setbufvar(dbiclient_bufmap.data.reloadBufnr, 'dbiclient_bufmap', dbiclient_bufmap)
    call s:reload(dbiclient_bufmap.data.reloadBufnr, dbiclient_bufmap.data.sql, a:reloadflg)
endfunction

function s:editSqlDo() abort
    let port = s:getPort()
    let bufnr = s:bufnr('%')
    let dbiclient_bufmap = deepcopy(getbufvar(bufnr, 'dbiclient_bufmap', {}))
    let bufname = 'SQL_PREVIEW'
    let bufnr = s:aboveNewBuffer(bufname)
    call s:appendbufline(bufnr, '$', get(dbiclient_bufmap.data, 'doText', []))
    norm gg
endfunction

function s:editSql() abort
    let port = s:getPort()
    function! s:editSqlQuery(alignFlg) abort
        let port = s:getPort()
        if s:error2CurrentBuffer(port)
            return
        endif
        if s:isDisableline()
            return
        endif
        let sql = join(getline(0, '$'), "\n")
        let bufnr = s:bufnr('%')
        let dbiclient_bufmap = getbufvar(bufnr, 'dbiclient_bufmap', {})
        let dbiclient_bufmap.data.sql = sql
        let dbiclient_bufmap.data.single_table = ''
        let dbiclient_bufmap.opt = {}
        let limitrows = get(dbiclient_bufmap, 'limitrows', s:getLimitrows())
        "call setbufvar(dbiclient_bufmap.data.reloadBufnr, 'dbiclient_bufmap', dbiclient_bufmap)
        call s:reload(dbiclient_bufmap.data.reloadBufnr, dbiclient_bufmap.data.sql, 0)
    endfunction
    let bufname = bufname('%')
    let bufnr = s:bufnr('%')
    let dbiclient_bufmap = deepcopy(getbufvar(bufnr, 'dbiclient_bufmap', {}))
    if empty(get(dbiclient_bufmap, 'data', {}))
        return
    endif
    let bufname = bufname('%') .. '_SQL_EDIT'
    let bufnr = s:vsNewBuffer(bufname)
    call s:appendbufline(bufnr, 0, split(dbiclient_bufmap.data.sql, "\n"))
    norm gg
    call setbufvar(bufnr, 'dbiclient_bufmap', dbiclient_bufmap)
    call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_edit_SQ', s:nmap_edit_SQ), ':<C-u>call <SID>editSqlQuery(b:dbiclient_bufmap.alignFlg)<CR>')
    call s:setallmap(bufnr)
endfunction

function s:order() abort
    let port = s:getPort()
    function! s:orderQuery(alignFlg) abort
        let port = s:getPort()
        if s:error2CurrentBuffer(port)
            return
        endif
        if s:isDisableline()
            return
        endif
        let bufnr = s:bufnr('%')
        let dbiclient_bufmap = getbufvar(bufnr, 'dbiclient_bufmap', {})
        if !exists('dbiclient_bufmap.opt.extend')
            let dbiclient_bufmap.opt.extend = {}
        endif
        let selectdict = getbufvar(bufnr, 'selectdict', {})
        let selectdictAscDesc = getbufvar(bufnr, 'selectdictAscDesc', {})
        let selectUnmatchCols = getbufvar(bufnr, 'selectUnmatchCols', [])
        let selectdictstr = getbufvar(bufnr, 'selectdictstr', {})
        if empty(selectdict)
            let dbiclient_bufmap.opt.extend.order = ''
        else
            let list1 = s:selectValues(selectdict)
            let order = 'ORDER BY ' .. join(list1, ", ")
            let dbiclient_bufmap.opt.extend.order = order
        endif
        let dbiclient_bufmap.opt.order = {}
        let dbiclient_bufmap.opt.order.selectdict = selectdict
        let dbiclient_bufmap.opt.order.selectdictstr = selectdictstr
        let dbiclient_bufmap.opt.order.selectdictAscDesc = selectdictAscDesc
        let dbiclient_bufmap.opt.order.selectUnmatchCols = selectUnmatchCols
        call setbufvar(bufnr, 'dbiclient_bufmap', dbiclient_bufmap)
        let extend = dbiclient_bufmap.opt.extend
        call s:extendquery(a:alignFlg, extend, 1)
    endfunction
    let bufname = bufname('%')
    let bufnr = s:bufnr('%')
    let dbiclient_bufmap = deepcopy(getbufvar(bufnr, 'dbiclient_bufmap', {}))
    let singleTableFlg = !empty(get(get(dbiclient_bufmap, 'data', {}), 'single_table', ''))
    if !singleTableFlg
        return
    endif
    if s:error2CurrentBuffer(port)
        return
    endif
    call s:selectExtends(bufname .. '_SQL_ORDER', 1, get(dbiclient_bufmap.opt, 'order', {}))
    let bufnr = s:bufnr('%')
    call setbufvar(bufnr, 'dbiclient_bufmap', dbiclient_bufmap)
    call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_order_SQ', s:nmap_order_SQ), ':<C-u>call <SID>orderQuery(b:dbiclient_bufmap.alignFlg)<CR>')
    call s:setallmap(bufnr)
endfunction

function s:count(schemtable, port) abort
    if s:isDisableline() || s:error2CurrentBuffer(a:port)
        return
    endif
    return s:getQueryAsyncSimple('SELECT COUNT(*) FROM ' .. a:schemtable)
endfunction

function s:select() abort
    let port = s:getPort()
    function! s:selectQuery(alignFlg) abort
        let port = s:getPort()
        if s:error2CurrentBuffer(port)
            return
        endif
        if s:isDisableline()
            return
        endif
        let bufnr = s:bufnr('%')
        let dbiclient_bufmap = getbufvar(bufnr, 'dbiclient_bufmap', {})
        if !exists('dbiclient_bufmap.opt.extend')
            let dbiclient_bufmap.opt.extend = {}
        endif
        let selectdict = getbufvar(bufnr, 'selectdict', {})
        let selectdictAscDesc = getbufvar(bufnr, 'selectdictAscDesc', {})
        let selectUnmatchCols = getbufvar(bufnr, 'selectUnmatchCols', [])
        let selectdictstr = getbufvar(bufnr, 'selectdictstr', {})
        if empty(selectdict)
            let dbiclient_bufmap.opt.extend.select = ''
        else
            let list1 = s:selectValues(selectdict)
            let select = 'SELECT ' .. join(list1, ", ")
            let dbiclient_bufmap.opt.extend.select = select
        endif
        let dbiclient_bufmap.opt.select = {}
        let dbiclient_bufmap.opt.select.selectdict = selectdict
        let dbiclient_bufmap.opt.select.selectdictstr = selectdictstr
        let dbiclient_bufmap.opt.select.selectdictAscDesc = selectdictAscDesc
        let dbiclient_bufmap.opt.select.selectUnmatchCols = selectUnmatchCols
        call setbufvar(bufnr, 'dbiclient_bufmap', dbiclient_bufmap)
        let extend = dbiclient_bufmap.opt.extend
        call s:extendquery(a:alignFlg, extend, 1)
    endfunction
    let bufname = bufname('%')
    let bufnr = s:bufnr('%')
    let dbiclient_bufmap = deepcopy(getbufvar(bufnr, 'dbiclient_bufmap', {}))
    let singleTableFlg = !empty(get(get(dbiclient_bufmap, 'data', {}), 'single_table', ''))
    if !singleTableFlg
        return
    endif
    if s:error2CurrentBuffer(port)
        return
    endif
    call s:selectExtends(bufname .. '_SQL_SELECT', 0, get(dbiclient_bufmap.opt, 'select', {}))
    let bufnr = s:bufnr('%')
    call setbufvar(bufnr, 'dbiclient_bufmap', dbiclient_bufmap)
    call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_select_SQ', s:nmap_select_SQ), ':<C-u>call <SID>selectQuery(b:dbiclient_bufmap.alignFlg)<CR>')
    call s:setallmap(bufnr)
endfunction

function s:group() abort
    let port = s:getPort()
    function! s:groupQuery(alignFlg) abort
        let port = s:getPort()
        if  s:error2CurrentBuffer(port)
            return
        endif
        if s:isDisableline()
            return
        endif
        let bufnr = s:bufnr('%')
        let dbiclient_bufmap = deepcopy(getbufvar(bufnr, 'dbiclient_bufmap', {}))
        if !exists('dbiclient_bufmap.opt.extend')
            let dbiclient_bufmap.opt.extend = {}
        endif
        let selectselectUnmatchCols = []
        if exists('dbiclient_bufmap.opt.select.selectUnmatchCols')
            let selectselectUnmatchCols = dbiclient_bufmap.opt.select.selectUnmatchCols
        endif
        let selectdict = getbufvar(bufnr, 'selectdict', {})
        let selectdictAscDesc = getbufvar(bufnr, 'selectdictAscDesc', {})
        let selectUnmatchCols = getbufvar(bufnr, 'selectUnmatchCols', [])
        let selectdictstr = getbufvar(bufnr, 'selectdictstr', {})
        if empty(selectdict)
            let dbiclient_bufmap.opt.extend.group = ''
        else
            let list1 = s:selectValues(selectdict)
            let group = 'GROUP BY ' .. join(list1, ", ")
            let dbiclient_bufmap.opt.extend.group = group
            let select = 'SELECT ' .. join(extend(list1,selectselectUnmatchCols), ", ")
            let dbiclient_bufmap.opt.extend.select = select
        endif
        let dbiclient_bufmap.opt.group = {}
        let dbiclient_bufmap.opt.group.selectdict = selectdict
        let dbiclient_bufmap.opt.group.selectdictstr = selectdictstr
        let dbiclient_bufmap.opt.group.selectdictAscDesc = selectdictAscDesc
        let dbiclient_bufmap.opt.group.selectUnmatchCols = selectUnmatchCols
        call setbufvar(bufnr, 'dbiclient_bufmap', dbiclient_bufmap)
        let extend = dbiclient_bufmap.opt.extend
        call s:extendquery(a:alignFlg, extend, 1)
    endfunction
    let bufname = bufname('%')
    let bufnr = s:bufnr('%')
    let dbiclient_bufmap = deepcopy(getbufvar(bufnr, 'dbiclient_bufmap', {}))
    let singleTableFlg = !empty(get(get(dbiclient_bufmap, 'data', {}), 'single_table', ''))
    if !singleTableFlg
        return
    endif
    if s:error2CurrentBuffer(port)
        return
    endif
    call s:selectExtends(bufname .. '_SQL_GROUP', 0, get(dbiclient_bufmap.opt, 'group', {}))
    let bufnr = s:bufnr('%')
    call setbufvar(bufnr, 'dbiclient_bufmap', dbiclient_bufmap)
    call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_group_SQ', s:nmap_group_SQ), ':<C-u>call <SID>groupQuery(b:dbiclient_bufmap.alignFlg)<CR>')
    call s:setallmap(bufnr)
endfunction

function s:ijoin(prefix) abort
    let port = s:getPort()
    let s:prefix=a:prefix
    let s:asTableNm=''
    let s:tableNm=''
    function! s:selectJoinTable() abort
        let port = s:getPort()
        let bufnr = s:bufnr('%')
        let dbiclient_bufmap = getbufvar(bufnr, 'dbiclient_bufmap', {})
        let bufname = bufname('%') .. '_SQL_JOIN'
        let bufnr = s:vsNewBuffer(bufname)
        inoremap <buffer> <silent> <CR> <ESC>
        call s:appendbufline(bufnr, 0, get(s:params[port], 'table_list', []))
        norm gg
        call setbufvar(s:bufnr('%'), 'dbiclient_bufmap', dbiclient_bufmap)
    endfunction
    function! s:selectIjoin(tableNm) abort
        let s:tableNm = a:tableNm
        let s:asTableNm = s:input(a:tableNm .. ' as ', '')
        if empty(trim(s:asTableNm))
            let s:asTableNm = s:tableNm
        elseif trim(s:asTableNm) !~? '\v^[a-zA-Z0-9]+$'
            return
        endif
        let port = s:getPort()
        let bufnr = s:bufnr('%')
        let dbiclient_bufmap = getbufvar(bufnr, 'dbiclient_bufmap', {})
        let ijoin = dbiclient_bufmap.opt.ijoin[:]
        let cols = []
        let cols = map(s:getColumns(s:tableNm, port), {_, x -> s:asTableNm .. '.' .. x})
        let maxcol = max(map(cols[:], {_, x -> strdisplaywidth(x)}))
        let ijoin = extend(ijoin, map(cols[:], {_, x -> x .. repeat(' ' , maxcol - strdisplaywidth(x) +1) .. '| ='}))

        let bufname = bufname('%')
        quit
        exe 'silent! bwipeout! ' .. bufnr
        call s:gotoWin(s:bufnr(dbiclient_bufmap.data.reloadBufname))
        let bufnr = s:vsNewBuffer(bufname)
        inoremap <buffer> <silent> <CR> <ESC>
        call s:appendbufline(bufnr, 0, ijoin)
        norm gg
        call setbufvar(bufnr, 'dbiclient_bufmap', dbiclient_bufmap)
        call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_ijoin_SQ', s:nmap_ijoin_SQ), ':<C-u>call <SID>ijoinQuery(getline(0,''$''), b:dbiclient_bufmap.alignFlg)<CR>')
        call s:setallmap(bufnr)
    endfunction
    function! s:ijoinQuery(beforeIjoin, alignFlg) abort
        let port = s:getPort()
        if s:error2CurrentBuffer(port)
            return
        endif
        if s:isDisableline()
            return
        endif
        let bufnr = s:bufnr('%')
        let dbiclient_bufmap = getbufvar(bufnr, 'dbiclient_bufmap', {})
        let keys1 = map(a:beforeIjoin[:], {_, x -> matchstr(x, '\v^\zs.{-}\|\ze')})
        let keys2 = map(getline(0, '$'), {_, x -> matchstr(x, '\v^\zs.{-}\|\ze')})
        let keys1 = filter(keys1, {_, x -> trim(x) !=# ''})
        let keys2 = filter(keys2, {_, x -> trim(x) !=# ''})

        if keys1 !=# keys2
            let bufnr = s:bufnr('%')
            call s:deletebufline(bufnr, 1, '$')
            call s:appendbufline(bufnr, 0, a:beforeIjoin)
            norm gg$
            redraw
            echohl ErrorMsg
            echo 'Only the value can be edited.'
            echohl None
            return
        endif
        if !exists('dbiclient_bufmap.opt.extend')
            let dbiclient_bufmap.opt.extend = {}
        endif

        let limitrows = dbiclient_bufmap.data.limitrows
        let ijoinAnd = map(filter(getline(0, '$'), {_, x -> x !~# '\v^.{-}\|\s*\=?\s*$'}), {_, x -> substitute(x, '\v^.{-}\zs\s+\|\s*\ze', ' ', '')})
        let ijoinStr = join(ijoinAnd, "\nAND ")
        if trim(ijoinStr) !=# ''
            if s:asTableNm ==# s:tableNm
                let ijoin = "\n" .. s:prefix .. ' JOIN ' .. s:tableNm .. "\n" .. ' ON ' .. ijoinStr
            else
                let ijoin = "\n" .. s:prefix .. ' JOIN ' .. s:tableNm .. ' ' .. s:asTableNm .. "\n" .. ' ON ' .. ijoinStr
            endif
            let dbiclient_bufmap.opt.ijoin = a:beforeIjoin
        else
            let ijoin = ''
        endif
        let dbiclient_bufmap.opt.extend.ijoin = substitute(dbiclient_bufmap.opt.extend.ijoin, '\v[[:space:]\n]*<join>[[:space:]\n]+\V' .. s:tableNm .. '\v>[[:space:]\n]*\V' .. s:asTableNm  .. '\v[[:space:]\n]*(<on>|<using>).{-}\ze(<inner>|<left>|<right>)?[[:space:]\n]*(<outer>)?[[:space:]\n]*(<join>|$)', '', 'g')
        let dbiclient_bufmap.opt.extend.ijoin ..= ijoin
        let extend = dbiclient_bufmap.opt.extend
        call s:extendquery(a:alignFlg, extend, 1)
    endfunction
    let bufname = bufname('%')
    let bufnr = s:bufnr('%')
    let dbiclient_bufmap = deepcopy(getbufvar(bufnr, 'dbiclient_bufmap', {}))
    let singleTableFlg = !empty(get(get(dbiclient_bufmap, 'data', {}), 'single_table', ''))
    if !singleTableFlg
        return
    endif
    if s:error2CurrentBuffer(port)
        return
    endif
    call s:selectJoinTable()
    let bufnr = s:bufnr('%')
    norm gg$
    call setbufvar(bufnr, 'dbiclient_bufmap', dbiclient_bufmap)
    call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_ijoin_SQ', s:nmap_ijoin_SQ), ':<C-u>call <SID>selectIjoin(getline("."))<CR>')
    call s:setallmap(bufnr)
endfunction

function s:where() abort
    let port = s:getPort()
    function! s:selectWhere() abort
        let bufnr = s:bufnr('%')
        let dbiclient_bufmap = getbufvar(bufnr, 'dbiclient_bufmap', {})
        let where = dbiclient_bufmap.opt.where
        let bufname = bufname('%') .. '_SQL_WHERE'
        let bufnr = s:vsNewBuffer(bufname)
        inoremap <buffer> <silent> <CR> <ESC>
        call s:appendbufline(bufnr, 0, where)
    endfunction
    function! s:whereQuery(alignFlg) abort
        let port = s:getPort()
        if s:error2CurrentBuffer(port)
            return
        endif
        if s:isDisableline()
            return
        endif
        let bufnr = s:bufnr('%')
        let dbiclient_bufmap = getbufvar(bufnr, 'dbiclient_bufmap', {})
        let keys1 = map(dbiclient_bufmap.opt.where[:], {_, x -> matchstr(x, '\v^\zs.{-}\|\ze')})
        let keys2 = map(getline(0, '$'), {_, x -> matchstr(x, '\v^\zs.{-}\|\ze')})
        let keys1 = filter(keys1, {_, x -> trim(x) !=# ''})
        let keys2 = filter(keys2, {_, x -> trim(x) !=# ''})

        if keys1 !=# keys2
            let bufnr = s:bufnr('%')
            call s:deletebufline(bufnr, 1, '$')
            call s:appendbufline(bufnr, 0, dbiclient_bufmap.opt.where)
            norm gg$
            redraw
            echohl ErrorMsg
            echo 'Only the value can be edited.'
            echohl None
            return
        endif
        if !exists('dbiclient_bufmap.opt.extend')
            let dbiclient_bufmap.opt.extend = {}
        endif
        let dbiclient_bufmap.opt.where = getline(0, '$')

        let limitrows = dbiclient_bufmap.data.limitrows
        let whereAnd = map(filter(getline(0, '$'), {_, x -> x !~# '\v^.{-}\|\s*\=?\s*$'}), {_, x -> substitute(x, '\v^.{-}\zs\s+\|\s*\ze', ' ', '')})
        let whereStr = join(whereAnd, "\nAND ")
        if trim(whereStr) !=# ''
            let where = 'WHERE ' .. whereStr
        else
            let where = ''
        endif
        let dbiclient_bufmap.opt.extend.where = where
        let extend = dbiclient_bufmap.opt.extend
        call s:extendquery(a:alignFlg, extend, 1)
    endfunction
    let bufname = bufname('%')
    let bufnr = s:bufnr('%')
    let dbiclient_bufmap = deepcopy(getbufvar(bufnr, 'dbiclient_bufmap', {}))
    let singleTableFlg = !empty(get(get(dbiclient_bufmap, 'data', {}), 'single_table', ''))
    if !singleTableFlg
        return
    endif
    if s:error2CurrentBuffer(port)
        return
    endif
    call s:selectWhere()
    let bufnr = s:bufnr('%')
    norm gg$
    call setbufvar(bufnr, 'dbiclient_bufmap', dbiclient_bufmap)
    call s:setnmap(bufnr, get(g:, 'dbiclient_nmap_where_SQ', s:nmap_where_SQ), ':<C-u>call <SID>whereQuery(b:dbiclient_bufmap.alignFlg)<CR>')
    call s:setallmap(bufnr)
endfunction

function s:dbhistoryCmd(port) abort
    let port = a:port
    if !has_key(s:params, port)
        return
    endif
    let save_cursor = getcurpos()
    call s:selectHistory(port)
    call setpos('.', save_cursor)
    return
endfunction

function s:dbhistoryRestore(str) abort
    if s:isDisableline()
        return
    endif
    "sandbox silent! let cmd = map(split(matchstr(a:str, '\v^.{-}\t\zs.*'), '{DELIMITER_CR}'), {_, x ->  eval(x)})
    "let dbiclient_bufmap = cmd[0]
    sandbox silent! let dbiclient_bufmap = eval(substitute(matchstr(a:str, '\v^.{-}\t\zs.*'), '{DELIMITER_CR}', '\r', 'g'))
    let tempfile = get(get(dbiclient_bufmap, 'data', {}), 'tempfile', '')
    "echom tempfile
    if !filereadable(tempfile)
        call s:echoMsg('EO02', tempfile)
        return
    endif
    let dbiclient_bufmap.restoreFlg = 1
    let connInfo1 = s:getconninfo(dbiclient_bufmap)
    for [port, connInfo2] in items(s:params)
        let status = s:ch_statusStrOk(s:ch_open2status(port))
        if get(connInfo1, 'hashKey', '1') ==# get(connInfo2, 'hashKey', '2') && status
            let dbiclient_bufmap.data.connInfo = connInfo2
            break
        endif
    endfor
    let dbiclient_bufmap.data.reloadBufnr = -1
    let dbiclient_bufmap.data.reloadBufname = dbiclient_bufmap.data.reloadBufname
    if s:f.getwidCurrentTab(s:bufnr(dbiclient_bufmap.data.reloadBufname)) ==# -1
        call s:f.delbuf(s:bufnr(dbiclient_bufmap.data.reloadBufname))
    endif
    if has_key(dbiclient_bufmap.data, 'sql')
        let callbackstr = get(dbiclient_bufmap.data, 'callbackstr', 's:cb_outputResultEasyAlign') 
        if has_key(dbiclient_bufmap, 'opt')
            call remove(dbiclient_bufmap, 'opt')
        endif
        call funcref(callbackstr)({}, dbiclient_bufmap)
    else
        call s:cb_do({}, dbiclient_bufmap)
    endif
    if !g:dbiclient_previewwindow
        call s:gotoWin(s:bufnr(dbiclient_bufmap.data.reloadBufname))
    endif
endfunction

function s:getSqlHistory(str) abort
    if s:isDisableline()
        return
    endif
    "sandbox silent! let cmd = map(split(matchstr(a:str, '\v.{-}\t\zs.*'), '{DELIMITER_CR}'), {_, x -> eval(x)})
    "let dbiclient_bufmap = cmd[0]
    sandbox silent! let dbiclient_bufmap = eval(substitute(matchstr(a:str, '\v^.{-}\t\zs.*'), '{DELIMITER_CR}', '\r', 'g'))
    if has_key(dbiclient_bufmap.data, 'sql')
        return split(dbiclient_bufmap.data.sql, '\v(\r\n|[\n\r])')
    else
        return get(dbiclient_bufmap.data, 'doText', [])
    endif
    return []
endfunction

function s:reload(bufnr, sql, reloadflg) abort
    let bufnr = a:bufnr
    let dbiclient_bufmap = getbufvar(bufnr, 'dbiclient_bufmap', {})
    let sql = a:sql
    if empty(sql)
        let sql = get(get(dbiclient_bufmap, 'data', {}), 'sql', '')
    endif
    if a:reloadflg == 1
        let dbiclient_bufmap.reload = 1
    endif
    call s:reloadLimit(bufnr, sql, get(get(dbiclient_bufmap, 'data', {}), 'limitrows', s:getLimitrows()))
endfunction

function s:reloadLimit(bufnr, sql, limitrows) abort
    let bufnr = a:bufnr
    let limitrows = a:limitrows
    if limitrows !~ '\v^-?[[0-9]+$'
        return
    endif
    let delbufnr = -1
    let winid = s:f.getwidCurrentTab(bufnr)
    let dbiclient_bufmap = getbufvar(bufnr, 'dbiclient_bufmap', {})
    if s:bufnr(bufnr) !=# s:bufnr('%') && winid ==# -1
        let bufnr = s:bufnr('%')
        let dbiclient_bufmap = getbufvar(bufnr, 'dbiclient_bufmap', {})
        if g:dbiclient_previewwindow
            let cwid = s:getwidCurrentTab(bufnr)
            silent! wincmd P
            silent! setlocal nopreviewwindow
            call s:debugLog('reloadLimit')
            if cwid != -1
                call win_gotoid(cwid)
                call s:debugLog('win_gotoid:[' .. s:bufnr('%') .. ',' .. cwid .. ']')
            else
                call s:gotoWin(bufnr)
            endif
            silent! setlocal previewwindow
            enew
            setlocal bufhidden=wipe
            let delbufnr = bufnr
        endif
    elseif s:bufnr(bufnr) !=# s:bufnr('%')
        let cbufnr = s:bufnr('%')
        quit
        exe 'silent! bwipeout! ' .. cbufnr
    endif

    if !empty(dbiclient_bufmap)
        let sql = a:sql
        if empty(sql)
            let sql = get(get(dbiclient_bufmap, 'data', {}), 'sql', '')
            let dbiclient_bufmap.reload = 1
        endif
        call s:reloadMain(bufnr, sql, get(dbiclient_bufmap, "alignFlg", 0), limitrows, delbufnr)
    endif
endfunction

function s:reloadMain(bufnr, sql, alignFlg, limitrows, delbufnr) abort
    let bufnr = a:bufnr
    let dbiclient_bufmap = getbufvar(bufnr, 'dbiclient_bufmap', {})
    let connInfo = s:getconninfo(dbiclient_bufmap)
    let port = get(connInfo, 'port', -1)
    if s:error2(port, bufnr)
        return
    endif
    if a:delbufnr != -1
        exe 'silent! bwipeout! ' .. a:delbufnr
    endif
    let limitrows = a:limitrows
    let sql = a:sql
    let opt = {}
    let alignFlg = a:alignFlg
    if get(dbiclient_bufmap, 'reload', 0) == 1 
        let opt.reloadBufname = dbiclient_bufmap.data.reloadBufname
        let opt.reloadBufnr = bufnr
    endif
    call s:getQueryAsync(sql, s:callbackstr(alignFlg), limitrows, opt, port)
endfunction

function s:callbackstr(alignFlg) abort
    return a:alignFlg ? 's:cb_outputResultEasyAlign' : 's:cb_outputResult'
endfunction

function s:userTablesMain(port) abort
    let port = a:port
    if !has_key(s:params, port)
        return
    endif
    if s:error1(port)
        return
    endif
    let tableNm = s:params[port].table_name
    let tabletype = s:params[port].tabletype
    call s:userTables(1, tableNm, tabletype, port)
endfunction

function s:getParams() abort
    let port = s:getPort()
    return get(s:params, port, {})
endfunction

function s:getTableNameSchem(port) abort
    if s:isDisableline()
        return ''
    endif
    let bufnr = s:bufnr('%')
    let remarkrow = getbufvar(bufnr, 'dbiclient_remarks_flg', 0)
    let dbiclient_col_line = getbufvar(bufnr, 'dbiclient_col_line', 0) - remarkrow
    let dbiclient_lines = getbufvar(bufnr, 'dbiclient_lines', 0)
    let line = line('.') - dbiclient_col_line
    let head = split(get(dbiclient_lines, 0, ''), g:dbiclient_col_delimiter, 1)
    let row = split(dbiclient_lines[line], g:dbiclient_col_delimiter, 1)
    let rowdict = s:f2.Foldl({x, y -> extend(x, y)}, {}, map(head, {i, x -> {x:row[i]}}))
    let schem = get(get(s:params, a:port, {}), 'schema_flg', 0) ? get(rowdict, 'TABLE_SCHEM', '') : ''
    let type = get(rowdict, 'TABLE_TYPE', '')
    let tableNm = get(rowdict, 'TABLE_NAME', '')
    return (empty(schem) ? '' : schem .. '.') .. (empty(tableNm) ? '' : tableNm)
endfunction

function s:userTables(alignFlg, tableNm, tabletype, port) abort
    if s:error1(a:port) || a:tableNm == v:null || a:tabletype == v:null
        return
    endif
    let tableNm = empty(a:tableNm) || a:tableNm =~? '\v^\s*$' ? '' : a:tableNm
    let tableNm = substitute(a:tableNm, "'", "", 'g')
    let tabletype = empty(a:tabletype) || a:tabletype =~? '\v^\s*$' ? '' : a:tabletype
    let tabletype = substitute(a:tabletype, "'", "", 'g')
    let s:params[a:port].tabletype = empty(tabletype) ? '' : tabletype
    let s:params[a:port].table_name = empty(tableNm) ? '' : tableNm
    let bufname = 'Tables'
    let bufnr = s:bufnr(bufname)

    if s:f.getwidCurrentTab(bufnr) ==# -1
        let bufnr = s:enewBuffer(bufname)
        call s:f.noreadonly(bufnr)
        call add(s:bufferList, bufnr)
    else
        call s:f.noreadonly(bufnr)
        call s:deletebufline(bufnr, 1, '$')
        call setbufvar(bufnr, 'dbiclient_bufmap', {})
        call setbufvar(bufnr, 'dbiclient_col_line', 0)
        call setbufvar(bufnr, 'dbiclient_header', [])
        call setbufvar(bufnr, 'dbiclient_lines', [])
        call setbufvar(bufnr, 'dbiclient_matches', [])
        call setbufvar(bufnr, 'dbiclient_nmap', [])
        call setbufvar(bufnr, 'dbiclient_vmap', [])
    endif
    if getbufvar(bufnr, '&previewwindow')
        call setbufvar(bufnr, '&previewwindow', 0)
    endif

    let opt = {
                \'noaddhistory'   : 1
                \, 'nosql'         : 1
                \, 'notablenm'     : 1
                \, 'nocols'        : 0
                \, 'table_info'    : 1
                \, 'linesep'       : ' '
                \, 'tabletype'     : tabletype
                \, 'table_name'    : tableNm
                \, 'reloadBufname' : bufname
                \, 'reloadBufnr'   : bufnr}
    call s:appendbufline(bufnr, '$', ['Now loading...'])
    "exe 'autocmd BufDelete,BufWipeout,QuitPre,BufUnload <buffer=' .. bufnr .. '> :call s:cancel(' .. a:port .. ',' .. bufnr .. ')'
    call s:f.readonly(bufnr)
    call s:gotoWin(bufnr)
    call s:getQueryAsync('', s:callbackstr(a:alignFlg), -1, opt, a:port)
endfunction

function s:getColumnsTableRemarks(data) abort
    let data = deepcopy(a:data)

    if !empty(data)
        let itemmap = s:f2.Foldl({x, y -> extend(x, y)}, {}, map(data[:], {_, x -> empty(trim(get(x, 'REMARKS', ''))) ? {} : {get(x, 'COLUMN_NAME', '') : get(x, 'REMARKS', '')}}))
        call filter(map(itemmap, {k, v -> empty(v) ? '' : v}), {_, x -> !empty(trim(x))})
    else
        let itemmap={}
    endif
    return itemmap
endfunction

function s:getColumnsPopupInfo(data) abort
    let data = deepcopy(a:data)

    if !empty(data)
        let itemmap = s:f2.Foldl({x, y -> extend(x, y)}, {}, map(data[:], {_, x -> {get(x, 'COLUMN_NAME', '') : (get(x, 'TYPE_NAME', '') .. '(' .. get(x, 'COLUMN_SIZE', '') .. (get(x, 'DECIMAL_DIGITS', v:null) == v:null ? '' : ',' .. get(x, 'DECIMAL_DIGITS', v:null))  .. ')')}}))
        call filter(map(itemmap, {k, v -> empty(v) ? '' : v}), {_, x -> !empty(trim(x))})
    else
        let itemmap={}
    endif
    return itemmap
endfunction

function s:PopupColInfo() abort
    let col = matchstr(expand('<cWORD>'), '\v(\w|[$#.])+')
    if exists('b:dbiclient_bufmap.data.columnsPopupInfo')
        let info = get(b:dbiclient_bufmap.data.columnsPopupInfo, col, '')
        if !empty(info) && line('.') == get(b:, 'dbiclient_col_line', -1)
            call popup_atcursor(info, #{moved:'any', line: 'cursor-1', col: 'cursor'})
        endif
    endif
endfunction

function s:getTableRemarks(data) abort
    let data = deepcopy(a:data)

    if !empty(data)
        let itemmap = s:f2.Foldl({x, y -> extend(x, y)}, {}, map(data[:], {_, x -> empty(trim(get(x, 'REMARKS', ''))) ? {} : {get(x, 'TABLE_NAME', '') : get(x, 'REMARKS', '')}}))
    else
        let itemmap={}
    endif
    return itemmap
endfunction

function s:selectColumnsTable(alignFlg, wordFlg, table) abort
    call s:selectColumnsTableCmn(a:alignFlg, s:getTableNm(a:wordFlg, a:table))
endfunction

function s:getTableNm(wordFlg, table) abort
    if trim(a:table) !=# ''
        let table = trim(a:table)
    else
        if a:wordFlg
            let table = matchstr(expand('<cWORD>'), '\v(\w|[$#.])+')
        else
            let table = join(s:f.getRangeCurList(getpos("'<"), getpos("'>")))
        endif
    endif
    return table
endfunction


function s:selectColumnsTableCmn(alignFlg, table, ...) abort
    let port = s:getCurrentPort()
    if empty(trim(a:table))
        return
    endif
    let table = a:table
    let ymdhms = strftime("%Y%m%d%H%M%S", localtime())
    let bufname = 'Columns_' .. s:getuser(s:params[port]) .. '_'  .. port .. '_' .. ymdhms
    let bufnr = s:bufnr(bufname)
    let opt = {
                \'noaddhistory'   : 1
                \, 'nosql'         : 1
                \, 'notablenm'     : 1
                \, 'column_info'   : 1
                \, 'tableNm'       : table
                \, 'reloadBufname' : bufname
                \, 'reloadBufnr'   : bufnr}
    call s:getQueryAsync('', s:callbackstr(a:alignFlg), -1, opt, port)
endfunction

function s:selectValues(selectdict) abort
    let bufnr = s:bufnr('%')
    let selectdictAscDesc = getbufvar(bufnr, 'selectdictAscDesc', 0)
    let list = sort(items(a:selectdict), {x, y -> x[1] ==# y[1] ? 0 : x[1] > y[1] ? 1 : -1})
    return map(map(list, {_, x->[x[1], x[0]]}), {_, x-> x[1] .. (selectdictAscDesc[x[1]] ? ' DESC' : '')})
endfunction

function s:SelectLines(orderFlg) range abort
    if s:isDisableline(a:firstline, a:lastline)
        return
    endif
    for line in range(a:firstline, a:lastline)
        if a:orderFlg
            call s:SelectLineOrder(line)
        else
            call s:SelectLine(line)
        endif
    endfor
endfunction

function s:SelectLineOrder(line) abort
    if s:isDisableline()
        return
    endif
    let bufnr = s:bufnr('%')
    let line = a:line
    let matchadds=[]
    call add(matchadds, ['Comment', '\v^(\[ASC\]|\[DESC\]).*'])
    let str = getbufline(bufnr, line)[0]
    let selectdict = getbufvar(bufnr, 'selectdict', {})
    let selectdictAscDesc = getbufvar(bufnr, 'selectdictAscDesc', {})
    let selectUnmatchCols = getbufvar(bufnr, 'selectUnmatchCols', [])
    let selectdictstr = getbufvar(bufnr, 'selectdictstr', {})
    if str !~# '\v^(\[ASC\]|\[DESC\])'
        let selectdict[str] = max(selectdict)+1
        let selectdictAscDesc[str] = 0
        let selectdictstr[str] = '[ASC]' .. selectdict[str] .. ' ' .. str
    elseif str =~? '^\[ASC\]'
        let str = substitute(str, '\v^(\[ASC\]|\[DESC\])+[0-9]+\s', '', '')
        let selectdictAscDesc[str] = 1
        let selectdictstr[str] = '[DESC]' .. selectdict[str] .. ' ' .. str
    else
        let str = substitute(str, '\v^(\[ASC\]|\[DESC\])+[0-9]+\s', '', '')
        call remove(selectdict, str)
        call remove(selectdictstr, str)
        call remove(selectdictAscDesc, str)
        let selectdict_tmp={}
        let i = 1
        for [key, val] in sort(items(selectdict), {x, y -> x[1] ==# y[1] ? 0 : x[1] > y[1] ? 1 : -1})
            let selectdict_tmp[key]=i
            let selectdictstr[key] = substitute(selectdictstr[key], '\v^(\[ASC\]|\[DESC\])+\zs[0-9]+\ze\s', i, '')
            let i+=1
        endfor
        let selectdict = selectdict_tmp
    endif
    let save_cursor = getcurpos()
    call s:f.noreadonly(bufnr)

    let lines = getbufline(bufnr, 1, '$')
    call s:deletebufline(bufnr, 1, '$')
    call s:appendbufline(bufnr, '$', map(lines, {_, x -> substitute(x, '\v^(\[ASC\]|\[DESC\])+[0-9]+\s', '', '')}))
    for [key, val] in items(selectdictstr)
        call s:setbufline(bufnr, searchpos('^\V' .. key .. '\v$', 'cn')[0], val)
    endfor
    call s:f.readonly(bufnr)
    call setbufvar(bufnr, 'dbiclient_matches', matchadds)
    call setbufvar(bufnr, 'selectdict', selectdict)
    call setbufvar(bufnr, 'selectdictstr', selectdictstr)
    call setbufvar(bufnr, 'selectdictAscDesc', selectdictAscDesc)
    call setbufvar(bufnr, 'selectUnmatchCols', selectUnmatchCols)
    call s:sethl(bufnr)
    call setpos('.', save_cursor)
endfunction

function s:SelectLine(line) abort
    if s:isDisableline()
        return
    endif
    let bufnr = s:bufnr('%')
    let line = a:line
    let matchadds=[]
    call add(matchadds, ['Comment', '^[*].*'])
    let str = getbufline(bufnr, line)[0]
    let selectdict = getbufvar(bufnr, 'selectdict', {})
    let selectdictAscDesc = getbufvar(bufnr, 'selectdictAscDesc', {})
    let selectUnmatchCols = getbufvar(bufnr, 'selectUnmatchCols', [])
    let selectdictstr = getbufvar(bufnr, 'selectdictstr', {})
    if str !~# '^[*]'
        let selectdict[str] = max(selectdict)+1
        let selectdictAscDesc[str] = 0
        let selectdictstr[str] = '*' .. selectdict[str] .. ' ' .. str
    else
        let str = substitute(str, '\v^[*]+[0-9]+\s', '', '')
        call remove(selectdict, str)
        call remove(selectdictstr, str)
        call remove(selectdictAscDesc, str)
        let selectdict_tmp={}
        let i = 1
        for [key, val] in sort(items(selectdict), {x, y -> x[1] ==# y[1] ? 0 : x[1] > y[1] ? 1 : -1})
            let selectdict_tmp[key]=i
            let selectdictstr[key] = substitute(selectdictstr[key], '\v^[*]+\zs[0-9]+\ze\s', i, '')
            let i+=1
        endfor
        let selectdict = selectdict_tmp
    endif
    let save_cursor = getcurpos()
    call s:f.noreadonly(bufnr)
    let lines = getbufline(bufnr, 1, '$')
    call s:deletebufline(bufnr, 1, '$')
    call s:appendbufline(bufnr, '$', map(lines, {_, x -> substitute(x, '\v^[*]+[0-9]+\s', '', '')}))
    for [key, val] in items(selectdictstr)
        call s:setbufline(bufnr, searchpos('^\V' .. key .. '\v$', 'cn')[0], val)
    endfor
    call s:f.readonly(bufnr)
    call setbufvar(bufnr, 'dbiclient_matches', matchadds)
    call setbufvar(bufnr, 'selectdict', selectdict)
    call setbufvar(bufnr, 'selectdictstr', selectdictstr)
    call setbufvar(bufnr, 'selectdictAscDesc', selectdictAscDesc)
    call setbufvar(bufnr, 'selectUnmatchCols', selectUnmatchCols)
    call s:sethl(bufnr)
    call setpos('.', save_cursor)
endfunction

function s:selectExtends(bufname, orderflg, dict) abort
    let bufname = a:bufname
    let curbufnr = s:bufnr('%')
    let matchadds=[]
    call add(matchadds, ['Comment', '^[*].*'])
    call add(matchadds, ['Comment', '\v^(\[ASC\]|\[DESC\]).*'])
    let dbiclient_bufmap = getbufvar(curbufnr, 'dbiclient_bufmap', {})
    let opt = get(dbiclient_bufmap, 'opt', {})
    let cols = get(dbiclient_bufmap.data, 'cols', [])
    if empty(cols)
        let cols = get(dbiclient_bufmap, 'cols', [])[:]
    endif
    let cols = extend(cols[:], get(a:dict, 'selectUnmatchCols', []))
    if has_key(a:dict, 'selectdict') && !empty(keys(get(a:dict, 'selectdictstr',{})))
        let list=[]
        let keys = keys(a:dict.selectdictstr)
        for key in cols
            let keys2 = filter(keys[:], {_,x -> key =~ '\v^.{-}\.\V' .. x .. '\v$'})
            let key2 = key
            if len(keys2) == 1
                let key2 = keys2[0]
            endif
            call add(list, get(a:dict.selectdictstr, key2, key))
        endfor
    else
        let list = cols
    endif
    let bufnr = s:vsNewBuffer(bufname)
    call s:appendbufline(bufnr, 0, list)
    if a:orderflg
        call s:setnmap(bufnr, '<SPACE>', ':<C-u>call <SID>SelectLineOrder(line("."))<CR>')
        call s:setvmap(bufnr, '<SPACE>', ':call <SID>SelectLines(1)<CR>')
    else
        call s:setnmap(bufnr, '<SPACE>', ':<C-u>call <SID>SelectLine(line("."))<CR>')
        call s:setvmap(bufnr, '<SPACE>', ':call <SID>SelectLines(0)<CR>')
    endif
    call s:setallmap(bufnr)

    call s:f.readonly(bufnr)
    call setbufvar(bufnr, 'dbiclient_matches', matchadds)
    call setbufvar(bufnr, 'selectdict', get(a:dict, 'selectdict', {}))
    call setbufvar(bufnr, 'selectdictstr', get(a:dict, 'selectdictstr', {}))
    call setbufvar(bufnr, 'selectdictAscDesc', get(a:dict, 'selectdictAscDesc', {}))
    call setbufvar(bufnr, 'selectUnmatchCols', get(a:dict, 'selectUnmatchCols', []))
    call s:sethl(bufnr)
    norm gg
endfunction

function s:isDisableline(...) abort
    let bufnr = s:bufnr('%')
    let disableline = getbufvar(bufnr, 'dbiclient_disableline', [])

    for dl in disableline
        if mode() ==# 'n'
             if line('.') ==# dl
                 return 1
             endif
         elseif mode() ==# 'v' || mode() ==# 'V'
             for line in range(a:1, a:2)
                 if line ==# dl
                     return 1
                 endif
             endfor
         endif
    endfor
    return 0
endfunction

function s:deletebuflineOfFilter(bufnr, regex) abort
    for line in reverse(filter(range(1, s:endbufline(a:bufnr)), {_, line -> getbufline(a:bufnr, line)[0] =~? a:regex}))
        call deletebufline(a:bufnr, line, line)
    endfor
endfunction

function s:deletebufline(bufnr, first, last) abort
    call deletebufline(a:bufnr, a:first, a:last)
endfunction

function s:setbufline(bufnr, line, str) abort
    call setbufline(a:bufnr, a:line, a:str)
endfunction

function s:endbufline(bufnr) abort
    let winid = s:f.getwid(a:bufnr)
    return line('$', winid)
endfunction

function s:appendbufline(bufnr, line, list) abort
    let winid = s:f.getwid(a:bufnr)
    call appendbufline(a:bufnr, a:line, a:list)
    if getbufline(a:bufnr, '$')[0] ==# ''
        call s:deletebufline(a:bufnr, s:endbufline(a:bufnr), s:endbufline(a:bufnr))
    endif
    if getbufline(a:bufnr, 1)[0] ==# ''
        call s:deletebufline(a:bufnr, 1, 1)
    endif
    return
endfunction

function s:readfile(file) abort
    if filereadable(a:file)
        let lines = readfile(a:file)
    else
        let lines = []
    endif
    return lines
endfunction

function s:readfileTakeRows(file, rows) abort
    if has_key(s:history_data, a:file)
        let lines = s:history_data[a:file][:]
    else
        if filereadable(a:file)
            let lines = readfile(a:file, '', a:rows)
        else
            let lines = []
        endif
        let s:history_data[a:file] = lines[:]
    endif
    return lines
endfunction

function s:tempname() abort
    let logpath = s:getRootPath()
    let ymdhmss = strftime("%Y%m%d%H%M%S", localtime()) .. reltime()[1][-4:] .. split(reltimestr(reltime()), '\.')[1]
    let temp = s:Filepath.join(s:getRootPath(), 'data/' .. ymdhmss .. '.dat')
    if !isdirectory(fnamemodify(temp, ':p:h'))
        call mkdir(fnamemodify(temp, ':p:h'), 'p')
    endif
    return temp
endfunction

function s:getconninfo(dict) abort
    let ret = get(get(a:dict, 'data', {}), 'connInfo', {})
    return ret
endfunction

function s:getdsn(dsn) abort
    let dsn = substitute(a:dsn, '\v(\r\n|\r|\n)+', '', 'g')
    return len(dsn) > 100 ? (dsn[:100] .. '...') : dsn
endfunction

function s:getuser(connInfo) abort
    let connInfo = a:connInfo
    let ret  = get(connInfo, 'user', '')
    return empty(ret) ? 'NOUSER' : ret
endfunction

function s:getprelinesep() abort
    return g:dbiclient_prelinesep
endfunction

function s:getPort() abort
    let bufnr = s:bufnr('%')
    let dbiclient_bufmap = getbufvar(bufnr, 'dbiclient_bufmap', {})
    let connInfo = s:getconninfo(dbiclient_bufmap)
    let port = get(connInfo, 'port', s:dbi_job_port)
    return str2nr(port)
endfunction

function s:getCurrentPort() abort
    return str2nr(s:dbi_job_port)
endfunction

function s:getLimitrows() abort
    return get(s:params, 'limitrows', s:limitrows)
endfunction

function s:getLimitrowsaBuffer() abort
    let bufnr = s:bufnr('%')
    let dbiclient_bufmap = get(getbufvar(bufnr, 'dbiclient_bufmap', {}), 'data', {})
    let limitrows = get(dbiclient_bufmap, 'limitrows', '')
    return get(s:params, 'limitrows', limitrows)
endfunction

function s:enewBuffer(bufname, ...) abort
    setlocal nopreviewwindow
    let bufnr = s:f.enew(a:bufname, g:dbiclient_buffer_encoding, 1)
    call setbufvar(bufnr, '&filetype', 'dbiclient')
    return bufnr
endfunction

function s:belowNewBuffer(bufname, ...) abort
    let [bufnr, cbufnr] = s:f.newBuffer('below new', g:dbiclient_new_window_hight, a:bufname, g:dbiclient_buffer_encoding, 0)
    call setbufvar(bufnr, '&filetype', 'dbiclient')
    return bufnr
endfunction

function s:aboveNewBuffer(bufname, ...) abort
    let [bufnr, cbufnr] = s:f.newBuffer('above new', g:dbiclient_new_window_hight, a:bufname, g:dbiclient_buffer_encoding, 0)
    call setbufvar(bufnr, '&filetype', 'dbiclient')
    return bufnr
endfunction

function s:vsNewBuffer(bufname, ...) abort
    let [bufnr, cbufnr] = s:f.newBuffer('vertical new', '', a:bufname, g:dbiclient_buffer_encoding, 0)
    call setbufvar(bufnr, '&filetype', 'dbiclient')
    let cwid = s:f.getwidCurrentTab(cbufnr)
    exe 'autocmd BufDelete,BufWipeout,QuitPre,BufUnload <buffer=' .. bufnr .. '> :call win_gotoid(' .. cwid .. ')'
    return bufnr
endfunction

function s:belowPeditBuffer(bufname, ...) abort
    if g:dbiclient_previewwindow
        let pflg = 0
        let tabnr = tabpagenr()
        for wid in map(range(tabpagewinnr(tabnr,'$')),{_,x->win_getid(x+1,tabnr)})
            if getwinvar(wid, '&previewwindow')
                let pflg = 1
                break
            endif
        endfor
        if pflg
            let hight = ''
        else
            let hight = winheight(s:getwid(s:bufnr(a:bufname)))
            let hight = hight == -1 && !&previewwindow  ? g:dbiclient_new_window_hight : ''
        endif
        let [bufnr, cbufnr] = s:f.newBuffer('bo pedit', hight, a:bufname, g:dbiclient_buffer_encoding, g:dbiclient_previewwindow)
    else
        let [bufnr, cbufnr] = s:f.newBuffer('below new', g:dbiclient_new_window_hight, a:bufname, g:dbiclient_buffer_encoding, g:dbiclient_previewwindow)
    endif
    call setbufvar(bufnr, '&filetype', 'dbiclient')
    return [bufnr, cbufnr]
endfunction

function s:setnmap(bufnr, char, command) abort
    let nmap = getbufvar(a:bufnr, 'dbiclient_nmap', [])
    call add(nmap, [a:char, a:command])
    call setbufvar(a:bufnr, 'dbiclient_nmap', nmap)
endfunction

function s:setvmap(bufnr, char, command) abort
    let vmap = getbufvar(a:bufnr, 'dbiclient_vmap', [])
    call add(vmap, [a:char, a:command])
    call setbufvar(a:bufnr, 'dbiclient_vmap', vmap)
endfunction

function s:nmap(char, command) abort
    if empty(maparg(a:char, 'n', 0, 1))
        exe 'nmap <buffer> <nowait> <silent> ' .. a:char .. ' ' a:command
    endif
endfunction

function s:vmap(char, command) abort
    if empty(maparg(a:char, 'v', 0, 1))
        exe 'vmap <buffer> <nowait> <silent> ' .. a:char .. ' ' a:command
    endif
endfunction

function s:setallmap(bufnr) abort
    let cbufnr = bufnr('%')
    let cwid = s:f.getwidCurrentTab(cbufnr)
    call s:debugLog('setallmap')
    call s:gotoWin(a:bufnr)
    let nmap = getbufvar(a:bufnr, 'dbiclient_nmap', [])
    for x in nmap
        call s:nmap(x[0], x[1])
    endfor
    let vmap = getbufvar(a:bufnr, 'dbiclient_vmap', [])
    for x in vmap
        call s:vmap(x[0], x[1])
    endfor
    call s:debugLog('setallmap')
    if cwid != -1
        call win_gotoid(cwid)
        call s:debugLog('win_gotoid:[' .. s:bufnr('%') .. ',' .. cwid .. ']')
    else
        call s:gotoWin(cbufnr)
    endif
endfunction

def s:Tuple(a1: any, b1: any): dict<any>
    var ret = {}
    def DictGet1(): any
        return copy(a1)
    enddef
    def DictGet2(): any
        return copy(b1)
    enddef
    ret.Get1 = DictGet1
    ret.Get2 = DictGet2
    return ret
enddef

function s:sethl(bufnr) abort
    let bufnr = a:bufnr
    let winidList = s:f.getwidlist(bufnr)
    for winid in winidList
        let w_dbiclient_matches = getwinvar(winid, 'w_dbiclient_matches', [])
        if !empty(w_dbiclient_matches)
            silent! call map(w_dbiclient_matches, {_, x -> matchdelete(x, winid)})
            let w_dbiclient_matches = []
        endif
        call setwinvar(winid, 'w_dbiclient_matches', w_dbiclient_matches)
    endfor
    let dbiclient_matches = getbufvar(bufnr, 'dbiclient_matches', [])
    for winid in winidList
        if getwinvar(winid, '&filetype', '') ==# 'dbiclient'
            let w_dbiclient_matches = []
            for x in dbiclient_matches
                call add(w_dbiclient_matches, matchadd(x[0], x[1], 0, -1, {'window' : winid}))
            endfor
            call setwinvar(winid, 'w_dbiclient_matches', w_dbiclient_matches)
        endif
    endfor
endfunction


function s:init() abort
    if s:loaded ==# 0
        if !isdirectory(s:getRootPath())
            call mkdir(s:getRootPath())
        endif
        let path = s:Filepath.join(s:getRootPath() , 'channellog.log')
        if g:dbiclient_debugflg
        endif
        if s:getRootPath() ==# "" || !isdirectory(s:getRootPath())
            call s:echoMsg('EO11', s:getRootPath())
            return 0
        endif
        if s:getPerlmPath() ==# "" || !filereadable(s:getPerlmPath())
            call s:echoMsg('EO12', s:getPerlmPath())
            return 0
        endif
        let logpath = s:getRootPath()
        if !isdirectory(logpath)
            call mkdir(logpath)
        endif
        call s:zonbie()
    endif
    let s:loaded = 1
endfunction

function s:zonbie()
    for file in split(glob(s:Filepath.join(s:getRootPath(), '*.lock')), "\n")
        let port = fnamemodify(file, ':p:t:r')
        let channel = ch_open('localhost:' .. port)
        if s:ch_statusOk(channel)
            :sandbox let s:params[port] = eval(join(readfile(file)))
        else
            call delete(file)
        endif
        call s:ch_close(channel)
    endfor
endfunction

function s:ch_statusStrOk(str) abort
    if a:str ==# 'open' || a:str ==# 'buffered'
        return 1
    else
        return 0
    endif
endfunction

def s:ch_statusOk(channel: any): any
    var stat = ch_status(channel)
    var starttime = localtime()
    while stat ==# 'buffered' && (localtime() - starttime) < 30
        stat = ch_status(channel)
    endwhile
    if stat ==# 'buffered'
        throw 'error ch_status:buffered'
    endif
    return s:ch_statusStrOk(stat)
enddef

def s:ch_close(channel: any)
    if type(channel) ==# v:t_channel
        var stat = ch_status(channel)
        try
            if stat !=# 'closed'
                if s:ch_statusOk(channel)
                    ch_close(channel)
                endif
            endif
        catch /./
            throw 'error ch_close() ch_status:' .. stat
        endtry
    endif
enddef

function s:input(prompt, ...) abort
    let default = get(a:, 1, '')
    echom a:prompt .. default
    let str = str2list(default)
    let c = ''
    while 1
        let c = getchar()
        if c ==# '27' || c ==# '13'
            break
        elseif c ==# "\<BS>"
            if len(str) > 0
                call remove(str, -1)
            endif
        else
            call add(str, c)
        endif
        redraw
        echom a:prompt .. list2str(str)
    endwhile
    redraw
    echom a:prompt .. list2str(str)
    if c ==# '13'
        return list2str(str)
    else
        return v:null
    endif
endfunction

function s:ch_open2status(port) abort
    if len(filter(s:sendexprList[:], {_, x -> x[0] ==# a:port})) > 0
        let ret = 'open'
    else
        let ch = ch_open('localhost:' .. a:port)
        let ret = ch_status(ch)
        call s:ch_close(ch)
    endif
    return ret
endfunction

function s:getwid(bufnr)
    return s:getwidCurrentTab(a:bufnr)
endfunction

function s:gotoWin(bufnr)
    let wid = s:getwid(a:bufnr)
    call s:debugLog('gotoWin:[' .. a:bufnr .. ',' .. wid .. ']')
    if wid != -1
        call win_gotoid(wid)
        return 1
    endif
    return -1
endfunction

function s:getwidCurrentTab(bufnr)
    let tabnr = tabpagenr()
    for wid in map(range(tabpagewinnr(tabnr,'$')),{_,x->win_getid(x+1,tabnr)})
        if(s:any(map(win_findbuf(a:bufnr),{_,x->wid==x}),{x->x!=0}))
            return wid
        endif
    endfor
    return -1
endfunction

function s:gotoWinCurrentTab(bufnr)
    let wid = s:getwidCurrentTab(a:bufnr)
    call s:debugLog('gotoWinCurrentTab:[' .. a:bufnr .. ',' .. wid .. ']')
    if wid != -1
        call win_gotoid(wid)
        return 1
    endif
    return -1
endfunction

function s:any(xs, fuc)
    for x in a:xs
        if a:fuc(x)
            return 1
        endif
    endfor
    return 0
endfunction

function s:bufCopy()
    if has_key(b:,'dbiclient_bufmap') && has_key(b:dbiclient_bufmap,'data') && b:dbiclient_bufmap.data.reloadBufname =~ '^Result_' && len(win_findbuf(s:bufnr('%'))) > 1
        let lines = getline(0, '$')
        let bufDict = b:
        let winDict = w:
        let port = s:getCurrentPort()
        let ymdhmss = strftime("%Y%m%d%H%M%S", localtime()) .. reltime()[1][-4:] .. split(reltimestr(reltime()), '\.')[1]
        let bufname = 'Result_' .. s:getuser(s:params[port]) .. '_' .. port .. '_' .. ymdhmss
        let bufnr = s:enewBuffer(bufname)
        let winid = bufwinid(bufnr)
        call s:appendbufline(bufnr, 0, lines)
        for [key,val] in items(bufDict)
            if key =~ '^dbiclient_'
                call setbufvar(bufnr, key, val)
            endif
        endfor
        let b:dbiclient_bufmap.data.reloadBufname = bufname
        let b:dbiclient_bufmap.data.reloadBufnr = bufnr
        for [key,val] in items(winDict)
            if key =~ '^dbiclient_'
                call setwinvar(winid, key, val)
            endif
        endfor
        call s:setallmap(bufnr)
        call s:sethl(bufnr)
        call s:addbufferlist(port, bufnr)
        norm gg
    endif
endfunction

augroup dbiclient
    au!
    autocmd WinNew,BufEnter * :call dbiclient#sethl(bufnr('%'))
    autocmd VimLeavePre * :call dbiclient#jobStopAll()
augroup END

let &cpo = s:cpo_save
unlet s:cpo_save

" vim:fdm=marker:nowrap:ts=4:expandtab:
