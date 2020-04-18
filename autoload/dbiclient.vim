scriptencoding utf-8

if !exists('g:loaded_dbiclient')
    finish
endif

let s:cpo_save = &cpo
set cpo&vim

let s:loaded = 0
let s:sendexprList=[]
let s:bufferList=[]
let s:f = dbiclient#funclib#new()
let s:f2 = dbiclient#funclib#new2()
let s:Filepath = vital#dbiclient#new().import('System.Filepath')
let s:Stream = vital#dbiclient#new().import('Stream')
let s:dbi_job_port=-1
let s:limitrows = 1000
let s:jobs={}
let s:params={}
let s:shadowpass=''
let s:msg={
            \ 'EO01':'The specified buffer was not found.'
            \,'EO02':'The specified file($1) was not found.'
            \,'EO03':'The specified table($1) was not found.'
            \,'EO04':'A database error has occurred.($1)'
            \,'IO05':'$1'
            \,'IO07':'Please connect to the database.($1)'
            \,'IO08':'It is closed port $1.'
            \,'IO09':'$1 updated.'
            \,'EO10':'It could not the performed for multiple tables.'
            \,'EO11':'An initial error has occurred. setRootPath({rootpath}) $1'
            \,'EO12':'An initial error has occurred. setPerlmPath({perlmpath}) $1'
            \,'IO13':'Commit'
            \,'IO14':'Rollback'
            \,'IO15':'Success'
            \,'EO16':'It could not the performed for alignFlg.'
            \,'EO17':'It could not the performed for bufname.'
            \,'IO18':'Already job port on running $1.'
            \,'IO19':'Please start to the socket.pl.'
            \,'IO20':'It is running sql on server.'
            \}

let s:connect_opt_gotowinlastbuf='connect_opt_gotowinlastbuf'
let s:connect_opt_table_name='connect_opt_table_name'
let s:connect_opt_table_type='connect_opt_table_type'
let s:connect_opt_schema_flg='connect_opt_schema_flg'
let s:connect_opt_primarykeyflg='connect_opt_primarykeyflg'
let s:connect_opt_envdict='connect_opt_envdict'
let s:connect_opt_debuglog='connect_opt_debuglog'
let s:connect_opt_schema_list='connect_opt_schema_list'
let s:connect_opt_limitrows='connect_opt_limitrows'
let s:connect_opt_encoding='connect_opt_encoding'
let s:connect_opt_history_data_flg='connect_opt_history_data_flg'

let s:nmap_job_CH = '<CR>'
let s:nmap_job_ST = 'ms'
let s:nmap_job_TA = 'mt'
let s:nmap_job_HI = 'mh'

let s:nmap_result_AL = 'ma'
let s:nmap_result_ED = 'me'
let s:nmap_result_GR = 'mg'
let s:nmap_result_OR = 'mo'
let s:nmap_result_RE = 'mr'
let s:nmap_result_SE = 'ms'
let s:nmap_result_WH = 'mw'
let s:vmap_result_DE = '<C-D>'
let s:vmap_result_IN = '<C-I>'
let s:vmap_result_UP = '<C-U>'

let s:nmap_do_PR = 'me'

let s:nmap_table_SQ = '<CR>'
let s:nmap_table_CT = 'mc'
let s:nmap_table_TT = 'mt'
let s:nmap_table_TW = 'mw'

let s:nmap_history_PR = '<CR>'
let s:nmap_history_RE = 'mr'
let s:nmap_history_SQ = 'me'
let s:nmap_history_DD = 'md'

let s:nmap_edit_SQ = '<CR>'
let s:nmap_select_SQ = '<CR>'
let s:nmap_where_SQ = '<CR>'
let s:nmap_group_SQ = '<CR>'
let s:nmap_order_SQ = '<CR>'

function! dbiclient#setSecurePassword(name) abort
    return s:setSecurePassword(a:name)
endfunction

function! dbiclient#connect_secure(port,dsn,user,passwordName,...) abort
    return s:connect_secure(a:port,a:dsn,a:user,a:passwordName,get(a:,1,{}))
endfunction

function! dbiclient#connect(port,dsn,user,pass,...) abort
    return s:connect(a:port,a:dsn,a:user,a:pass,get(a:,1,{}))
endfunction

function! dbiclient#sqllog() abort
    return s:sqllog()
endfunction

function! dbiclient#joblist() abort
    return s:joblist(1)
endfunction

function! dbiclient#jobStopAll() abort
    return s:jobStopAll()
endfunction

function! dbiclient#kill_job(...) abort
    return s:kill_job(get(a:,1,s:getCurrentPort()))
endfunction

function! dbiclient#cancel(...) abort
    return s:cancel(get(a:,1,s:getCurrentPort()))
endfunction

function! dbiclient#selectRangeSQL(delim,alignFlg,...) range abort
    return s:selectRangeSQL(a:delim,a:alignFlg,get(a:,1,s:getLimitrows()))
endfunction

function! dbiclient#dBExecRangeSQLDo(delim,bang) range abort
    return s:dBExecRangeSQLDo(a:delim,a:bang)
endfunction

function! dbiclient#getQuery(sql,limitrows,opt) abort
    return s:getQuery(a:sql,a:limitrows,a:opt,s:getCurrentPort())
endfunction

function! dbiclient#getQuerySync(sql,callback,limitrows,opt) abort
    return s:getQuerySync(a:sql,a:callback,a:limitrows,a:opt,s:getCurrentPort())
endfunction

function! dbiclient#getQuerySyncSimple(sql,bufname) abort
    return s:getQuerySync(a:sql,'s:cb_outputResultEasyAlign',s:getLimitrows(),{'reloadBufname':a:bufname},s:getCurrentPort())
endfunction

function! dbiclient#getQueryAsyncSimple(sql) abort
    return s:getQueryAsyncSimple(a:sql)
endfunction

function! dbiclient#commit() abort
    return s:commit()
endfunction

function! dbiclient#rollback() abort
    return s:rollback()
endfunction

function! dbiclient#set(key,value) abort
    return s:set(a:key,a:value)
endfunction

function! dbiclient#dBCommandMain(command) abort
    return s:dBCommandMain(a:command)
endfunction

function! dbiclient#dBCommandAsync(command,callback,delim,port) abort
    return s:dBCommandAsync(a:command,a:callback,a:delim,a:port)
endfunction

function! dbiclient#alignMain(preCr) abort
    return s:alignMain(a:preCr)
endfunction

function! dbiclient#selectTable(alignFlg,wordFlg,...) abort
    let table = get(a:,1,'')
    return s:selectTable(a:alignFlg,a:wordFlg,table)
endfunction

function! dbiclient#dbhistoryAllCmd() abort
    return s:dbhistoryAllCmd()
endfunction

function! dbiclient#dbhistoryCmd() abort
    return s:dbhistoryCmd()
endfunction

function! dbiclient#reloadMain(alignFlg,...) abort
    let bufnr = s:bufnr('%')
    return s:reloadMain(bufnr,a:alignFlg,get(a:,1,s:getLimitrows()))
endfunction

function! dbiclient#selectColumnsTable(alignFlg,wordFlg,...) abort
    let table = get(a:,1,'')
    return s:selectColumnsTable(a:alignFlg,a:wordFlg,table)
endfunction

function! s:debugLog(msg) abort
    if g:dbiclient_debugflg
        let datetime = strftime("%Y/%m/%d %H:%M:%S")
        echohl WarningMsg
        echom datetime . ' ' . string(a:msg)
        echohl None
    endif
endfunction

function! s:deleteHistoryAllCmd() abort
    let sqlpath = s:getHistoryPathCmdAll()
    if !filereadable(sqlpath)
        return
    endif
    let sqllist = s:readfile(sqlpath)
    if s:loaded == 0
        let limit = g:dbiclient_hist_cnt * -1
        if len(sqllist) > limit * -1
            "call writefile(sqllist[0:limit - 1],sqlpath . '.bk','a')
            call writefile(sqllist[limit:],sqlpath)
        endif
    endif
endfunction

function! s:deleteHistoryCmd(port) abort
    let sqlpath = s:getHistoryPathCmd(a:port)
    if !filereadable(sqlpath)
        return
    endif
    let sqllist = s:readfile(sqlpath)
    let limit = g:dbiclient_hist_cnt * -1
    if len(sqllist) > limit * -1
        "call writefile(sqllist[0:limit - 1],sqlpath . '.bk','a')
        for val in sqllist[0:limit - 1]
            let cmd = map(split(matchstr(val,'\v.{-}\t\zs.*'),'{DELIMITER_CR}'),{_,x -> eval(x)})
            if filereadable(cmd.data.tempfile)
                call delete(cmd.data.tempfile)
            endif
            if filereadable(cmd.data.tempfile . 'err')
                call delete(cmd.data.tempfile . 'err')
            endif
        endfor
        call writefile(sqllist[limit:],sqlpath)
    endif
endfunction

function! s:deleteHistory(sqlpath,no,removefile) abort
    let sqlpath = a:sqlpath
    let no = a:no
    if !filereadable(sqlpath)
        return
    endif
    let sqllist = filter(s:readfile(sqlpath),{_,x -> x =~ '\v^(.{-})DSN:(.{-})SQL:'})
    sandbox silent! let cmd = eval(matchstr(sqllist[no],'\v.{-}\t\zs.*'))
    if a:removefile && type(cmd) == v:t_dict
        if filereadable(cmd.data.tempfile)
            call delete(cmd.data.tempfile)
        endif
        if filereadable(cmd.data.tempfile . 'err')
            call delete(cmd.data.tempfile . 'err')
        endif
    endif
    call remove(sqllist,no)
    call writefile(sqllist,sqlpath)
endfunction

function! s:loadQueryHistoryAllCmd() abort
    let sqlpath = s:getHistoryPathCmdAll()
    if !filereadable(sqlpath)
        return []
    endif
    let sqllist = s:readfile(sqlpath)
    let list = map(sqllist,{_,x -> substitute(x,'\V{DELIMITER_CR}',"\n",'g')})
    let list = filter(list,{_,x -> x =~ '\v^(.{-})DSN:(.{-})SQL:'})
    return list
endfunction

function! s:loadQueryHistoryCmd(port) abort
    let sqlpath = s:getHistoryPathCmd(a:port)
    if !filereadable(sqlpath)
        return []
    endif
    let sqllist = s:readfile(sqlpath)
    let list = map(sqllist,{_,x -> substitute(x,'\V{DELIMITER_CR}',"\n",'g')})
    let list = filter(list,{_,x -> x =~ '\v^(.{-})DSN:(.{-})SQL:'})
    return list
endfunction

function! s:getHistoryPathCmdAll() abort
    let sqlpath = s:Filepath.join(s:getRootPath(),"historyall_cmd")
    return sqlpath
endfunction

function! s:getHistoryPathCmd(port) abort
    let port = a:port
    let connInfo = get(s:params,port,{})
    let dsn = matchstr(get(connInfo,'dsn',''),'\v\s*\zs\w+')
    let user = s:getuser(connInfo)
    let sqlpath = s:Filepath.join(s:getRootPath(),"history_cmd_" . dsn . '_' . user)
    return sqlpath
endfunction

function! s:getRootPath() abort
    return g:dbiclient_rootPath
endfunction

function! s:getPerlmPath() abort
    return g:dbiclient_perlmPath
endfunction

function! s:sqllog() abort
    let ymd = strftime("%Y%m%d", localtime())
    let logfile= 'socket_' . ymd . '.log'
    bo new
    exe 'e ' . s:Filepath.join(s:getRootPath(),logfile)
endfunction

function! s:error1CurrentPort() abort
    let port = s:getCurrentPort()
    return s:error1(port)
endfunction

function! s:error0(port) abort
    let port = a:port

    if !has_key(s:params,port) || get(s:params[port],'connect',9) != 1
        call s:echoMsg('IO07',port)
        return 1
    endif
    return 0
endfunction

function! s:error1(port) abort
    let port = a:port

    call filter(s:sendexprList,{_,x -> s:ch_statusOk(x[1])})
    let sendexprList = filter(s:sendexprList[:],{_,x -> x[0] == port})
    if len(sendexprList) > 0
        call s:echoMsg('IO20')
        return 1
    endif
    return s:error0(port)
endfunction

function! s:error2CurrentBuffer(port) abort
    return s:error2(a:port,s:bufnr('%'))
endfunction
function! s:error2(port,bufnr) abort
    let port = a:port
    let bufnr = a:bufnr
    let connInfo = s:getconninfo(getbufvar(bufnr,'dbiclient_bufmap',{}))
    let hashKey1 = get(get(s:params,port,{}),'hashKey','1')
    let hashKey2 = get(connInfo,'hashKey','2')
    if hashKey1 != hashKey2
        call s:echoMsg('IO07',port)
        return 1
    endif
    if s:error1(port)
        return 1
    endif
    return 0
endfunction

function! s:error3(...) abort
    let port = get(a:,1,s:getCurrentPort())
    let bufnr = s:bufnr('%')
    let dbiclient_bufmap = getbufvar(bufnr,'dbiclient_bufmap',{})
    if empty(dbiclient_bufmap) || empty(get(dbiclient_bufmap,"cols",[]))
        call s:echoMsg('EO01')
        return 1
    endif
    if dbiclient_bufmap.data.tableJoinNm =~ ' '
        call s:echoMsg('EO10')
        return 1
    endif
    "if dbiclient_bufmap.alignFlg==1
    "    call s:echoMsg('EO16')
    "    return 1
    "endif
    return 0
endfunction

function! s:getTableName(sql,table) abort
    if a:table == v:null || !empty(a:table)
        return a:table
    endif
    let sql = s:getSqlLine(s:getSqlLineDelComment(a:sql))
    let table = get(s:getTableJoinList(sql),0,'')
    let table = substitute(table,'"','','g')
    if table==""
        return ''
    else
        return table
    endif
endfunction

function! s:getTableJoinList(sql) abort
    let sql = s:getSqlLine(s:getSqlLineDelComment(a:sql))
    "let table = matchstr(sql,'\v\c\s+<from>\s+\zs[^(,]{-}\ze(<where>|<inner>|<join>|<left>|<right>|<full>|<group>|<order>|[),]|$)')
    let regex = '\v\c\s+%(from|join)\s+([[:alnum:]_$#.()]+|".{-}")'
    let suba = substitute(sql,regex . '\zs','\n','g')
    let table = dbiclient#funclib#List(s:split(suba,"\n")).matchstr('\v\c\s+%(from|join)\s+\zs([[:alnum:]_$#.()]+|".{-}")\ze').value()
    let table = filter(table,{_,x -> x !~ '\v^\s*[_$#.()]+\s*$'})
    if empty(table)
        return []
    else
        return table
    endif
endfunction

function! s:getTableJoinListUniq(sql) abort
    return uniq(sort(s:getTableJoinList(a:sql)))
endfunction

function! s:getPrimaryKeys(tableNm,port) abort
    let opt={'tableNm':a:tableNm,'column_info':1}
    return get(s:getQuery('',-1,opt,a:port),'primary_key',[])
endfunction

function! s:getDefinedKeyValue(sql) abort
    let ret = {}
    let regexp='\v\c^\s*%(def|define)\s+([[:alnum:]_]+)\s*\=(.*)$'
    if a:sql =~ regexp
        let key = substitute(a:sql,regexp,'\1','')
        let val = substitute(a:sql,regexp,'\2','')
        let ret[key]=val
    endif
    return ret
endfunction

function! s:createInsertRange() range abort
    let port = s:getCurrentPort()
    function! s:createInsert(keys,vallist,tableNm) abort
        if a:tableNm==""
            return []
        endif
        let result=[]
        let cols = join(a:keys,",")
        for record in a:vallist
            let res  = "INSERT INTO "
            let res .= a:tableNm
            let res .= "("
            let res .= cols
            let res .= ")VALUES("
            let collist = s:split(record,g:dbiclient_col_delimiter)
            let collist = map(collist,{_,x -> s:trim_surround(x)})
            call add(result,res . join(map(collist,{_,xs -> "'" . substitute(xs,"'","''",'g') . "'"}),",") . ");")
        endfor
        return result
    endfunction
    if s:isDisableline(a:firstline, a:lastline)
        return
    endif
    let bufname = bufname('%') . "_ScratchCreateInsert"
    let list = getline(a:firstline, a:lastline)
    let dbiclient_bufmap = getbufvar(s:bufnr('%'),'dbiclient_bufmap',{})
    if dbiclient_bufmap.alignFlg
        let list = map(list,{_,line -> join(map(split(line,g:dbiclient_col_delimiter_align),{_,x -> trim(x)}),g:dbiclient_col_delimiter)})
    endif
    if empty(list)
        return
    endif
    let cols = dbiclient_bufmap.cols
    let tableNm = dbiclient_bufmap.data.tableNm
    let bufnr = s:bufnr(bufname)
    if s:f.getwidCurrentTab(bufnr) == -1
        let bufnr = s:newBuffer(bufname)
    endif
    call s:deletebufline(bufnr,1,'$')
    call s:appendbufline(bufnr,'$', s:createInsert(cols,list,tableNm))
endfunction

function! s:trim_surround(val) abort
    if !empty(g:dbiclient_surround)
        return substitute(substitute(a:val,'^\V' . g:dbiclient_surround, '',''),'\V' . g:dbiclient_surround . '\v$', '','')
    else
        return a:val
    endif
endfunction

function! s:createUpdateRange() range abort
    let port = s:getCurrentPort()
    function! s:createUpdate(vallist,beforevallist,tableNm,port) abort
        let keys = s:getPrimaryKeys(a:tableNm,a:port)
        if a:tableNm==""
            return []
        endif
        let result=[]
        let i=0
        for items in a:vallist
            let beforedict = dbiclient#funclib#List(a:beforevallist[i]).foldl({x -> {x[0]:substitute(x[1],"'" ,"''",'g')}},{}).value()
            let dict = dbiclient#funclib#List(items).foldl({x -> {x[0]:substitute(x[1],"'" ,"''",'g')}},{}).value()
            let res  = "UPDATE ".a:tableNm." SET "
            let collist = dbiclient#funclib#List(items)
                        \.filter({item -> item[1] != beforedict[item[0]]})
                        \.foldl({item -> item[0] . ' = ' . "'" . s:trim_surround(item[1]) . "'"},[]).value()
            if len(collist) > 0
                let res  .= join(collist, ', ')
            else
                let res  .= '<*>'
            endif
            if(len(keys)>0)
                let res .= {key->' WHERE ' . key . ' = ' . "'" . s:trim_surround(get(dict,key,'<*>')) . "'"}(keys[0])
                let res .= join(dbiclient#funclib#List(keys[1:]).foldl({key -> ' AND ' . key . ' = ' . "'" . s:trim_surround(get(dict,key,'<*>')) . "'"},[]).value())
            else
                let res .= ' WHERE <*>'
            endif
            call add(result, res . ";")
            let i += 1
        endfor
        return result
    endfunction
    if s:isDisableline(a:firstline, a:lastline)
        return
    endif
    if s:error1CurrentPort() || s:error3()
        return
    endif
    let bufname = bufname('%') . "_ScratchCreateUpdate"
    let list = getline(a:firstline, a:lastline)
    let offset = getbufvar(s:bufnr('%'),'dbiclient_col_line',0)
    let beforeList = getbufvar(s:bufnr('%'),'dbiclient_lines',{})[a:firstline - offset:a:lastline - offset]
    let dbiclient_bufmap = getbufvar(s:bufnr('%'),'dbiclient_bufmap',{})
    if dbiclient_bufmap.alignFlg
        let list = map(list,{_,line -> join(map(split(line,g:dbiclient_col_delimiter_align),{_,x -> trim(x)}),g:dbiclient_col_delimiter)})
    endif
    if empty(list)
        return
    endif
    let cols = dbiclient_bufmap.cols
    let tableNm = dbiclient_bufmap.data.tableNm
    let bufnr = s:bufnr(bufname)
    if s:f.getwidCurrentTab(bufnr) == -1
        let bufnr = s:newBuffer(bufname)
    endif
    call s:deletebufline(bufnr,1,'$')
    let param  = dbiclient#funclib#List(list).foldl({x -> s:f.zip(cols,s:split(x,g:dbiclient_col_delimiter))},[]).value()
    let param2 = dbiclient#funclib#List(beforeList).foldl({x -> s:f.zip(cols,s:split(x,g:dbiclient_col_delimiter))},[]).value()
    call s:appendbufline(bufnr,'$', s:createUpdate(param,param2,tableNm,port))
endfunction

function! s:createDeleteRange() range abort
    let port = s:getCurrentPort()
    function! s:createDelete(vallist,tableNm,port) abort
        let keys = s:getPrimaryKeys(a:tableNm,a:port)
        if a:tableNm==""
            return []
        endif
        let result=[]
        for items in a:vallist
            let dict = dbiclient#funclib#List(items).foldl({x -> {x[0]:x[1]}},{}).value()
            let res  = "DELETE FROM ".a:tableNm
            if(len(keys)>0)
                let res .= {key->' WHERE ' . key . ' = ' . "'" . s:trim_surround(get(dict,key,'<*>')) . "'"}(keys[0])
                let res .= join(dbiclient#funclib#List(keys[1:]).foldl({key -> ' AND ' . key . ' = ' . "'" . s:trim_surround(get(dict,key,'<*>')) . "'"},[]).value())
            else
                let res .= ' WHERE <*>'
            endif
            call add(result, res . ";")
        endfor
        return result
    endfunction
    if s:isDisableline(a:firstline, a:lastline)
        return
    endif
    if s:error1CurrentPort() || s:error3()
        return
    endif
    let bufname = bufname('%') . "_ScratchCreateDelete"
    let list = getline(a:firstline, a:lastline)
    let dbiclient_bufmap = getbufvar(s:bufnr('%'),'dbiclient_bufmap',{})
    if dbiclient_bufmap.alignFlg
        let list = map(list,{_,line -> join(map(split(line,g:dbiclient_col_delimiter_align),{_,x -> trim(x)}),g:dbiclient_col_delimiter)})
    endif
    if empty(list)
        return
    endif
    let cols = dbiclient_bufmap.cols
    let tableNm = dbiclient_bufmap.data.tableNm
    let bufnr = s:bufnr(bufname)
    if s:f.getwidCurrentTab(bufnr) == -1
        let bufnr = s:newBuffer(bufname)
    endif
    call s:deletebufline(bufnr,1,'$')
    let param = dbiclient#funclib#List(list).foldl({x -> s:f.zip(cols,s:split(x,g:dbiclient_col_delimiter))},[]).value()
    call s:appendbufline(bufnr,'$', s:createDelete(param,tableNm,port))
endfunction

function! s:joblist(moveFlg) abort
    let cbufnr = s:bufnr('%')
    call s:init()
    let port = s:getCurrentPort()
    call filter(s:sendexprList,{_,x -> s:ch_statusOk(x[1])})
    function! s:dbinfo(port) abort
        let port = a:port
        let msgList = []
        let connInfo = get(s:params,port,{})
        call add(msgList, ['PID', '=' . get(connInfo,'process','')])
        call add(msgList, ['SCHEMA', '=' . s:getuser(connInfo)])
        call add(msgList, ['DSN', '=' . s:getdsn(connInfo.dsn)])
        call add(msgList, ['STATUS', '=' . s:ch_open2status(port)])
        call add(msgList, ['RUNNING', '=' . join(map(filter(s:sendexprList[:],{_,x -> x[0] == port}),{_,x -> string(x[1])}),',')])
        let msg ='Info:'
        let msg .= s:f2.Foldl({x,y -> x . y},"",map(msgList,{_,val -> ' [' . val[0] .  val[1] . ']'}))
        return msg
    endfunction
    let list = map(keys(s:params),{_,x->(port == x ? '*' : '') . x . ' ' . s:dbinfo(x)})
    let bufname = 'DBIJobList'
    let bufnr = s:bufnr(bufname)
    if (a:moveFlg && s:f.getwidCurrentTab(bufnr) == -1) || (!a:moveFlg && s:f.getwid(bufnr) == -1)
        let bufnr = s:newBuffer(bufname)
        let save_cursor = getcurpos()
        call s:nmap(get(g:,'dbiclient_nmap_job_CH',s:nmap_job_CH), ':<C-u>call <SID>chgjob(matchstr(getline("."),''\v^\*?\zs\d+''),1)<CR>')
        call s:nmap(get(g:,'dbiclient_nmap_job_ST',s:nmap_job_ST), ':<C-u>call <SID>jobStopNext(matchstr(getline("."),''\v^\*?\zs\d+''))<CR>')
        call s:nmap(get(g:,'dbiclient_nmap_job_TA',s:nmap_job_TA), ':<C-u>call <SID>userTablesMain(matchstr(getline("."),''\v^\*?\zs\d+''))<CR>')
        call s:nmap(get(g:,'dbiclient_nmap_job_HI',s:nmap_job_HI), ':<C-u>call <SID>dbhistoryCmd(matchstr(getline("."),''\v^\*?\zs\d+''))<CR>')
    else
        call s:f.gotoWinCurrentTab(bufnr)
        let save_cursor = getcurpos()
        call s:f.noreadonly(bufnr)
        call s:deletebufline(bufnr,1,'$')
    endif
    "echom bufnr
    let msgList = []
    call add(msgList, [get(g:,'dbiclient_nmap_job_CH',s:nmap_job_CH), ':' . 'CHANGE'])
    call add(msgList, [get(g:,'dbiclient_nmap_job_ST',s:nmap_job_ST), ':' . 'STOP'])
    call add(msgList, [get(g:,'dbiclient_nmap_job_TA',s:nmap_job_TA), ':' . 'TABLES'])
    call add(msgList, [get(g:,'dbiclient_nmap_job_HI',s:nmap_job_HI), ':' . 'HISTORY'])
    let info ='"Quick Help<nmap> :'
    let info .= s:f2.Foldl({x,y -> x . y},"",map(msgList,{_,val -> ' [' . val[0] . val[1] . ']'}))
    call s:appendbufline(bufnr,'$',info)
    call s:appendbufline(bufnr,'$',list)
    call setpos('.', save_cursor)
    if !a:moveFlg
        call s:f.gotoWin(cbufnr)
    endif
    call s:f.readonly(bufnr)
    let matchadds=[]
    call add(matchadds,['Comment','\v^".{-}:'])
    call add(matchadds,['Identifier','^\*.*'])
    call add(matchadds,['String','\v%1l^".{-}:\zs.*$'])
    call add(matchadds,['Function','\v%1l( \[)@<=.{-}(\:)@='])
    call add(matchadds,['ErrorMsg','fail'])
    call setbufvar(bufnr,'dbiclient_matches',matchadds)
    call s:sethl(bufnr)
endfunction

function! s:updateStatus(moveFlg) abort
    let cport = s:getCurrentPort()
    for bufnr in uniq(sort(s:bufferList))
        let tupleList = getbufvar(bufnr,'dbiclient_tupleList',[])
        if bufexists(bufnr) && !empty(tupleList)
            let tuple = tupleList[0]
            let list = tuple.Get2()
            let list = filter(list[:],{_,x -> x[0] != 'STATUS'})

            let connInfo = get(get(getbufvar(bufnr,'dbiclient_bufmap',{}),'data',{}),'connInfo',{})
            if has_key(s:params,get(connInfo,'port',''))
                let status = s:ch_open2status(connInfo.port)
            else
                let status = 'closed'
            endif
            if get(connInfo,'port','') == cport && cport != -1
                call add(list,['STATUS','=' . status . '*'])
            else
                call add(list,['STATUS','=' . status])
            endif
            let tuple = s:Tuple(tuple.Get1(),list)
            let tupleList[0] = tuple
            call setbufvar(bufnr,'dbiclient_tupleList',tupleList)

            let maxsize = max(map(deepcopy(tupleList),{_,x -> len(x.Get1())}))
            let row = 1
            for tuple in tupleList
                let info = tuple.Get1() . (repeat(' ', maxsize - len(tuple.Get1())) . ' :')
                let info .= s:f2.Foldl({x,y -> x . y},"",map(tuple.Get2(),{_,val -> ' [' . val[0] . val[1] . ']'}))
                call s:setbufline(bufnr,row,info)
                let row += 1
            endfor
        endif
    endfor
    if s:f.getwid(s:bufnr('DBIJobList')) != -1
        call s:joblist(a:moveFlg)
    endif
endfunction

function! s:chgjob(port,moveFlg) abort
    let s:dbi_job_port = a:port
    call s:updateStatus(a:moveFlg)
endfunction

function! s:jobNext() abort
    let keys = sort(keys(s:params))
    let index = min(filter(keys[:],{i,p -> p == s:getCurrentPort()}))
    let port = get(keys,index + 1, get(keys,0,-1))
    if port != -1
        call s:chgjob(port,0)
    endif
endfunction

function! s:setSecurePassword(name) abort
    let shadowpath = s:Filepath.join(s:getRootPath(),'SECPASS_') . a:name
    if filereadable(shadowpath)
        call inputsave()
        if toupper(input('Confirm deletion of file<' . shadowpath . '> [(y)es,(n)o] ','')) == 'Y'
            call inputrestore()
            call delete(shadowpath)
        else
            call inputrestore()
            return
        endif
    endif
    redraw
    redrawstatus!
    keepjumps silent! exe 'e ' . shadowpath
    keepjumps X
    redrawstatus
    keepjumps let pass = inputsecret('Enter DB password:')
    keepjumps call setline(1,'shadow:' . pass)
    keepjumps silent! write
    keepjumps bwipeout!
endfunction

function! s:getUnusedPort() abort
    let port = v:null
    for p in range(49152,65535)
        if !s:ch_statusStrOk(s:ch_open2status(p))
            let port = p
            break
        endif
    endfor
    return port
endfunction

function! s:connect_secure(port,dsn,user,passwordName,opt) abort
    let pass = '' 
    let opt = a:opt
    let shadowpath = s:Filepath.join(s:getRootPath(),'SECPASS_') . a:passwordName
    if filereadable(shadowpath) 
        silent! keepjumps exe 'bo new ' . shadowpath
        let pass = matchstr(getline(1),'^shadow:\zs.*')
        keepjumps bwipeout!
        if empty(pass)
            redraw
            echohl WarningMsg
            echo 'Password is incorrect'
            echohl None
            return
        endif
        call s:connect(a:port,a:dsn,a:user,pass,opt)
    endif
endfunction

function! s:connect(port,dsn,user,pass,opt) abort
    call s:init()
    let pass = a:pass
    let opt = a:opt
    let port = a:port == v:null ? s:getUnusedPort() : a:port
    let limitrows = get(opt, s:connect_opt_limitrows, s:limitrows)
    let encoding = get(opt, s:connect_opt_encoding, 'utf8')
    let s:dbi_job_port = port
    function! s:cb_jobout(ch,dict) closure abort
        if a:dict == port
            call s:connect_base(a:dsn,a:user,pass,limitrows,encoding,opt)
        endif
    endfunction
    function! s:cb_joberr(ch,dict) closure abort
        call s:kill_job(port)
        redraw
        echohl ErrorMsg
        echom iconv(string(a:dict),get(get(s:params,port,{}),'encoding',&enc),g:dbiclient_buffer_encoding)
        echohl None
    endfunction

    if has_key(s:params,port) && get(opt,'reconnect',0) == 0
        let opt.reconnect = 1
        call s:jobStop(port)
        call s:connect(port,a:dsn,a:user,pass,opt)
        return
    endif
    if port !~ '\v^[[0-9]+$'
        throw 'port error ' . port
    endif
    if !has_key(s:params,port) && s:ch_statusStrOk(s:ch_open2status(port))
        call s:echoMsg('IO18',port)
        return
    endif
    let logpath = s:getRootPath()
    let cmdlist=['perl', s:getPerlmPath() ,port,logpath,g:dbiclient_perl_binmode,get(opt,s:connect_opt_debuglog,0)]
    call s:debugLog(join(cmdlist,' '))
    if has_key(opt,'reconnect')
        let opt.reconnect = 0
    endif
    let s:jobs[port] = job_start(cmdlist,{
                \  'err_cb':funcref('s:cb_joberr')
                \ ,'stoponexit':''
                \ ,'out_cb':funcref('s:cb_jobout')
                \ })

    let s:params[port]={}
    let s:params[port].port = port
endfunction

function! s:kill_job(port) abort
    let port = a:port
    if !has_key(s:params,port)
        return
    endif
    let channel = ch_open('localhost:' . port)
    if s:ch_statusOk(channel)
        let result = s:ch_evalexpr(channel, {"kill" : 1} , {"timeout":30000})
        let status = ch_status(channel)
        if status == 'open'
            call ch_close(channel)
        endif
    else
        "return
    endif
    if has_key(s:jobs,port)
        call remove(s:jobs,port)
    endif
    if has_key(s:params,port)
        call remove(s:params,port)
    endif
    if s:f.getwid(s:bufnr('DBIJobList')) != -1
        call s:joblist(0)
    endif
    "call s:echoMsg('IO08',port)
endfunction

function! s:jobStopAll() abort
    for [port,job] in items(s:params)
        call s:jobStop(port)
    endfor
endfunction

function! s:jobStopNext(port) abort
    let port = a:port
    let save_cursor = getcurpos()
    let cport = s:getCurrentPort()
    call s:jobStop(port)
    if port == cport
        call s:jobNext()
    else
        call s:chgjob(cport,0)
    endif
    call s:updateStatus(0)
    call setpos('.', save_cursor)
endfunction

function! s:jobStop(port) abort
    call filter(s:sendexprList,{_,x -> s:ch_statusOk(x[1])})
    if len(filter(s:sendexprList[:],{_,x -> x[0] == a:port})) > 0
        call s:echoMsg('IO05','running channel ' . string(s:sendexprList))
        return 0
        "throw 'running channel ' . string(s:sendexprList)
    endif
    let port = a:port
    if empty(s:params)
        return 0
    endif
    let s:dbi_job_port=-1
    if has_key(s:params,port)
        "if get(get(s:params,port,{}),'connect',9) == 1
        "    let c = s:dbclose(port)
        "endif
        call s:kill_job(port)
        "call job_stop(s:jobs[port])
        "while s:ch_statusStrOk(s:ch_open2status(port))
        "    sleep 100m
        "endwhile
        if has_key(s:jobs,port)
            call remove(s:jobs,port)
        endif
        if has_key(s:params,port)
            call remove(s:params,port)
        endif
        for file in split(glob(s:Filepath.join(s:getRootPath(),'*.lock')),"\n")
            let port2 = fnamemodify(file,':p:t:r')
            if port == port2
                call delete(file)
            endif
        endfor
    endif
    if s:f.getwid(s:bufnr('DBIJobList')) != -1
        call s:joblist(0)
    endif
    return 1
endfunction

function! s:cancel(port) abort
    let port = a:port
    if empty(s:params)
        return 0
    endif
    if has_key(s:jobs,port)
        echo 'CANCEL ' . port
        call job_stop(s:jobs[port], 'int')
    endif
endfunction

function! s:selectRangeSQL(delim,alignFlg,limitrows) range abort
    let port = s:getCurrentPort()
    if s:error1CurrentPort()
        return {}
    endif

    let limitrows = a:limitrows
    let list = s:f.getRangeCurList(getpos("'<"), getpos("'>"))
    if empty(list)
        return
    endif
    let i = 0
    let regexp='\v\c^\s*%(def|define)\s+([[:alnum:]_]+)\s*\=(.*)$'
    let deflist = filter(list[:], {_,x -> x =~ regexp})
    let sqllist = filter(list[:], {_,x -> x !~ regexp})
    let defineDict = s:f2.Foldl({x,y -> extend(x,y)},{},map(deflist[:],{_,x -> s:getDefinedKeyValue(x)}))
    let defineKeys = join(uniq(sort(keys(defineDict))),'|')

    let sqllist = s:splitSql(sqllist, a:delim)
    let sqllist = map(sqllist,{_,x -> substitute(x,'\v\c\&\&' . defineKeys . '\.?' ,'\=get(defineDict,matchstr(submatch(0),''\v\c\&\&\zs[[:alnum:]_]+\ze\.?''), submatch(0))','g')})
    let channellist=[]
    let cnt = 0

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
    for sql in sqllist
        "echom sql
        let channel = s:getQueryAsync(trim(sql),s:callbackstr(a:alignFlg),limitrows,{},port)
    endfor
endfunction

function! s:split(str,delim) abort
    "if a:str =~ a:delim . '$'
    return split(a:str,a:delim,'1')
    "else
    "    return split(a:str,a:delim)
    "endif
endfunction

function! s:echoMsg(id,...) abort
    let msg = get(s:msg,a:id)
    for i in range(a:0)
        let msg = substitute(msg,'\V$' . (i+1),a:000[i],'')
    endfor
    redraw
    if a:id[0:0] == 'E'
        echohl ErrorMsg
    elseif a:id[0:0] == 'I'
        echohl Normal
    else
        echohl WarningMsg
    endif
    echo msg
    echohl None
endfunction

function! s:dBExecRangeSQLDo(delim,bang) range abort
    let port = s:getCurrentPort()
    let list = s:f.getRangeCurList(getpos("'<"), getpos("'>"))
    if empty(trim(join(list)))
        return
    endif
    let regexp='\v\c^\s*%(def|define)\s+([[:alnum:]_]+)\s*\=(.*)$'
    let deflist = filter(list[:], {_,x -> x =~ regexp})
    let sqllist = filter(list[:], {_,x -> x !~ regexp})
    let defineDict = s:f2.Foldl({x,y -> extend(x,y)},{},map(deflist[:],{_,x -> s:getDefinedKeyValue(x)}))
    let defineKeys = join(uniq(sort(keys(defineDict))),'|')

    let sqllist = s:splitSql(sqllist, a:delim)
    let sqllist = map(sqllist,{_,x -> substitute(x,'\v\c\&\&' . defineKeys . '\.?' ,'\=get(defineDict,matchstr(submatch(0),''\v\c\&\&\zs[[:alnum:]_]+\ze\.?''), submatch(0))','g')})
    "echom 'test2'
    call s:dBCommandAsync({"do":sqllist,"continue":(a:bang == '!' ? 1 : 0)},'s:cb_do',a:delim,port)
endfunction

function! s:splitSql(sqllist,delim) abort
    let list = a:sqllist
    let delim = a:delim
    let list = filter(list,{_,x -> trim(x) != ''})
    let sql = join(list,"\n")
    let delsql = s:split(s:getSqlLineDelComment(sql), "\n")
    let matchlist = map(delsql[:], {_,x -> match(x, '\v' . delim . '\s*$')})
    let sql = join(map(list[:], {i,x -> matchlist[i] != -1 
                \ ? (matchlist[i] == 0 
                    \ ? '###DELEMITER###'
                    \ : x[0:matchlist[i] - 1] . '###DELEMITER###') 
                \ : x}), "\n")
    let sqllist = s:split(sql, '###DELEMITER###')
    let sqllist = filter(sqllist, {_,x -> trim(s:getSqlLineDelComment(x)) != ''})
    call s:debugLog(sqllist)
    return sqllist
endfunction

function! s:getQuerySync(sql,callback,limitrows,opt,port) abort
    let data = s:getQuery(a:sql,a:limitrows,a:opt,a:port)
    return funcref(a:callback)({},data)
endfunction

function! s:getQuery(sql,limitrows,opt,port) abort
    let port = a:port
    if s:error1(port)
        return {}
    endif
    let schemtableNm = s:getTableName(a:sql,get(a:opt,'tableNm',''))
    let tableNm = matchstr(schemtableNm,'\v^(.{-}\.)?\zs.*')
    let schem = matchstr(schemtableNm,'\v\zs^(.{-})\ze\..*')
    let tableJoinNm = join(s:getTableJoinListUniq(a:sql)," ")
    let channel = ch_open('localhost:' . port)
    if !s:ch_statusOk(channel)
        return {}
    endif
    let param = {
                \"sql"            : a:sql
                \,"tableNm"       : tableNm
                \,"schem"         : schem
                \,"tableJoinNm"   : tableJoinNm
                \,'connInfo'      : s:params[port]
                \,"limitrows"     : a:limitrows
                \,'linesep'       : get(a:opt ,'linesep' ,g:dbiclient_linesep)
                \,'surround'      : get(a:opt ,'surround' ,g:dbiclient_surround)
                \,'null'          : get(a:opt ,'null' ,g:dbiclient_null)
                \,'table_info'    : get(a:opt,'table_info',0)
                \,'column_info'   : get(a:opt,'column_info',0)
                \,'single_table'  : get(a:opt ,'single_table' ,'')
                \,'reloadBufname' : get(a:opt,'reloadBufname','')
                \,'reloadBufnr'   : get(a:opt,'reloadBufnr',-1)
                \,'tempfile'      : s:tempname()}
    let result = s:ch_evalexpr(channel, param , {"timeout":30000})
    if s:f.getwid(s:bufnr('DBIJobList')) != -1
        call s:joblist(0)
    endif
    if type(result)==v:t_dict
        if ch_status(channel) == 'open'
            call ch_close(channel)
        endif
        function result.GetData() closure abort
            if filereadable(result.data.tempfile) && has_key(result,'cols')
                let contents = filter(s:readfile(result.data.tempfile),{_,x -> x !~ '\v^\s*$'})
                let cols = result.cols
                return map(contents,{_,line -> s:f2.Foldl({x,y -> extend(x,y)},{},map(split(line,'\t',1),{i,x -> {cols[i]:x}}))})
            else
                return []
            endif
        endfunction
        return result
    else
        if ch_status(channel) == 'open'
            call ch_close(channel)
        endif
        return {}
    endif
endfunction

function! s:getQueryAsyncSimple(sql) abort
    let port = s:getCurrentPort()
    if s:error1(port)
        return {}
    endif
    return s:getQueryAsync(a:sql,'s:cb_outputResultEasyAlign',-1,{'noaddhistory':1},port)
endfunction

function! s:getQueryAsync(sql,callback,limitrows,opt,port) abort
    if s:error0(a:port)
        return {}
    endif

    let sql = a:sql
    let schemtableNm = s:getTableName(a:sql,get(a:opt,'tableNm',''))
    let tableNm = matchstr(schemtableNm,'\v^(.{-}\.)?\zs.*')
    let schem = matchstr(schemtableNm,'\v\zs^(.{-})\ze\..*')
    let tableJoinNm = join(s:getTableJoinListUniq(sql)," ")
    let channel = ch_open('localhost:' . a:port)
    if !s:ch_statusOk(channel)
        return {}
    endif
    let ymdhmss = strftime("%Y%m%d%H%M%S",localtime()) . reltime()[1][-4:] . split(reltimestr(reltime()),'\.')[1]
    let bufname = get(a:opt,'reloadBufname','Result_' . s:getuser(s:params[a:port]) . '_' . a:port . '_' . ymdhmss)
    let bufnr = s:bufnr(get(a:opt,'reloadBufnr',s:bufnr(bufname)))

    if s:f.getwid(bufnr) == -1
        let bufnr = s:peditBuffer(bufname)
        call add(s:bufferList,bufnr)
        if sql != ''
            call s:nmap(get(g:,'dbiclient_nmap_result_WH',s:nmap_result_WH),      ':<C-u>call <SID>where()<CR>')
            call s:nmap(get(g:,'dbiclient_nmap_result_RE',s:nmap_result_RE),      ':<C-u>call <SID>reload(<SID>bufnr("%"))<CR>')
            call s:nmap(get(g:,'dbiclient_nmap_result_SE',s:nmap_result_SE),      ':<C-u>call <SID>select()<CR>')
            call s:nmap(get(g:,'dbiclient_nmap_result_GR',s:nmap_result_GR),  ':<C-u>call <SID>group()<CR>')
            call s:nmap(get(g:,'dbiclient_nmap_result_OR',s:nmap_result_OR),      ':<C-u>call <SID>order()<CR>')
            call s:nmap(get(g:,'dbiclient_nmap_result_AL',s:nmap_result_AL),      ':<C-u>call <SID>align(!get(b:dbiclient_bufmap,"alignFlg",0),<SID>bufnr("%"),<SID>getprelinesep())<CR>')
            call s:nmap(get(g:,'dbiclient_nmap_result_ED',s:nmap_result_ED),      ':<C-u>call <SID>editSql()<CR>')
            call s:vmap(get(g:,'dbiclient_vmap_result_IN',s:vmap_result_IN),  ':call <SID>createInsertRange()<CR>')
            call s:vmap(get(g:,'dbiclient_vmap_result_DE',s:vmap_result_DE),  ':call <SID>createDeleteRange()<CR>')
            call s:vmap(get(g:,'dbiclient_vmap_result_UP',s:vmap_result_UP),  ':call <SID>createUpdateRange()<CR>')
        endif
    else
        call s:deletebufline(bufnr,1,'$')
        call setbufvar(bufnr,'dbiclient_bufmap',{})
        call setbufvar(bufnr,'dbiclient_col_line',0)
        call setbufvar(bufnr,'dbiclient_header',[])
        call setbufvar(bufnr,'dbiclient_lines',[])
        call setbufvar(bufnr,'dbiclient_matches',[])
    endif
    call s:appendbufline(bufnr,'$',['Now loading...'])
    call s:f.gotoWin(bufnr)
    "redraw!
    "if empty(dbiclient_bufmap)
    let param = {
                \"opt"            : a:opt
                \,"sql"           : sql
                \,"tableNm"       : tableNm
                \,"schem"         : schem
                \,"tableJoinNm"   : tableJoinNm
                \,"limitrows"     : a:limitrows
                \,'linesep'       : get(a:opt ,'linesep' ,g:dbiclient_linesep)
                \,'surround'      : get(a:opt ,'surround' ,g:dbiclient_surround)
                \,'null'          : get(a:opt ,'null' ,g:dbiclient_null)
                \,'prelinesep'    : s:getprelinesep()
                \,'table_info'    : get(a:opt ,'table_info' ,0)
                \,'column_info'   : get(a:opt ,'column_info' ,0)
                \,'table_name'    : get(a:opt ,'table_name' ,'')
                \,'tabletype'     : get(a:opt ,'tabletype' ,'')
                \,'single_table'  : get(a:opt ,'single_table' ,'')
                \,'reloadBufname' : bufname
                \,'reloadBufnr'   : bufnr
                \,'callbackstr'   : a:callback
                \,'connInfo'      : s:params[a:port]
                \,'tempfile'      : s:tempname()}
    call s:ch_sendexpr(channel, param ,{"callback": funcref(a:callback)})
    "else
    "    let data = dbiclient_bufmap.data
    "    let data.tempfile = s:tempname()
    "    let data.opt = a:opt
    "    call s:ch_sendexpr(channel, data,{"callback": funcref(a:callback)})
    "endif
    return channel
endfunction

function! s:commit() abort
    let port = s:getCurrentPort()
    call s:dBCommandAsync({"commit":"1","nodisplay":1},'s:cb_do','',port)
endfunction

function! s:rollback() abort
    let port = s:getCurrentPort()
    call s:dBCommandAsync({"rollback":"1","nodisplay":1},'s:cb_do','',port)
endfunction

function! s:set(key,value) abort
    let ret = s:dBCommandMain({'setkey':a:key,'setvalue':a:value})
    return ret
endfunction

function! s:dbclose(port) abort
    let port = a:port
    if s:error1(port)
        return {}
    endif
    let ret = s:dBCommand(port,{"close":"1"})
    let s:params[port].connect = 0
    return ret
endfunction

function! s:connect_base(dsn,user,pass,limitrows,encoding,opt) abort
    let port = s:getCurrentPort()
    let opt = a:opt
    let user = empty(a:user) ? v:null : a:user
    let dsn = substitute(a:dsn ,'\v^\s*','','')
    if has_key(s:params,port)
        let s:params[port]={}
        let s:params[port].datasource = substitute(dsn ,'\v^\s*','','')
        let s:params[port].user = user
        let s:params[port].hashKey = sha256(dsn . a:user . a:pass)
        let s:params[port].limitrows = a:limitrows
        let s:params[port].port = port
        let s:params[port].encoding = a:encoding
        let s:params[port].gotowinlastbuf = get(opt,s:connect_opt_gotowinlastbuf,0)
        let s:params[port].dsn = dsn
        let s:params[port].primarykeyflg = get(opt,s:connect_opt_primarykeyflg,1)
        let s:params[port].table_name = get(opt,s:connect_opt_table_name,'')
        let s:params[port].tabletype = get(opt,s:connect_opt_table_type,'')
        let s:params[port].schema_flg = get(opt,s:connect_opt_schema_flg,0)
        let s:params[port].schema_list = get(opt,s:connect_opt_schema_list,[])
        let s:params[port].history_data_flg = get(opt,s:connect_opt_history_data_flg,0)
        let s:params[port].envdict = get(opt,s:connect_opt_envdict,{})
        let s:params[port].process = job_info(s:jobs[port]).process
        let command = deepcopy(s:params[port])
        let command.pass = a:pass
        let ret = s:dBCommandNoChk(port,command)
        let s:params[port].connect = get(ret,'status',9)
        if s:params[port].connect == 1
            call s:joblist(1)
        elseif s:params[port].connect == 9
            echoerr ret.message
        endif
        let lockfilepath = s:Filepath.join(s:getRootPath(),port . '.lock')
        call writefile([string(s:params[port])],lockfilepath)
    else
        call s:echoMsg('IO19',port)
    endif
    call s:deleteHistoryCmd(port)
    call s:chgjob(port,0)
endfunction

function! s:dBCommandNoChk(port,command) abort
    let port = a:port
    let channel = ch_open('localhost:' . port)
    let errret = {}
    let errret.message = 'channel:' . channel
    if !s:ch_statusOk(channel)
        return errret
    endif
    let command = a:command
    let command.tempfile = s:tempname()
    let result = s:ch_evalexpr(channel, command, {"timeout":60000})
    if s:ch_statusOk(channel)
        if type(result)==v:t_dict
            if ch_status(channel) == 'open'
                call ch_close(channel)
            endif
            "let result.message = 'channel:' . channel
            return result
        else
            if ch_status(channel) == 'open'
                call ch_close(channel)
            endif
            return errret
        endif
    else
        return errret
    endif
endfunction

function! s:ch_sendexpr(handle, expr, opt) abort
    let result = ch_sendexpr(a:handle, a:expr, a:opt)
    call add(s:sendexprList,[a:expr.connInfo.port,a:handle])
    if s:f.getwid(s:bufnr('DBIJobList')) != -1
        call s:joblist(0)
    endif
    return result
endfunction

function! s:ch_evalexpr(handle, expr, opt) abort
    let result = ch_evalexpr(a:handle, a:expr, a:opt)
    return result
endfunction

function! s:dBCommand(port,command) abort
    if s:error1(a:port)
        return {}
    endif
    return s:dBCommandNoChk(a:port,a:command)
endfunction

function! s:dBCommandMain(command) abort
    let port = s:getCurrentPort()
    return s:dBCommand(port,a:command)
endfunction

function! s:dBCommandAsync(command,callback,delim,port) abort
    let port = a:port
    if s:error1(port)
        return {}
    endif
    if has_key(a:command,'do') && len(get(a:command,'do',[])) == 0
        return {}
    endif
    let hist=[]
    for sql in get(a:command,'do',[])[:]
        if trim(sql) != ''
            "let sql .= a:delim
            call add(hist,join(split(sql . a:delim,"\n"),"{DELIMITER_CR}"))
        endif
    endfor
    let channel = ch_open('localhost:' . port)
    if !s:ch_statusOk(channel)
        return {}
    endif
    let command = a:command
    let command.tempfile = s:tempname()
    let command.delimiter = a:delim
    let command.connInfo = s:params[port]
    if get(command,"nodisplay",0) != 1 
        let ymdhmss = strftime("%Y%m%d%H%M%S",localtime()) . reltime()[1][-4:] . split(reltimestr(reltime()),'\.')[1]
        let bufname='Result_' . s:getuser(s:params[a:port]) . '_' . port . '_' . ymdhmss
        let bufnr = s:bufnr(bufname)
        if s:f.getwid(bufnr) == -1
            let bufnr = s:peditBuffer(bufname)
            call add(s:bufferList,bufnr)
            call s:nmap(get(g:,'dbiclient_nmap_do_PR',s:nmap_do_PR), ':<C-u>call <SID>editSqlDo()<CR>')
        else
            call s:deletebufline(bufnr,1,'$')
            call setbufvar(bufnr,'dbiclient_bufmap',{})
            call setbufvar(bufnr,'dbiclient_col_line',0)
            call setbufvar(bufnr,'dbiclient_header',[])
            call setbufvar(bufnr,'dbiclient_lines',[])
            call setbufvar(bufnr,'dbiclient_matches',[])
        endif
        call s:appendbufline(bufnr,'$',['Now loading...'])
        call s:f.gotoWin(bufnr)
        "redraw!
        let command.reloadBufname = bufname
        let command.reloadBufnr = bufnr
    endif

    call s:ch_sendexpr(channel, command,{"callback": funcref(a:callback)})
endfunction

function! s:cb_do(ch,dict) abort
    let starttime = localtime()
    let port = get(a:dict.data.connInfo,'port')
    "echom 'test_cb_do' . port
    let connInfo = get(a:dict.data,'connInfo')
    if type(a:ch) == v:t_channel && s:ch_statusOk(a:ch)
        call ch_close(a:ch)
    endif
    let matchadds=[]
    if type(a:dict)==v:t_dict
        if has_key(a:dict,'commit')
            if get(a:dict,"status",9) == 1
                call s:echoMsg('IO13')
            endif
        elseif has_key(a:dict,'rollback')
            if get(a:dict,"status",9) == 1
                call s:echoMsg('IO14')
            endif
        else
            let ymdhms = strftime("%Y%m%d%H%M%S",localtime())
            let bufname = get(a:dict.data,'reloadBufname','')
            let bufnr = s:bufnr(get(a:dict.data,'reloadBufnr',-1))
            if get(a:dict,'restoreFlg',0) == 1
                let bufnr = s:bufnr(bufname)
                "let bufname = bufname . '_HISTORY_PREVIEW'
            endif
            if s:f.getwid(bufnr) == -1
                let bufnr = s:newBuffer(bufname)
                let a:dict.data.reloadBufnr = bufnr
                call s:nmap(get(g:,'dbiclient_nmap_do_PR',s:nmap_do_PR), ':<C-u>call <SID>editSqlDo()<CR>')
                call add(s:bufferList,bufnr)
            else
                call s:deletebufline(bufnr,1,'$')
                call setbufvar(bufnr,'dbiclient_bufmap',{})
                call setbufvar(bufnr,'dbiclient_col_line',0)
                call setbufvar(bufnr,'dbiclient_header',[])
                call setbufvar(bufnr,'dbiclient_lines',[])
                call setbufvar(bufnr,'dbiclient_matches',[])
            endif
            let status = s:getStatus(port,connInfo)
            let time = get(a:dict,'time',0)
            let tupleList = []
            let msgList = []
            call add(msgList, ['PID', '=' . get(connInfo,'process','')])
            call add(msgList, ['PORT', '=' . port])
            call add(msgList, ['SCHEMA', '=' . s:getuser(connInfo)])
            call add(msgList, ['DSN', '=' . s:getdsn(connInfo.dsn)])
            call add(msgList, ['STATUS', '=' . (connInfo.port == s:getCurrentPort() ? status . '*' : status)])
            call add(tupleList, s:Tuple('"Connection info',msgList))
            let msgList = []
            call add(msgList, ['COUNT', '=' . get(a:dict,'cnt',-1)])
            call add(msgList, ['START', '=' . get(a:dict,'startdate','')])
            call add(msgList, ['SERVER', '=' . time . 'ms'])
            call add(tupleList, s:Tuple('"Response info',msgList))
            let msgList = []
            call add(msgList, [get(g:,'dbiclient_nmap_do_PR',s:nmap_do_PR), ':' . 'SQL_PREVIEW'])
            call add(tupleList, s:Tuple('"Quick Help<nmap>',msgList))
            call setbufvar(bufnr,'dbiclient_tupleList',tupleList)
            let maxsize = max(map(deepcopy(tupleList),{_,x -> len(x.Get1())}))
            for tuple in tupleList
                let info = tuple.Get1() . (repeat(' ', maxsize - len(tuple.Get1())) . ' :')
                let info .= s:f2.Foldl({x,y -> x . y},"",map(tuple.Get2(),{_,val -> ' [' . val[0] . val[1] . ']'}))
                call s:appendbufline(bufnr,'$',[info])
            endfor
            call add(matchadds,['Comment','\v%1l^".{-}:'])
            call add(matchadds,['Comment','\v%2l^".{-}:'])
            call add(matchadds,['String','\v%1l^".{-}:\zs.*$'])
            call add(matchadds,['String','\v%2l^".{-}:\zs.*$'])
            call add(matchadds,['Function','\v%1l( \[)@<=.{-}(\=)@='])
            call add(matchadds,['Function','\v%2l( \[)@<=.{-}(\=)@='])
            call add(matchadds,['Comment','\v%3l^".{-}:'])
            call add(matchadds,['String','\v%3l^".{-}:\zs.*$'])
            call add(matchadds,['Function','\v%3l( \[)@<=.{-}(\:)@='])
            let i = 0
            let strlines = s:readfile(a:dict.data.tempfile)
            call s:appendbufline(bufnr,'$',strlines)

            if get(a:dict,"status",9) == 1
                let lines = map(s:readfile(a:dict.data.tempfile . '.err'),{_,str -> matchstr(str, '\v^.*\ze at (( at )@!.)*$')})
                call map(lines,{i,x -> iconv(x,get(connInfo,'encoding',&enc),g:dbiclient_buffer_encoding)})
                if !empty(lines)
                    call s:appendbufline(bufnr,'$',lines)
                endif
            endif
        endif
    else
        call s:echoMsg('EO04',port,'')
    endif
    if get(a:dict,"status",9) != 9 && get(a:dict,'restoreFlg',0) != 1 && !empty(get(a:dict.data, 'do',[]))
        let path = s:getHistoryPathCmd(port)
        let path2 = s:getHistoryPathCmdAll()
        let bufVals=[]
        let datetime = strftime("%Y-%m-%d %H:%M:%S ")
        let dsn = get(connInfo,'dsn','')
        let user = s:getuser(connInfo)
        let connStr = user . '@' . dsn

        let sql = s:getSqlLine(string(get(a:dict.data, 'do','')))
        let sql = (strdisplaywidth(sql) > 300 ? sql[:300] . '...' : sql) . "\t"
        let dbiclient_bufmap = a:dict
        call add(bufVals,string(dbiclient_bufmap))
        let ww=[datetime . 'DSN:' . connStr . ' SQL:' . sql . ' ' . join(bufVals,'{DELIMITER_CR}')]
        call writefile(ww,path,'a')
        call writefile(ww,path2,'a')
        if s:params[port].history_data_flg == 0 && filereadable(a:dict.data.tempfile)
            call delete(a:dict.data.tempfile)
        endif
        if s:params[port].history_data_flg == 0 && filereadable(a:dict.data.tempfile . 'err')
            call delete(a:dict.data.tempfile . 'err')
        endif
    endif
    let endttime = localtime()
    if exists('bufnr')
        let tupleList = getbufvar(bufnr,'dbiclient_tupleList',[])
        let maxsize = max(map(deepcopy(tupleList),{_,x -> len(x.Get1())}))
        let tuple = tupleList[1]
        let msgList = tuple.Get2()
        call add(msgList, ['VIM', '=' . (endttime - starttime) . 'sec'])
        let tuple = s:Tuple(tuple.Get1(),msgList)
        let tupleList[1] = tuple
        let info = tuple.Get1() . (repeat(' ', maxsize - len(tuple.Get1())) . ' :')
        let info .= s:f2.Foldl({x,y -> x . y},"",map(tuple.Get2(),{_,val -> ' [' . val[0] . val[1] . ']'}))
        call s:setbufline(bufnr,2,info)
        call setbufvar(bufnr,'dbiclient_tupleList',tupleList)
        call setbufvar(bufnr,'dbiclient_bufmap',deepcopy(a:dict))
        if !empty(matchadds)
            call setbufvar(bufnr,'dbiclient_matches',matchadds)
            call s:sethl(bufnr)
        endif
    endif
    call s:debugLog(a:dict)
    if s:f.getwid(s:bufnr('DBIJobList')) != -1
        call s:joblist(0)
    endif
endfunction

function! s:getStatus(port, connInfo) abort
    let hashKey1 = get(get(s:params,a:port,{}),'hashKey','1')
    let hashKey2 = get(a:connInfo,'hashKey','2')
    if hashKey1 == hashKey2
        let status = s:ch_open2status(a:port)
    else
        let status = 'closed'
    endif
    return status
endfunction

function! s:cb_outputResultCmn(ch,dict,bufnr) abort
    let port = get(a:dict.data.connInfo,'port')
    let connInfo = get(a:dict.data,'connInfo')
    let bufnr = a:bufnr
    if type(a:ch) == v:t_channel && s:ch_statusOk(a:ch)
        "echom 'channel:' . a:ch
        call ch_close(a:ch)
    endif

    let status = s:getStatus(port,connInfo)
    let opt = get(a:dict.data,'opt',{})
    let time = get(a:dict,'time',0)
    let tupleList = []
    let msgList = []
    call add(msgList, ['PID', '=' . get(connInfo,'process','')])
    call add(msgList, ['PORT', '=' . port])
    call add(msgList, ['SCHEMA', '=' . s:getuser(connInfo)])
    call add(msgList, ['DSN', '=' . s:getdsn(connInfo.dsn)])
    call add(msgList, ['STATUS', '=' . (connInfo.port == s:getCurrentPort() ? status . '*' : status)])
    call add(tupleList, s:Tuple('"Connection info',msgList))
    let msgList = []
    call add(msgList, ['COUNT', '=' . get(a:dict,'cnt',-1)])
    call add(msgList, ['START', '=' . get(a:dict,'startdate','')])
    call add(msgList, ['SERVER', '=' . time . 'ms'])
    call add(tupleList, s:Tuple('"Response info',msgList))
    let matchadds=[]
    call add(matchadds,['Comment','\v%1l^".{-}:'])
    call add(matchadds,['Comment','\v%2l^".{-}:'])
    call add(matchadds,['String','\v%1l^".{-}:\zs.*$'])
    call add(matchadds,['String','\v%2l^".{-}:\zs.*$'])
    call add(matchadds,['Function','\v%1l( \[)@<=.{-}(\=)@='])
    call add(matchadds,['Function','\v%2l( \[)@<=.{-}(\=)@='])
    let dbiclient_col_line = -1

    let parseSQL = s:parseSQL(a:dict.data.sql)
    let a:dict.data.single_table = get(parseSQL, 'table', '')
    if get(a:dict,"status",9) != 2
        if get(a:dict.data,'sql','') != ''
            let list1=[]
            let msgList = []
            let singleTableFlg = !empty(get(a:dict.data,'single_table',''))
            if singleTableFlg
                call add(msgList, [get(g:,'dbiclient_nmap_result_SE',s:nmap_result_SE), ':SELECT'])
                call add(msgList, [get(g:,'dbiclient_nmap_result_WH',s:nmap_result_WH), ':WHERE'])
                call add(msgList, [get(g:,'dbiclient_nmap_result_OR',s:nmap_result_OR), ':ORDER'])
                call add(msgList, [get(g:,'dbiclient_nmap_result_GR',s:nmap_result_GR), ':GROUP'])
            endif
            call add(msgList, [get(g:,'dbiclient_nmap_result_RE',s:nmap_result_RE), ':RELOAD'])
            call add(msgList, [get(g:,'dbiclient_nmap_result_AL',s:nmap_result_AL), ':ALIGN'])
            call add(msgList, [get(g:,'dbiclient_nmap_result_ED',s:nmap_result_ED), ':EDIT'])
            call add(tupleList, s:Tuple('"Quick Help<nmap>',msgList))
            call add(matchadds,['Comment','\v%3l^".{-}:'])
            call add(matchadds,['String','\v%3l^".{-}:\zs.*$'])
            call add(matchadds,['Function','\v%3l( \[)@<=.{-}(\:)@='])

            let msgList = []
            call add(msgList, [get(g:,'dbiclient_vmap_result_IN',s:vmap_result_IN), ':INSERT'])
            call add(msgList, [get(g:,'dbiclient_vmap_result_UP',s:vmap_result_UP), ':UPDATE'])
            call add(msgList, [get(g:,'dbiclient_vmap_result_DE',s:vmap_result_DE), ':DELETE'])
            call add(tupleList, s:Tuple('"Quick Help<vmap>',msgList))
            call add(matchadds,['Comment','\v%4l^".{-}:'])
            call add(matchadds,['String','\v%4l^".{-}:\zs.*$'])
            call add(matchadds,['Function','\v%4l( \[)@<=.{-}(\:)@='])
        elseif get(a:dict.data,'table_info',0) == 1
            let msgList = []
            call add(msgList, [get(g:,'dbiclient_nmap_table_SQ',s:nmap_table_SQ), ':SQL'])
            call add(msgList, [get(g:,'dbiclient_nmap_table_CT',s:nmap_table_CT), ':COUNT'])
            call add(msgList, [get(g:,'dbiclient_nmap_table_TW',s:nmap_table_TW), ':TABLE_NAME'])
            call add(msgList, [get(g:,'dbiclient_nmap_table_TT',s:nmap_table_TT), ':TABLE_TYPE'])
            call add(tupleList, s:Tuple('"Quick Help',msgList))
            call add(matchadds,['Comment','\v%3l^".{-}:'])
            call add(matchadds,['String','\v%3l^".{-}:\zs.*$'])
            call add(matchadds,['Function','\v%3l( \[)@<=.{-}(\:)@='])
        endif
    endif
    let disableline = []
    call setbufvar(bufnr,'dbiclient_tupleList',tupleList)
    let maxsize = max(map(deepcopy(tupleList),{_,x -> len(x.Get1())}))
    for tuple in tupleList
        let info = tuple.Get1() . (repeat(' ', maxsize - len(tuple.Get1())) . ' :')
        let info .= s:f2.Foldl({x,y -> x . y},"",map(tuple.Get2(),{_,val -> ' [' . val[0] . val[1] . ']'}))
        call s:appendbufline(bufnr,'$',[info])
        call add(disableline,s:endbufline(bufnr))
    endfor
    if get(a:dict,"status",9) == 1

        if get(opt,"nosql",0) == 0 && !empty(a:dict.data.sql)
            let tmp = s:getSqlLine(a:dict.data.sql)
            call s:appendbufline(bufnr,'$',[tmp])
            call add(disableline,s:endbufline(bufnr))
            call s:appendbufline(bufnr,'$',[substitute(tmp,'.','-','g')])
            call add(disableline,s:endbufline(bufnr))
        endif
        if get(opt,"notablenm",0) == 0 && !empty(a:dict.data.tableJoinNm)
            let tableRemarks=''
            if g:dbiclient_disp_remarks && a:dict.data.single_table != ''
                let table = a:dict.data.tableNm
                let tableRemarks = get(s:getTableRemarks(get(a:dict,'table_info',[])),table,'')
            endif
            if empty(tableRemarks)
                call extend(matchadds,s:appendbufline(bufnr,'$',[a:dict.data.tableJoinNm],'Identifier'))
            else
                call extend(matchadds,s:appendbufline(bufnr,'$',[a:dict.data.tableJoinNm . ' (' . tableRemarks . ')'],'Identifier'))
            endif
            call add(disableline,s:endbufline(bufnr))
        endif
        let cols = a:dict.cols
        if get(opt,"nocols",0) == 0 && !empty(cols)
            if g:dbiclient_disp_remarks && a:dict.data.single_table != ''
                let columnsRemarks = s:getColumnsTableRemarks(get(a:dict,'column_info',[]))
                let head = map(cols[:],{i,x -> get(columnsRemarks,x,'')})
                if !empty(filter(head[:],{_,x -> x != ''}))
                    let headstr = join(head,"\t")
                    call s:appendbufline(bufnr,'$',[headstr])
                    let dbiclient_col_line = s:endbufline(bufnr)
                    call add(disableline,s:endbufline(bufnr))
                    if len(head) > 0
                        let matchkeys = head[:]
                        call add(matchadds,['Type','\v%' . (s:endbufline(bufnr)) . 'l' . '(' . join(map(sort(matchkeys,{x,y -> len(x) == len(y) ? 0 : len(x) < len(y) ? 1 : -1}),{_,x -> '<\V' . x . '\v>'}),'|') . ')'])
                    endif
                    if !empty(get(a:dict,'maxcols',[]))
                        call map(a:dict.maxcols,{i,size -> strdisplaywidth(head[i]) > size ? strdisplaywidth(head[i]) : size})
                    endif
                endif
            endif
            let colsstr = join(cols,"\t")
            call s:appendbufline(bufnr,'$',[colsstr])
            if dbiclient_col_line == -1
                let dbiclient_col_line = s:endbufline(bufnr)
            endif
            call add(disableline,s:endbufline(bufnr))
            if len(cols) > 0
                let matchkeys = cols[:]
                call add(matchadds,['Type','\v%' . (s:endbufline(bufnr)) . 'l' . '(' . join(map(sort(matchkeys,{x,y -> len(x) == len(y) ? 0 : len(x) < len(y) ? 1 : -1}),{_,x -> '<\V' . x . '\v>'}),'|') . ')'])
            endif
            if len(get(a:dict,'primary_key',[])) > 0
                let matchkeys = get(a:dict,'primary_key',[])[:]
                call add(matchadds,['Title','\v%' . (s:endbufline(bufnr)) . 'l' . '(' . join(map(sort(matchkeys,{x,y -> len(x) == len(y) ? 0 : len(x) < len(y) ? 1 : -1}),{_,x -> '<\V' . x . '\v>'}),'|') . ')'])
            endif
        endif
        if get(a:dict.data,'column_info',0) == 1
            if len(get(a:dict,'primary_key',[])) > 0
                let matchkeys = get(a:dict,'primary_key',[])[:]
                call add(matchadds,['Title','\v%' . (s:endbufline(bufnr)) . 'l' . '(' . join(map(sort(matchkeys,{x,y -> len(x) == len(y) ? 0 : len(x) < len(y) ? 1 : -1}),{_,x -> '<\V' . x . '\v>'}),'|') . ')'])
            endif
        endif
        let lines = s:readfile(a:dict.data.tempfile)
        if g:dbiclient_col_delimiter != "\t"
            call s:appendbufline(bufnr,'$',substitute(lines,'\t' , g:dbiclient_col_delimiter, 'g'))
        else
            call s:appendbufline(bufnr,'$',lines)
        endif

    elseif get(a:dict,"status",9) == 2
        let sql = a:dict.data.sql
        let lines = s:readfile(a:dict.data.tempfile)
        call s:appendbufline(bufnr,'$',lines)
    else
        let lines = s:readfile(a:dict.data.tempfile)
        call s:appendbufline(bufnr,'$',lines)
    endif
    let dbiclient_bufmap = deepcopy(a:dict)
    let dbiclient_bufmap.opt = opt
    if has_key(dbiclient_bufmap.opt,'reloadBufname')
        call remove(dbiclient_bufmap.opt,'reloadBufname')
    endif
    if has_key(dbiclient_bufmap.opt,'reloadBufnr')
        call remove(dbiclient_bufmap.opt,'reloadBufnr')
    endif
    "echom parseSQL
    let cols = map(filter(get(dbiclient_bufmap,'column_info',[])[:],{_,x -> !empty(x)}),{_,x -> get(keys(x),0,'')})
    if empty(cols)
        let cols = get(dbiclient_bufmap,'cols',[])
    endif
    if empty(get(dbiclient_bufmap.opt,'precols',[]))
        let dbiclient_bufmap.opt.precols = cols
    elseif len(dbiclient_bufmap.opt.precols) < len(cols)
        let dbiclient_bufmap.opt.precols = cols
    endif
    if empty(get(dbiclient_bufmap.opt,'where',[]))
        let maxcol = max(map(cols[:],{_,x -> strdisplaywidth(x)}))
        let where = map(cols[:],{_,x -> x . repeat(' ' , maxcol - strdisplaywidth(x) +1) . '| ='})
    endif
    if empty(get(dbiclient_bufmap.opt,'extend',[]))
        let dbiclient_bufmap.opt.extend={}
        let dbiclient_bufmap.opt.extend.select = get(parseSQL, 'select', '')
        let dbiclient_bufmap.opt.extend.where = get(parseSQL, 'where', '')
        let dbiclient_bufmap.opt.extend.order = get(parseSQL, 'order', '')
        let dbiclient_bufmap.opt.extend.group = get(parseSQL, 'group', '')
        let dbiclient_bufmap.opt.select = {}
        let F1 = {x -> matchstr(x,'\v(^\w+\s*\.\s*\zs\w+)|(^[^.]+)')}
        let F2 = {x -> trim(substitute(matchstr(x,'\v(^\w+\s*\.\s*\zs\w+)|(^[^.]+)'),'\v(ASC|DESC)\s*$','',''))}
        let dbiclient_bufmap.opt.select.selectdict = s:f2.Foldl({x,y -> extend(x,y)},{},map(split(dbiclient_bufmap.opt.extend.select,','),{i,x -> {F1(x) : i+1}}))
        let dbiclient_bufmap.opt.select.selectdictstr = s:f2.Foldl({x,y -> extend(x,y)},{},map(split(dbiclient_bufmap.opt.extend.select,','),{i,x -> {F1(x) : '*' . (i+1) . ' ' . F1(x)}}))
        let dbiclient_bufmap.opt.select.selectdictAscDesc = s:f2.Foldl({x,y -> extend(x,y)},{},map(split(dbiclient_bufmap.opt.extend.select,','),{i,x -> {F1(x) : 0}}))

        if !empty(get(dbiclient_bufmap.opt,'where',[]))
            let where = dbiclient_bufmap.opt.where[:]
        endif
        let extendWhere = substitute(get(dbiclient_bufmap.opt.extend,'where',''),'\v\c^\s*<where>\s*','','')
        call filter(where,{i,x -> !(i==0 && x =~ '\v^\s*\(')})
        if !empty(extendWhere)
            call insert(where,'(' . matchstr(extendWhere,'\v^\s*\(\zs.*\ze\)\s*$|^\s*\zs.*\ze\s*$') . ')',0)
        endif

        let dbiclient_bufmap.opt.where = where

        let orderStr = matchstr(dbiclient_bufmap.opt.extend.order,'\v\corder by \zs.*')
        let dbiclient_bufmap.opt.order = {}
        let dbiclient_bufmap.opt.order.selectdict = s:f2.Foldl({x,y -> extend(x,y)},{},map(split(orderStr,','),{i,x -> {F2(x) : i+1}}))
        let dbiclient_bufmap.opt.order.selectdictstr = s:f2.Foldl({x,y -> extend(x,y)},{},map(split(orderStr,','),{i,x -> {F2(x) : (x =~ '\v\c<desc>' ? '[DESC]' : '[ASC]') . (i+1) . ' ' . F2(x)}}))
        let dbiclient_bufmap.opt.order.selectdictAscDesc = s:f2.Foldl({x,y -> extend(x,y)},{},map(split(orderStr,','),{i,x -> {F2(x) : x =~ '\v\c<desc>' ? 1 : 0}}))
        let dbiclient_bufmap.opt.group = {}
        let groupStr = matchstr(dbiclient_bufmap.opt.extend.group,'\v\cgroup by \zs.*')
        let dbiclient_bufmap.opt.group.selectdict = s:f2.Foldl({x,y -> extend(x,y)},{},map(split(groupStr,','),{i,x -> {F1(x) : i+1}}))
        let dbiclient_bufmap.opt.group.selectdictstr = s:f2.Foldl({x,y -> extend(x,y)},{},map(split(groupStr,','),{i,x -> {F1(x) : '*' . (i+1) . ' ' . F1(x)}}))
        let dbiclient_bufmap.opt.group.selectdictAscDesc = s:f2.Foldl({x,y -> extend(x,y)},{},map(split(groupStr,','),{i,x -> {F1(x) : 0}}))
    endif
    if get(a:dict,"status",9) != 9 && get(a:dict,'restoreFlg',0) != 1 && !empty(get(a:dict.data, 'sql',''))
        let path = s:getHistoryPathCmd(port)
        let path2 = s:getHistoryPathCmdAll()
        let bufVals=[]
        let datetime = strftime("%Y-%m-%d %H:%M:%S ")
        let dsn = get(connInfo,'dsn','')
        let user = s:getuser(connInfo)
        let connStr = user . '@' . dsn

        let sql = s:getSqlLine(get(a:dict.data, 'sql',''))
        let sql = (strdisplaywidth(sql) > 300 ? sql[:300] . '...' : sql) . "\t"
        call add(bufVals,string(dbiclient_bufmap))
        let ww=[datetime . 'DSN:' . connStr . ' SQL:' . sql . ' ' . join(bufVals,'{DELIMITER_CR}')]
        call writefile(ww,path,'a')
        call writefile(ww,path2,'a')
        if s:params[port].history_data_flg == 0 && filereadable(a:dict.data.tempfile)
            call delete(a:dict.data.tempfile)
        endif
        if s:params[port].history_data_flg == 0 && filereadable(a:dict.data.tempfile . 'err')
            call delete(a:dict.data.tempfile . 'err')
        endif
    endif
    if get(a:dict,"status",9) == 9
        let winid = s:f.getwid(bufnr)
        let disableline = range(line('$',winid))
    endif
    call setbufvar(bufnr,'dbiclient_bufmap',dbiclient_bufmap)
    call setbufvar(bufnr,'dbiclient_col_line',dbiclient_col_line)
    call setbufvar(bufnr,'disableline',disableline)
    if !empty(matchadds)
        call setbufvar(bufnr,'dbiclient_matches',matchadds)
        call s:sethl(bufnr)
    endif
    "call s:f.readonly(bufnr)
endfunction

function! s:cb_outputResult(ch,dict) abort
    let starttime = localtime()
    let port = get(a:dict.data.connInfo,'port')
    "echom 'test_cb_outputResult' . port
    let opt = get(a:dict.data,'opt',{})
    let ymdhmss = strftime("%Y%m%d%H%M%S",localtime()) . reltime()[1][-4:] . split(reltimestr(reltime()),'\.')[1]
    let bufname = get(a:dict.data,'reloadBufname','')
    let bufnr = s:bufnr(get(a:dict.data,'reloadBufnr',-1))
    if get(a:dict,'restoreFlg',0) == 1
        let bufnr = s:bufnr(bufname)
        "let bufname = bufname . '_HISTORY_PREVIEW'
    endif
    if s:f.getwid(bufnr) == -1
        let bufnr = s:peditBuffer(bufname)
        let a:dict.data.reloadBufnr = bufnr
        call add(s:bufferList,bufnr)
        if a:dict.data.sql != ''
            call s:nmap(get(g:,'dbiclient_nmap_result_WH',s:nmap_result_WH),      ':<C-u>call <SID>where()<CR>')
            call s:nmap(get(g:,'dbiclient_nmap_result_RE',s:nmap_result_RE),      ':<C-u>call <SID>reload(<SID>bufnr("%"))<CR>')
            call s:nmap(get(g:,'dbiclient_nmap_result_SE',s:nmap_result_SE),      ':<C-u>call <SID>select()<CR>')
            call s:nmap(get(g:,'dbiclient_nmap_result_GR',s:nmap_result_GR),  ':<C-u>call <SID>group()<CR>')
            call s:nmap(get(g:,'dbiclient_nmap_result_OR',s:nmap_result_OR),      ':<C-u>call <SID>order()<CR>')
            call s:nmap(get(g:,'dbiclient_nmap_result_AL',s:nmap_result_AL),      ':<C-u>call <SID>align(!get(b:dbiclient_bufmap,"alignFlg",0),<SID>bufnr("%"),<SID>getprelinesep())<CR>')
            call s:nmap(get(g:,'dbiclient_nmap_result_ED',s:nmap_result_ED),      ':<C-u>call <SID>editSql()<CR>')
            call s:vmap(get(g:,'dbiclient_vmap_result_IN',s:vmap_result_IN),  ':call <SID>createInsertRange()<CR>')
            call s:vmap(get(g:,'dbiclient_vmap_result_DE',s:vmap_result_DE),  ':call <SID>createDeleteRange()<CR>')
            call s:vmap(get(g:,'dbiclient_vmap_result_UP',s:vmap_result_UP),  ':call <SID>createUpdateRange()<CR>')
        endif
    else
        call s:deletebufline(bufnr,1,'$')
        call setbufvar(bufnr,'dbiclient_bufmap',{})
        call setbufvar(bufnr,'dbiclient_col_line',0)
        call setbufvar(bufnr,'dbiclient_header',[])
        call setbufvar(bufnr,'dbiclient_lines',[])
        call setbufvar(bufnr,'dbiclient_matches',[])
    endif
    call s:cb_outputResultCmn(a:ch,a:dict,bufnr)
    let dbiclient_bufmap = getbufvar(bufnr,'dbiclient_bufmap',{})
    let dbiclient_bufmap.alignFlg = 0
    if get(a:dict,"status",9) == 1
        call s:align(0,bufnr,s:getprelinesep())
    endif
    let endttime = localtime()
    let tupleList = getbufvar(bufnr,'dbiclient_tupleList',[])
    let maxsize = max(map(deepcopy(tupleList),{_,x -> len(x.Get1())}))
    let tuple = tupleList[1]
    let msgList = tuple.Get2()
    call add(msgList, ['VIM', '=' . (endttime - starttime) . 'sec'])
    let tuple = s:Tuple(tuple.Get1(),msgList)
    let tupleList[1] = tuple
    let info = tuple.Get1() . (repeat(' ', maxsize - len(tuple.Get1())) . ' :')
    let info .= s:f2.Foldl({x,y -> x . y},"",map(tuple.Get2(),{_,val -> ' [' . val[0] . val[1] . ']'}))
    call s:setbufline(bufnr,2,info)
    call setbufvar(bufnr,'dbiclient_tupleList',tupleList)
    let dbiclient_header = getbufvar(bufnr,'dbiclient_header',[])
    if !empty(dbiclient_header)
        let dbiclient_header[1] = info
    endif
    if s:f.getwid(s:bufnr('DBIJobList')) != -1
        call s:joblist(0)
    endif
    return 0
endfunction

function! s:cb_outputResultEasyAlign(ch,dict) abort
    let starttime = localtime()
    let port = get(a:dict.data.connInfo,'port')
    "echom 'test_cb_outputResultEasyAlign' . port
    let opt = get(a:dict.data,'opt',{})
    let ymdhmss = strftime("%Y%m%d%H%M%S",localtime()) . reltime()[1][-4:] . split(reltimestr(reltime()),'\.')[1]
    let bufname = get(a:dict.data,'reloadBufname','')
    let bufnr = s:bufnr(get(a:dict.data,'reloadBufnr',-1))
    if get(a:dict,'restoreFlg',0) == 1
        let bufnr = s:bufnr(bufname)
        "let bufname = bufname . '_HISTORY_PREVIEW'
    endif
    if s:f.getwid(bufnr) == -1
        let bufnr = s:peditBuffer(bufname)
        let a:dict.data.reloadBufnr = bufnr
        call add(s:bufferList,bufnr)
        if a:dict.data.sql != ''
            call s:nmap(get(g:,'dbiclient_nmap_result_WH',s:nmap_result_WH),      ':<C-u>call <SID>where()<CR>')
            call s:nmap(get(g:,'dbiclient_nmap_result_RE',s:nmap_result_RE),      ':<C-u>call <SID>reload(<SID>bufnr("%"))<CR>')
            call s:nmap(get(g:,'dbiclient_nmap_result_SE',s:nmap_result_SE),      ':<C-u>call <SID>select()<CR>')
            call s:nmap(get(g:,'dbiclient_nmap_result_GR',s:nmap_result_GR),  ':<C-u>call <SID>group()<CR>')
            call s:nmap(get(g:,'dbiclient_nmap_result_OR',s:nmap_result_OR),      ':<C-u>call <SID>order()<CR>')
            call s:nmap(get(g:,'dbiclient_nmap_result_AL',s:nmap_result_AL),      ':<C-u>call <SID>align(!get(b:dbiclient_bufmap,"alignFlg",0),<SID>bufnr("%"),<SID>getprelinesep())<CR>')
            call s:nmap(get(g:,'dbiclient_nmap_result_ED',s:nmap_result_ED),      ':<C-u>call <SID>editSql()<CR>')
            call s:vmap(get(g:,'dbiclient_vmap_result_IN',s:vmap_result_IN),  ':call <SID>createInsertRange()<CR>')
            call s:vmap(get(g:,'dbiclient_vmap_result_DE',s:vmap_result_DE),  ':call <SID>createDeleteRange()<CR>')
            call s:vmap(get(g:,'dbiclient_vmap_result_UP',s:vmap_result_UP),  ':call <SID>createUpdateRange()<CR>')
        endif
    else
        call s:deletebufline(bufnr,1,'$')
        call setbufvar(bufnr,'dbiclient_bufmap',{})
        call setbufvar(bufnr,'dbiclient_col_line',0)
        call setbufvar(bufnr,'dbiclient_header',[])
        call setbufvar(bufnr,'dbiclient_lines',[])
        call setbufvar(bufnr,'dbiclient_matches',[])
    endif
    call s:cb_outputResultCmn(a:ch,a:dict,bufnr)
    let dbiclient_bufmap = getbufvar(bufnr,'dbiclient_bufmap',{})
    let dbiclient_bufmap.alignFlg = 1
    if get(a:dict,"status",9) == 1
        if s:endbufline(bufnr) >= 10000
            redraw
            echohl WarningMsg
            echo 'It did not "align" because it took a long time to display.'
            echohl None
            call s:align(0,bufnr,s:getprelinesep())
        else
            call s:align(1,bufnr,s:getprelinesep())
        endif
    endif
    let endttime = localtime()
    let tupleList = getbufvar(bufnr,'dbiclient_tupleList',[])
    let maxsize = max(map(deepcopy(tupleList),{_,x -> len(x.Get1())}))
    let tuple = tupleList[1]
    let msgList = tuple.Get2()
    call add(msgList, ['VIM', '=' . (endttime - starttime) . 'sec'])
    let tuple = s:Tuple(tuple.Get1(),msgList)
    let tupleList[1] = tuple
    let info = tuple.Get1() . (repeat(' ', maxsize - len(tuple.Get1())) . ' :')
    let info .= s:f2.Foldl({x,y -> x . y},"",map(tuple.Get2(),{_,val -> ' [' . val[0] . val[1] . ']'}))
    call s:setbufline(bufnr,2,info)
    call setbufvar(bufnr,'dbiclient_tupleList',tupleList)
    let dbiclient_header = getbufvar(bufnr,'dbiclient_header',[])
    if !empty(dbiclient_header)
        let dbiclient_header[1] = info
    endif
    if s:f.getwid(s:bufnr('DBIJobList')) != -1
        call s:joblist(0)
    endif
    return 0
endfunction

function! s:nmap(char, command) abort
    exe 'nmap <buffer> <nowait> <silent> ' . a:char . ' ' a:command
endfunction

function! s:vmap(char, command) abort
    exe 'vmap <buffer> <nowait> <silent> ' . a:char . ' ' a:command
endfunction

function! s:align(alignFlg,bufnr, preCr) abort
    let bufnr = a:bufnr
    let dbiclient_bufmap = getbufvar(bufnr,'dbiclient_bufmap',{})
    if empty(dbiclient_bufmap) || empty(get(dbiclient_bufmap,"cols",[]))
        return
    endif
    let colsize = len(dbiclient_bufmap.cols)
    let save_cursor = getcurpos()
    let dbiclient_bufmap.alignFlg = a:alignFlg
    let dbiclient_lines = getbufvar(bufnr,'dbiclient_lines',[])
    let dbiclient_header = getbufvar(bufnr,'dbiclient_header',[])
    let dbiclient_col_line = getbufvar(bufnr,'dbiclient_col_line',0)
    if empty(dbiclient_lines)
        let dbiclient_header = getbufline(bufnr,0, dbiclient_col_line-1)
        let dbiclient_lines = getbufline(bufnr,dbiclient_col_line, '$')
    endif
    call s:deletebufline(bufnr,1,'$')
    call s:appendbufline(bufnr,'$',dbiclient_header)
    let dbiclient_lines_tmp = dbiclient_lines[:]
    if a:alignFlg == 1
        call s:appendbufline(bufnr,'$',dbiclient_lines_tmp)
        call s:alignLinesCR(bufnr,s:getprelinesep())
        let dbiclient_lines_tmp = getbufline(bufnr,dbiclient_col_line, '$')
        call s:deletebufline(bufnr,1,'$')
        call s:appendbufline(bufnr,'$',dbiclient_header)
        let surr='\V' . (g:dbiclient_surround == v:null ? '"' : g:dbiclient_surround)
        let dbiclient_lines_tmp = map(dbiclient_lines_tmp, {_,line -> substitute(line, surr . a:preCr . '\v|\V' . a:preCr . surr,'','g')})
        if !empty(get(dbiclient_bufmap,'maxcols',[]))
            let lines = s:getalignlist2(dbiclient_lines_tmp, dbiclient_bufmap.maxcols)
        else
            let lines = s:getalignlist(dbiclient_lines_tmp)
        endif
    else
        let surr='\V'
        let dbiclient_lines_tmp = map(dbiclient_lines_tmp, {_,line -> substitute(line, surr . a:preCr . '\v|\V' . a:preCr . surr,'','g')})
        let lines = dbiclient_lines_tmp
    endif
    call s:appendbufline(bufnr,'$',lines)
    if dbiclient_bufmap.alignFlg
        "call s:f.readonly(bufnr)
    endif
    call setbufvar(bufnr,'dbiclient_header',  dbiclient_header)
    call setbufvar(bufnr,'dbiclient_lines',  dbiclient_lines)
    call setpos('.', save_cursor)
endfunction

function! s:rpad(x,n,c) abort
    let len = a:n - strdisplaywidth(a:x)
    return a:x . repeat(a:c,a:n - strdisplaywidth(a:x))
endfunction

function! s:alignLinesCR(bufnr, preCr) abort
    let bufnr = a:bufnr
    let cbufnr = s:bufnr('%')
    call s:f.gotoWin(bufnr)
    let curpos = 1
    let save_cursor = getcurpos()
    norm gg
    let surr='\V' . (g:dbiclient_surround == v:null ? '"' : g:dbiclient_surround)
    try
        let posS = searchpos('\v(^|\t)\V' . a:preCr . surr . '\v\zs(\_[^\t]){-}\ze' . surr . a:preCr .'\v(\t|$)','c')
        let save_posS = getcurpos()
        let posE = searchpos('\v(^|\t)\V' . a:preCr . surr . '\v\zs(\_[^\t]){-}' . surr . a:preCr .'\v\ze(\t|$)','ce')
    catch /./
        let posS=[0]
        let posE=[0]
        exe '%s/' . a:preCr . '//g'
    endtry
    "echom line('.')
    let flg = 0
    call s:debugLog('alignCr:start')
    while posS[0] != 0
        if posS[0] != posE[0]
            let strS = getbufline(bufnr,posS[0])[0]
            let strE = getbufline(bufnr,posE[0])[0]
            if posE[0]-posS[0] > 1
                for pos in range(posS[0]+1,posE[0]-1)
                    let strS = strS . "<<CRLF>>" . getbufline(bufnr,pos)[0]
                endfor
            endif
            let str = strS . "<<CRLF>>" . strE
            call s:deletebufline(bufnr, (posS[0]+1),(posE[0]))
            call s:setbufline(bufnr,posS[0],str)
            call setpos('.', save_posS)
            call searchpos('\v' . surr . '\v(\_[^\t]){-}' . surr,'e')
            let flg = 1
        endif
        let posS = searchpos('\v(^|\t)\V' . a:preCr . surr . '\v\zs(\_[^\t]){-}\ze' . surr . a:preCr .'\v(\t|$)','c')
        "echom line('.')
        let save_posS = getcurpos()
        let posE = searchpos('\v(^|\t)\V' . a:preCr . surr . '\v\zs(\_[^\t]){-}' . surr . a:preCr .'\v\ze(\t|$)','ce')
    endwhile
    call s:debugLog('alignCr:end')
    call s:debugLog('alignCrReplace:start')
    if flg == 1
        let ret=[]
        for str in getbufline(bufnr,curpos,'$')
            let lines=[]
            let j = 0
            let colval = split(str,"\t",1)
            let emptyline = map(colval[:],{_,x->''})
            call add(lines,colval[:])
            call map(colval,{_,x -> split(x,'<<CRLF>>')})
            let index = filter(map(colval[:],{i,x->[i,len(x)]}),{_,x -> x[1]>1})
            let max = max(map(index[:],{_,x -> x[1]}))
            if max > 1
                for ppp in range(max-1)
                    call add(lines,emptyline[:])
                endfor
                for id in index
                    for i in range(id[1])
                        let lines[i][id[0]]=colval[id[0]][i]
                    endfor
                endfor
            endif
            call add(ret,lines)
        endfor

        call s:debugLog('alignCrReplace>:start')
        let i = curpos
        for lines in ret
            for line in lines
                call s:setbufline(bufnr,i,join(line,"\t"))
                let i+=1
            endfor
        endfor
        call s:debugLog('alignCrReplace>:end')
    endif
    call s:debugLog('alignCrReplace:end')
    call setpos('.', save_cursor)
    call s:f.gotoWin(cbufnr)
    return flg
endfunction

function! s:alignMain(preCr) abort
    let bufnr = s:bufnr(get(get(getbufvar(s:bufnr('%'),'dbiclient_bufmap',{}),'data',{}),'reloadBufnr',s:bufnr('%')))
    "call s:deletebuflineOfFilter(bufnr, '^\s*$')
    call s:alignLinesCR(bufnr,a:preCr)
    let dbiclient_bufmap = getbufvar(bufnr,'dbiclient_bufmap',{})
    if !empty(dbiclient_bufmap) && !empty(get(dbiclient_bufmap,'maxcols',[]))
        let lines = s:getalignlist2(getbufline(bufnr,0, '$'), dbiclient_bufmap.maxcols)
    else
        let lines = s:getalignlist(getbufline(bufnr,0, '$'))
    endif
    let i = 1
    for line in lines
        call s:setbufline(bufnr,i,line)
        let i+=1
    endfor
endfunction

function! s:getalignlist2(lines,maxCols) abort
    if empty(a:lines)
        return []
    endif
    call s:debugLog('align:start')
    let colsize = len(split(a:lines[0],g:dbiclient_col_delimiter,1))
    let lines = a:lines[:]
    call s:debugLog('align:lines ' . len(lines))
    let lines = map(lines ,{_,x -> split(x,g:dbiclient_col_delimiter,1)})
    call s:debugLog('align:copy')
    call s:debugLog('align:maxCols' . string(a:maxCols))
    let lines = map(lines,{_,cols -> colsize == len(cols) ? join(map(cols,{i,col -> col . repeat(' ',a:maxCols[i] + 1 - strdisplaywidth(col))}),g:dbiclient_col_delimiter_align . ' ') : join(cols,g:dbiclient_col_delimiter)})
    call s:debugLog('align:end')
    return lines
endfunction

function! s:getalignlist(lines) abort
    if empty(a:lines)
        return []
    endif
    let colsize = len(split(a:lines[0],g:dbiclient_col_delimiter,1))
    let maxsize = 200000/colsize
    call s:debugLog('align:start:maxsize ' . maxsize)
    let lines = a:lines[:maxsize]
    call s:debugLog('align:lines ' . len(lines))
    let lines2 = a:lines[maxsize+1:]
    call s:debugLog('align:lines2 ' . len(lines2))
    let lines = map(lines,{_,x -> split(x,g:dbiclient_col_delimiter,1)})
    call s:debugLog('align:copy')
    let linesLen = map(deepcopy(lines),{_,x -> map(x,{_,y -> strdisplaywidth(y)})})
    call s:debugLog('align:linesLen')
    let maxCols = copy(linesLen[0])
    call map(copy(linesLen),{_,cols -> map(maxCols,{i,col -> colsize == len(cols) && col < cols[i] ? cols[i] : col})})
    call s:debugLog('align:maxCols' . string(maxCols))
    let lines = map(lines,{_,cols -> colsize == len(cols) ? join(map(cols,{i,col -> col . repeat(' ',maxCols[i] + 1 - strdisplaywidth(col))}),g:dbiclient_col_delimiter_align . ' ') : join(cols,g:dbiclient_col_delimiter)})
    call s:debugLog('align:end')
    return extend(lines,lines2)
endfunction

function! s:selectTableOfList(schemtable,port) abort
    if s:isDisableline() || s:error2CurrentBuffer(a:port)
        return
    endif
    call s:selectTableCmn(1,a:schemtable,a:port)
endfunction

function! s:selectTable(alignFlg,wordFlg,table) abort
    let port = s:getCurrentPort()
    if trim(a:table) != ''
        let table = trim(a:table)
    else
        if a:wordFlg
            let table = matchstr(expand('<cWORD>'),'\v(\w|[$#.])+')
        else
            let table = join(s:f.getRangeCurList(getpos("'<"), getpos("'>")))
        endif
    endif
    call s:selectTableCmn(a:alignFlg,table,port,s:getLimitrows())
endfunction

function! s:selectTableCmn(alignFlg,table,port,...) abort
    if empty(trim(a:table))
        return
    endif
    if s:error1(a:port)
        return {}
    endif
    let limitrows = get(a:,1,s:getLimitrows())
    let list = ['SELECT * FROM ' . a:table]
    call s:getQueryAsync(join(list,"\n"),s:callbackstr(a:alignFlg),limitrows,{'single_table':a:table},a:port)
endfunction

function! s:editHistory(str) abort
    let port = s:getPort()
    function! s:editSqlQuery(alignFlg) abort
        let port = s:getPort()
        if s:error2CurrentBuffer(port)
            return
        endif
        if s:isDisableline()
            return
        endif
        let sql = join(getline(0,'$'),"\n")
        let bufnr = s:bufnr('%')
        let dbiclient_bufmap = getbufvar(bufnr,'dbiclient_bufmap',{})
        let dbiclient_bufmap.data.sql = sql
        let dbiclient_bufmap.data.single_table = ''
        let dbiclient_bufmap.opt = {}
        let limitrows = get(dbiclient_bufmap,'limitrows',s:getLimitrows())
        call setbufvar(dbiclient_bufmap.data.reloadBufnr,'dbiclient_bufmap',dbiclient_bufmap)
        call s:reload(dbiclient_bufmap.data.reloadBufnr)
    endfunction
    if s:isDisableline()
        return
    endif
    let bufname = bufname('%') . '_SQL_PREVIEW'
    let bufnr = s:newBuffer(bufname )
    let list = s:getSqlHistory(a:str)
    call s:appendbufline(bufnr,'$',list)
endfunction

function! s:getSqlLineDelComment(sql) abort
    if a:sql == ''
        return ''
    endif
    let port = s:getCurrentPort()
    let connInfo = get(s:params,port,{})
    let dsn = matchstr(get(connInfo,'dsn',''),'\v\s*\zs\w+')
    let commentStrList = ['--']

    if dsn =~? 'mysql'
        call add(commentStrList,'#')
    endif

    for commentStr in commentStrList
        let ret = map(split(a:sql,"\n"),{_,x -> substitute(x,'\v^\s*' . commentStr . '.*$',"\\=repeat(' ', strdisplaywidth(submatch(0)))",'')})
        let ret = map(ret,{_,x -> substitute(x,'\v''(''''|[^'']){-}''', "\\=substitute(submatch(0), " . string(commentStr) . ",'###HYPEN###','g')", 'g')})
        let ret = map(ret,{_,x -> substitute(x,'\v"(""|[^"]){-}"', "\\=substitute(submatch(0), " . string(commentStr) . ",'###HYPEN###','g')", 'g')})
        if dsn =~? 'oracle'
            let ret = map(ret,{_,x -> substitute(x,'\vq''[(\[{<]\zs.{-}\ze[)\]}>]''', "\\=substitute(submatch(0), " . string(commentStr) . ",'###HYPEN###','g')", 'g')})
            let ret = map(ret,{_,x -> substitute(x,'\vq''(.)\zs.{-}\ze\1''', "\\=substitute(submatch(0), " . string(commentStr) . ",'###HYPEN###','g')", 'g')})
        endif
        let ret = map(ret,{_,x -> substitute(x,'\v' . commentStr . '.*$',"\\=repeat(' ', strdisplaywidth(submatch(0)))",'')})
        "echom string(ret)
        let ret = map(ret,{_,x -> substitute(x,'\V###HYPEN###', commentStr,'g')})
    endfor
    let ret = join(ret,"\n")
    return ret
endfunction

function! s:getSqlLine(sql) abort
    if a:sql == ''
        return ''
    endif
    "let ret = map(split(a:sql,"\n"),{_,x -> substitute(x,'\v^%(%((--)@!.(-)@!.)|%(''%([^'']|('''')){-}''))*\zs\s*--.*$','','g')})
    let ret = split(a:sql,"\n")
    let ret = join(map(ret,{_,x -> substitute(x,'\v(^\s*|\s*$)','','g')}))
    return ret
endfunction

function! s:selectHistoryAll() abort
    let matchadds=[]
    let list = map(s:loadQueryHistoryAllCmd(),{_,x -> substitute(x,'\n',' ','g')})
    let dsnlist = []
    "let dsnlist = uniq(sort(map(list[:],{_,x -> [matchstr(x,'\v^(.{-})DSN:(.{-})\@\zs(.{-})\zeSQL:'), matchstr(x,'\v^(.{-})DSN:\zs(.{-})\ze\@(.{-})SQL:')]})))
    let list = map(list,{_,x -> matchstr(x,'\v^\zs(.{-})\zeDSN:(.{-})SQL:') . matchstr(x,'\v^(.{-})DSN:\zs(.{-})\zeSQL:') . matchstr(x,'\v^.{-}SQL:\zs.{-}\ze\t')})
    let bufname='DB_HISTORY_ALL_CMD'
    let bufnr = s:bufnr(bufname)
    if s:f.getwidCurrentTab(bufnr) == -1
        let bufnr = s:newBuffer(bufname )
        call s:nmap(get(g:,'dbiclient_nmap_history_PR',s:nmap_history_PR), ':<C-u>call <SID>dbhistoryRestore(<SID>loadQueryHistoryAllCmd()[line(".")  - len(b:disableline) - 1])<CR>')
        call s:nmap(get(g:,'dbiclient_nmap_history_SQ',s:nmap_history_SQ), ':call <SID>editHistory(<SID>loadQueryHistoryAllCmd()[line(".")  - len(b:disableline) - 1])<CR>')
        call s:nmap(get(g:,'dbiclient_nmap_history_RE',s:nmap_history_RE), ':call <SID>dbhistoryAllCmd()<CR>')
        call s:nmap(get(g:,'dbiclient_nmap_history_DD',s:nmap_history_DD), ':<C-u>call <SID>deleteHistory(<SID>getHistoryPathCmdAll(),line(".")  - len(b:disableline) - 1, 0)<CR>:call <SID>dbhistoryAllCmd()<CR>')
    else
        call s:f.noreadonly(bufnr)
        call s:deletebufline(bufnr,1,'$')
        call setbufvar(bufnr,'dbiclient_bufmap',{})
    endif
    let disableline = []
    let tupleList = []
    let msgList = []
    call add(msgList, [get(g:,'dbiclient_nmap_history_PR',s:nmap_history_PR), ':PREVIEW'])
    call add(msgList, [get(g:,'dbiclient_nmap_history_SQ',s:nmap_history_SQ), ':SQL_PREVIEW'])
    call add(msgList, [get(g:,'dbiclient_nmap_history_RE',s:nmap_history_RE), ':RELOAD'])
    call add(msgList, [get(g:,'dbiclient_nmap_history_DD',s:nmap_history_DD), ':DELETE'])
    call add(tupleList, s:Tuple('"Quick Help<nmap>',msgList))
    let maxsize = max(map(deepcopy(tupleList),{_,x -> len(x.Get1())}))
    for tuple in tupleList
        let info = tuple.Get1() . (repeat(' ', maxsize - len(tuple.Get1())) . ' :')
        let info .= s:f2.Foldl({x,y -> x . y},"",map(tuple.Get2(),{_,val -> ' [' . val[0] . val[1] . ']'}))
        call s:appendbufline(bufnr,'$',[info])
        call add(disableline,line('$'))
    endfor
    call add(matchadds,['Comment','\v%1l^".{-}:'])
    call add(matchadds,['String','\v%1l^".{-}:\zs.*$'])
    call add(matchadds,['Function','\v%1l( \[)@<=.{-}(\:)@='])
    for [dsn,schema] in dsnlist
        if !empty(trim(dsn))
            call add(matchadds,['Type','\V' . dsn])
        endif
        if !empty(trim(schema))
            call add(matchadds,['String','\V' . schema])
        endif
    endfor
    call s:appendbufline(bufnr,'$',list)
    call setbufvar(bufnr,'dbiclient_matches',matchadds)
    call setbufvar(bufnr,'disableline',disableline)
    call s:sethl(bufnr)
    norm G
    call s:f.readonly(bufnr)
endfunction

function! s:selectHistory(port) abort
    let port = a:port
    if get(get(s:params,port,{}),'connect',9) != 1
        return
    endif
    let matchadds=[]
    let list = map(s:loadQueryHistoryCmd(port),{_,x -> substitute(x,'\n',' ','g')})
    let dsnlist = []
    "let dsnlist = uniq(sort(map(list[:],{_,x -> [matchstr(x,'\v^(.{-})DSN:(.{-})\@\zs(.{-})\zeSQL:'), matchstr(x,'\v^(.{-})DSN:\zs(.{-})\ze\@(.{-})SQL:')]})))
    let list = map(list,{_,x -> matchstr(x,'\v^\zs(.{-})\zeDSN:(.{-})SQL:') . matchstr(x,'\v^.{-}SQL:\zs.{-}\ze\t')})
    let bufname='DB_HISTORY_CMD_' . s:getuser(s:params[port])
    let bufnr = s:bufnr(bufname)
    if s:f.getwidCurrentTab(bufnr) == -1
        let bufnr = s:newBuffer(bufname )
        call s:nmap(get(g:,'dbiclient_nmap_history_PR',s:nmap_history_PR), ':<C-u>call <SID>dbhistoryRestore(<SID>loadQueryHistoryCmd(<SID>getPort())[line(".")  - len(b:disableline) - 1])<CR>')
        call s:nmap(get(g:,'dbiclient_nmap_history_SQ',s:nmap_history_SQ), ':call <SID>editHistory(<SID>loadQueryHistoryCmd(<SID>getPort())[line(".")  - len(b:disableline) - 1])<CR>')
        call s:nmap(get(g:,'dbiclient_nmap_history_RE',s:nmap_history_RE), ':call <SID>dbhistoryCmd(<SID>getPort())<CR>')
        call s:nmap(get(g:,'dbiclient_nmap_history_DD',s:nmap_history_DD), ':<C-u>call <SID>deleteHistory(<SID>getHistoryPathCmd(<SID>getPort()),line(".")  - len(b:disableline) - 1, 1)<CR>:call <SID>dbhistoryCmd(<SID>getPort())<CR>')
    else
        call s:f.noreadonly(bufnr)
        call s:deletebufline(bufnr,1,'$')
        call setbufvar(bufnr,'dbiclient_bufmap',{})
    endif
    let dbiclient_bufmap = {}
    let dbiclient_bufmap.data = {}
    let dbiclient_bufmap.data.connInfo = s:params[port]
    let disableline = []
    let tupleList = []
    let msgList = []
    call add(msgList, [get(g:,'dbiclient_nmap_history_PR',s:nmap_history_PR), ':PREVIEW'])
    call add(msgList, [get(g:,'dbiclient_nmap_history_SQ',s:nmap_history_SQ), ':SQL_PREVIEW'])
    call add(msgList, [get(g:,'dbiclient_nmap_history_RE',s:nmap_history_RE), ':RELOAD'])
    call add(msgList, [get(g:,'dbiclient_nmap_history_DD',s:nmap_history_DD), ':DELETE'])
    call add(tupleList, s:Tuple('"Quick Help<nmap>',msgList))
    let maxsize = max(map(deepcopy(tupleList),{_,x -> len(x.Get1())}))
    for tuple in tupleList
        let info = tuple.Get1() . (repeat(' ', maxsize - len(tuple.Get1())) . ' :')
        let info .= s:f2.Foldl({x,y -> x . y},"",map(tuple.Get2(),{_,val -> ' [' . val[0] . val[1] . ']'}))
        call s:appendbufline(bufnr,'$',[info])
        call add(disableline,line('$'))
    endfor
    call add(matchadds,['Comment','\v%1l^".{-}:'])
    call add(matchadds,['String','\v%1l^".{-}:\zs.*$'])
    call add(matchadds,['Function','\v%1l( \[)@<=.{-}(\:)@='])
    for [dsn,schema] in dsnlist
        if !empty(trim(dsn))
            call add(matchadds,['Type','\V' . dsn])
        endif
        if !empty(trim(schema))
            call add(matchadds,['String','\V' . schema])
        endif
    endfor
    call s:appendbufline(bufnr,'$',list)
    call setbufvar(bufnr,'dbiclient_matches',matchadds)
    call setbufvar(bufnr, 'dbiclient_bufmap', dbiclient_bufmap)
    call setbufvar(bufnr,'disableline',disableline)
    call s:sethl(bufnr)
    norm G
    call s:f.readonly(bufnr)
endfunction

function! s:parseSQL(sql) abort
    let list = s:getTableJoinList(a:sql)
    let sql = s:getSqlLine(s:getSqlLineDelComment(a:sql))
    if len(list) == 1
        let parseSQL={}
        let parseSQL.select=['',matchstr(sql,'\v\c<select>\zs.{-}\ze<from>')]
        let parseSQL.select[1]=parseSQL.select[1] =~ '\v\*' ? '' : parseSQL.select[1]
        let parseSQL.table=['',s:getTableName(sql,'')]
        "let parseSQL.table=['',matchstr(sql,'\v\c<from>\zs.{-}\ze(<where>|<group>|<order>|$)')]
        let parseSQL.where=['WHERE ',matchstr(sql,'\v\c<where>\zs.{-}\ze(<group>|<order>|$)')]
        let parseSQL.group=['GROUP BY ',matchstr(sql,'\v\c<group>\s+<by>\zs.{-}\ze(<order>|$)')]
        let parseSQL.order=['ORDER BY ',matchstr(sql,'\v\c<order>\s+<by>\zs.{-}\ze($)')]
        if parseSQL.select[1] =~ '\v[().]' || parseSQL.table[1] =~ '\v[()]' || parseSQL.group[1] =~ '\v[().]' || parseSQL.order[1] =~ '\v[().]'
            return {}
        endif
        call s:debugLog(string(parseSQL))
        return map(filter(parseSQL,{_,x -> trim(x[1])!=''}),{_,x -> x[0] . trim(x[1])})
    else
        return {}
    endif
endfunction

function! s:extendquery(alignFlg,select,where,order,group) abort
    let port = s:getPort()
    if s:error2CurrentBuffer(port)
        return
    endif
    let bufnr = s:bufnr('%')
    let dbiclient_bufmap = getbufvar(bufnr,'dbiclient_bufmap',{})
    let limitrows = dbiclient_bufmap.data.limitrows
    let sql = dbiclient_bufmap.data.sql
    if sql =~ '\v\/\*PRESQL\*\/\zs\_.{-}\ze\/\*PRESQL\*\/'
        let sql = matchstr(sql,'\v\/\*PRESQL\*\/\s*\zs\_.{-}\ze\s*\/\*PRESQL\*\/')
    endif
    let sql = substitute(sql,'\v\_^(\r\n|\r|\n)+','','')
    let sql = substitute(sql,'\v(\r\n|\r|\n)+\_$','','')
    let jointable = s:getTableJoinList(sql)
    let select = a:select == '' ? '*' : a:select
    if len(jointable) > 1 || get(dbiclient_bufmap.data,'single_table','') == ''
        let sql = 'SELECT ' . select . "\n" . 'FROM (/*PRESQL*/ ' . "\n" . sql . "\n" . ' /*PRESQL*/) ' . "\n" . join(filter([a:where, a:group, a:order],{_,x -> trim(x)!=''}),"\n")
    else
        let sql = 'SELECT ' . select . "\n" . 'FROM ' . get(dbiclient_bufmap.data,'single_table','') . "\n" . join(filter([a:where, a:group, a:order],{_,x -> trim(x)!=''}),"\n")
    endif
    let opt = dbiclient_bufmap.opt
    "let opt.where = get(dbiclient_bufmap,'where',[])
    let opt.extend={}
    let opt.extend.select = a:select
    let opt.extend.where = a:where
    let opt.extend.order = a:order
    let opt.extend.group = a:group
    if !has_key(opt,'precols')
        let opt.precols = get(dbiclient_bufmap,'cols',[])
    endif
    let dbiclient_bufmap.data.sql = sql
    call setbufvar(dbiclient_bufmap.data.reloadBufnr,'dbiclient_bufmap',dbiclient_bufmap)
    call s:reload(dbiclient_bufmap.data.reloadBufnr)
endfunction

function! s:editSqlDo() abort
    let port = s:getPort()
    let bufnr = s:bufnr('%')
    let dbiclient_bufmap = deepcopy(getbufvar(bufnr,'dbiclient_bufmap',{}))
    let bufname = bufname('%') . '_SQL_PREVIEW'
    let bufnr = s:newBuffer(bufname)
    let i = 0
    for sql in dbiclient_bufmap.data.do
        let sqllist = s:split(sql,'\n')
        if i < len(dbiclient_bufmap.data.do) - 1
            let delimiter = get(dbiclient_bufmap.data,'delimiter','')
            let sqllist[-1] = sqllist[-1] . delimiter
        endif
        call s:appendbufline(bufnr,'$',sqllist)
        let i += 1
    endfor
    norm gg
endfunction

function! s:editSql() abort
    let port = s:getPort()
    function! s:editSqlQuery(alignFlg) abort
        let port = s:getPort()
        if s:error2CurrentBuffer(port)
            return
        endif
        if s:isDisableline()
            return
        endif
        let sql = join(getline(0,'$'),"\n")
        let bufnr = s:bufnr('%')
        let dbiclient_bufmap = getbufvar(bufnr,'dbiclient_bufmap',{})
        let dbiclient_bufmap.data.sql = sql
        let dbiclient_bufmap.data.single_table = ''
        let dbiclient_bufmap.opt = {}
        let limitrows = get(dbiclient_bufmap,'limitrows',s:getLimitrows())
        call setbufvar(dbiclient_bufmap.data.reloadBufnr,'dbiclient_bufmap',dbiclient_bufmap)
        call s:reload(dbiclient_bufmap.data.reloadBufnr)
    endfunction
    let bufname = bufname('%')
    let bufnr = s:bufnr('%')
    let dbiclient_bufmap = deepcopy(getbufvar(bufnr,'dbiclient_bufmap',{}))
    let bufname = bufname('%') . '_SQL_EDIT'
    let bufnr = s:newBuffer(bufname)
    call s:appendbufline(bufnr,0,split(dbiclient_bufmap.data.sql,"\n"))
    norm gg
    call setbufvar(s:bufnr('%'),'dbiclient_bufmap',dbiclient_bufmap)
    call s:nmap(get(g:,'dbiclient_nmap_edit_SQ',s:nmap_edit_SQ), ':<C-u>call <SID>editSqlQuery(b:dbiclient_bufmap.alignFlg)<CR>')
endfunction

function! s:order() abort
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
        let dbiclient_bufmap = getbufvar(bufnr,'dbiclient_bufmap',{})
        if !exists('dbiclient_bufmap.opt.extend')
            let dbiclient_bufmap.opt.extend = {}
        endif
        let selectdict = getbufvar(bufnr,'selectdict',{})
        let selectdictAscDesc = getbufvar(bufnr,'selectdictAscDesc',{})
        let selectdictstr = getbufvar(bufnr,'selectdictstr',{})
        if empty(selectdict)
            let dbiclient_bufmap.opt.extend.order = ''
        else
            let list1 = s:selectValues(selectdict)
            let order = 'ORDER BY ' . join(list1,",")
            let dbiclient_bufmap.opt.extend.order = order
        endif
        let dbiclient_bufmap.opt.order = {}
        let dbiclient_bufmap.opt.order.selectdict = selectdict
        let dbiclient_bufmap.opt.order.selectdictstr = selectdictstr
        let dbiclient_bufmap.opt.order.selectdictAscDesc = selectdictAscDesc
        let extend = dbiclient_bufmap.opt.extend
        call s:extendquery(a:alignFlg,get(extend,'select',''),get(extend,'where',''),get(extend,'order',''),get(extend,'group',''))
    endfunction
    let bufname = bufname('%')
    let bufnr = s:bufnr('%')
    let dbiclient_bufmap = deepcopy(getbufvar(bufnr,'dbiclient_bufmap',{}))
    let singleTableFlg = !empty(get(dbiclient_bufmap.data,'single_table',''))
    if !singleTableFlg
        return
    endif
    if s:error2CurrentBuffer(port)
        return
    endif
    call s:selectExtends(bufname . '_SQL_ORDER',1,get(dbiclient_bufmap.opt,'order',{}))
    call setbufvar(s:bufnr('%'),'dbiclient_bufmap',dbiclient_bufmap)
    call s:nmap(get(g:,'dbiclient_nmap_order_SQ',s:nmap_order_SQ), ':<C-u>call <SID>orderQuery(b:dbiclient_bufmap.alignFlg)<CR>')
endfunction

function! s:count(schemtable,port) abort
    if s:isDisableline() || s:error2CurrentBuffer(a:port)
        return
    endif
    return s:getQueryAsyncSimple('SELECT COUNT(*) FROM ' . a:schemtable)
endfunction

function! s:select() abort
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
        let dbiclient_bufmap = getbufvar(bufnr,'dbiclient_bufmap',{})
        if !exists('dbiclient_bufmap.opt.extend')
            let dbiclient_bufmap.opt.extend = {}
        endif
        let selectdict = getbufvar(bufnr,'selectdict',{})
        let selectdictAscDesc = getbufvar(bufnr,'selectdictAscDesc',{})
        let selectdictstr = getbufvar(bufnr,'selectdictstr',{})
        if empty(selectdict)
            let dbiclient_bufmap.opt.extend.select = ''
        else
            let list1 = s:selectValues(selectdict)
            let select = join(list1,",")
            let dbiclient_bufmap.opt.extend.select = select
        endif
        let dbiclient_bufmap.opt.select = {}
        let dbiclient_bufmap.opt.select.selectdict = selectdict
        let dbiclient_bufmap.opt.select.selectdictstr = selectdictstr
        let dbiclient_bufmap.opt.select.selectdictAscDesc = selectdictAscDesc
        let extend = dbiclient_bufmap.opt.extend
        call s:extendquery(a:alignFlg,get(extend,'select',''),get(extend,'where',''),get(extend,'order',''),get(extend,'group',''))
    endfunction
    let bufname = bufname('%')
    let bufnr = s:bufnr('%')
    let dbiclient_bufmap = deepcopy(getbufvar(bufnr,'dbiclient_bufmap',{}))
    let singleTableFlg = !empty(get(dbiclient_bufmap.data,'single_table',''))
    if !singleTableFlg
        return
    endif
    if s:error2CurrentBuffer(port)
        return
    endif
    call s:selectExtends(bufname . '_SQL_SELECT',0,get(dbiclient_bufmap.opt,'select',{}))
    call setbufvar(s:bufnr('%'),'dbiclient_bufmap',dbiclient_bufmap)
    call s:nmap(get(g:,'dbiclient_nmap_select_SQ',s:nmap_select_SQ), ':<C-u>call <SID>selectQuery(b:dbiclient_bufmap.alignFlg)<CR>')
endfunction

function! s:group() abort
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
        let dbiclient_bufmap = deepcopy(getbufvar(bufnr,'dbiclient_bufmap',{}))
        if !exists('dbiclient_bufmap.opt.extend')
            let dbiclient_bufmap.opt.extend = {}
        endif
        let selectdict = getbufvar(bufnr,'selectdict',{})
        let selectdictAscDesc = getbufvar(bufnr,'selectdictAscDesc',{})
        let selectdictstr = getbufvar(bufnr,'selectdictstr',{})
        if empty(selectdict)
            let dbiclient_bufmap.opt.extend.group = ''
            let dbiclient_bufmap.opt.extend.select = ''
        else
            let list1 = s:selectValues(selectdict)
            let group = 'GROUP BY ' . join(list1,",")
            let dbiclient_bufmap.opt.extend.group = group
            let dbiclient_bufmap.opt.extend.select = join(list1, ',')
        endif
        let dbiclient_bufmap.opt.group = {}
        let dbiclient_bufmap.opt.group.selectdict = selectdict
        let dbiclient_bufmap.opt.group.selectdictstr = selectdictstr
        let dbiclient_bufmap.opt.group.selectdictAscDesc = selectdictAscDesc
        let extend = dbiclient_bufmap.opt.extend
        call s:extendquery(a:alignFlg,get(extend,'select',''),get(extend,'where',''),get(extend,'order',''),get(extend,'group',''))
    endfunction
    let bufname = bufname('%')
    let bufnr = s:bufnr('%')
    let dbiclient_bufmap = deepcopy(getbufvar(bufnr,'dbiclient_bufmap',{}))
    let singleTableFlg = !empty(get(dbiclient_bufmap.data,'single_table',''))
    if !singleTableFlg
        return
    endif
    if s:error2CurrentBuffer(port)
        return
    endif
    call s:selectExtends(bufname . '_SQL_GROUP',0,get(dbiclient_bufmap.opt,'group',{}))
    call setbufvar(s:bufnr('%'),'dbiclient_bufmap',dbiclient_bufmap)
    call s:nmap(get(g:,'dbiclient_nmap_group_SQ',s:nmap_group_SQ), ':<C-u>call <SID>groupQuery(b:dbiclient_bufmap.alignFlg)<CR>')
endfunction

function! s:where() abort
    let port = s:getPort()
    function! s:selectWhere() abort
        let bufnr = s:bufnr('%')
        let dbiclient_bufmap = getbufvar(bufnr,'dbiclient_bufmap',{})
        let where = dbiclient_bufmap.opt.where
        let bufname = bufname('%') . '_SQL_WHERE'
        let bufnr = s:newBuffer(bufname)
        inoremap <buffer> <silent> <CR> <ESC>
        call s:appendbufline(bufnr,0,where)
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
        let dbiclient_bufmap = getbufvar(bufnr,'dbiclient_bufmap',{})
        let keys1 = map(dbiclient_bufmap.opt.where[:],{_,x -> matchstr(x,'\v^\zs.{-}\|\ze')})
        let keys2 = map(getline(0,'$'),{_,x -> matchstr(x,'\v^\zs.{-}\|\ze')})
        let keys1 = filter(keys1, {_,x -> trim(x) != ''})
        let keys2 = filter(keys2, {_,x -> trim(x) != ''})

        if keys1 != keys2
            let bufnr = s:bufnr('%')
            call s:deletebufline(bufnr,1,'$')
            call s:appendbufline(bufnr,0,dbiclient_bufmap.opt.where)
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
        let dbiclient_bufmap.opt.where = getline(0,'$')

        let limitrows = dbiclient_bufmap.data.limitrows
        let whereAnd = map(filter(getline(0,'$'),{_,x -> x !~ '\v^.{-}\|\s*\=?\s*$'}),{_,x -> substitute(x,'\v^.{-}\zs\s+\|\s*\ze',' ','')})
        let whereStr = join(whereAnd,"\nAND ")
        if trim(whereStr) != ''
            let where = 'WHERE ' . whereStr
        else
            let where = ''
        endif
        let dbiclient_bufmap.opt.extend.where = where
        let extend = dbiclient_bufmap.opt.extend
        call s:extendquery(a:alignFlg,get(extend,'select',''),get(extend,'where',''),get(extend,'order',''),get(extend,'group',''))
    endfunction
    let bufname = bufname('%')
    let bufnr = s:bufnr('%')
    let dbiclient_bufmap = deepcopy(getbufvar(bufnr,'dbiclient_bufmap',{}))
    let singleTableFlg = !empty(get(dbiclient_bufmap.data,'single_table',''))
    if !singleTableFlg
        return
    endif
    if s:error2CurrentBuffer(port)
        return
    endif
    call s:selectWhere()
    norm gg$
    call setbufvar(s:bufnr('%'),'dbiclient_bufmap',dbiclient_bufmap)
    call s:nmap(get(g:,'dbiclient_nmap_where_SQ',s:nmap_where_SQ), ':<C-u>call <SID>whereQuery(b:dbiclient_bufmap.alignFlg)<CR>')
endfunction

function! s:dbhistoryAllCmd() abort
    let save_cursor = getcurpos()
    call s:selectHistoryAll()
    call setpos('.', save_cursor)
    return
endfunction

function! s:dbhistoryCmd(port) abort
    let port = a:port
    if !has_key(s:params,port)
        return
    endif
    let save_cursor = getcurpos()
    call s:selectHistory(port)
    call setpos('.', save_cursor)
    return
endfunction

function! s:dbhistoryRestore(str) abort
    if s:isDisableline()
        return
    endif
    sandbox silent! let cmd = map(split(matchstr(a:str,'\v^.{-}\t\zs.*'),'{DELIMITER_CR}'),{_,x ->  eval(x)})
    if len(cmd) == 1
        let dbiclient_bufmap = cmd[0]
        "let dbiclient_bufmap.alignFlg = 1
        let dbiclient_bufmap.restoreFlg = 1
        let connInfo1 = s:getconninfo(dbiclient_bufmap)
        for [port,connInfo2] in items(s:params)
            let status = s:ch_statusStrOk(s:ch_open2status(port))
            if get(connInfo1,'hashKey','1') == get(connInfo2,'hashKey','2') && status
                let dbiclient_bufmap.data.connInfo = connInfo2
                break
            endif
        endfor
        let dbiclient_bufmap.data.reloadBufnr = -1
        let dbiclient_bufmap.data.reloadBufname = dbiclient_bufmap.data.reloadBufname . '_HIST'
        if s:f.getwidCurrentTab(s:bufnr(dbiclient_bufmap.data.reloadBufname)) == -1
            call s:f.delbuf(s:bufnr(dbiclient_bufmap.data.reloadBufname))
        endif
        if has_key(dbiclient_bufmap.data,'sql')
            let callbackstr = get(dbiclient_bufmap.data,'callbackstr','s:cb_outputResultEasyAlign') 
            if has_key(dbiclient_bufmap,'opt')
                call remove(dbiclient_bufmap,'opt')
            endif
            call funcref(callbackstr)({},dbiclient_bufmap)
        else
            call s:cb_do({},dbiclient_bufmap)
        endif
        call s:f.gotoWin(s:bufnr(dbiclient_bufmap.data.reloadBufname))
    endif
endfunction

function! s:getSqlHistory(str) abort
    if s:isDisableline()
        return
    endif
    let cmd = map(split(matchstr(a:str,'\v.{-}\t\zs.*'),'{DELIMITER_CR}'),{_,x -> eval(x)})
    if len(cmd) == 1
        let dbiclient_bufmap = cmd[0]
        if has_key(dbiclient_bufmap.data,'sql')
            return split(dbiclient_bufmap.data.sql,'\v(\r\n|[\n\r])')
        else
            return split(join(dbiclient_bufmap.data.do, get(dbiclient_bufmap.data, 'delimiter', '') . "\n"),'\v(\r\n|[\n\r])')
        endif
    endif
    return []
endfunction

function! s:reload(bufnr) abort
    let bufnr = a:bufnr
    if s:bufnr(bufnr) != s:bufnr('%')
        quit
    endif
    let dbiclient_bufmap = getbufvar(bufnr,'dbiclient_bufmap',{})

    if !empty(dbiclient_bufmap)
        call s:reloadMain(bufnr,get(dbiclient_bufmap,"alignFlg",0),get(get(dbiclient_bufmap,'data',{}),'limitrows',s:getLimitrows()))
    endif
endfunction

function! s:reloadMain(bufnr,alignFlg,limitrows) abort
    let bufnr = a:bufnr
    let dbiclient_bufmap = getbufvar(bufnr,'dbiclient_bufmap',{})
    let connInfo = s:getconninfo(dbiclient_bufmap)
    let port = get(connInfo,'port',-1)
    if s:error2(port,bufnr)
        return
    endif
    let dbiclient_bufmap.alignFlg = a:alignFlg
    let limitrows = a:limitrows
    let sql = dbiclient_bufmap.data.sql
    let opt = dbiclient_bufmap.opt
    let alignFlg = dbiclient_bufmap.alignFlg
    let opt.reloadBufname = dbiclient_bufmap.data.reloadBufname
    let opt.reloadBufnr = dbiclient_bufmap.data.reloadBufnr
    call s:getQueryAsync(sql,s:callbackstr(alignFlg),limitrows,opt,port)
endfunction

function! s:callbackstr(alignFlg) abort
    return a:alignFlg ? 's:cb_outputResultEasyAlign' : 's:cb_outputResult'
endfunction

function! s:userTablesMain(port) abort
    let port = a:port
    if !has_key(s:params,port)
        return
    endif
    if s:error1(port)
        return
    endif
    let tableNm = s:params[port].table_name
    let tabletype = s:params[port].tabletype
    call s:userTables(1,tableNm,tabletype,port)
endfunction

function! s:getParams() abort
    let port = s:getPort()
    return get(s:params,port,{})
endfunction

function! s:getTableNameSchem(port) abort
    let bufnr = s:bufnr('%')
    let dbiclient_col_line = getbufvar(bufnr,'dbiclient_col_line',0)
    let dbiclient_lines = getbufvar(bufnr,'dbiclient_lines',0)
    let line = line('.') - dbiclient_col_line
    let head = split(dbiclient_lines[0],g:dbiclient_col_delimiter,1)
    let row = split(dbiclient_lines[line],g:dbiclient_col_delimiter,1)
    let rowdict = s:f2.Foldl({x,y -> extend(x,y)},{},map(head,{i,x -> {x:row[i]}}))
    let schem = get(get(s:params,a:port,{}),'schema_flg',0) ? get(rowdict,'TABLE_SCHEM','') : ''
    let type = get(rowdict,'TABLE_TYPE','')
    let tableNm = get(rowdict,'TABLE_NAME','')
    return (empty(schem) ? '' : schem . '.') . (empty(tableNm) ? '' : tableNm)
endfunction

function! s:userTables(alignFlg,tableNm,tabletype,port) abort
    if s:error1(a:port)
        return
    endif
    let tableNm = a:tableNm == v:null || a:tableNm =~ '\v^\s*$' ? v:null : a:tableNm
    let tableNm = substitute(a:tableNm,"'","",'g')
    let tabletype = a:tabletype == v:null || a:tabletype =~ '\v^\s*$' ? v:null : a:tabletype
    let tabletype = substitute(a:tabletype,"'","",'g')
    let s:params[a:port].tabletype = tabletype == v:null ? '' : tabletype
    let s:params[a:port].table_name = tableNm == v:null ? '' : tableNm
    let bufname = 'Tables_' . s:getuser(s:params[a:port]) . '_' . a:port
    let bufnr = s:bufnr(bufname)

    if s:f.getwidCurrentTab(bufnr) == -1
        let bufnr = s:newBuffer(bufname)
        call add(s:bufferList,bufnr)
        call s:nmap(get(g:,'dbiclient_nmap_table_SQ',s:nmap_table_SQ), ':<C-u>call <SID>selectTableOfList(<SID>getTableNameSchem(<SID>getPort()),<SID>getPort())<CR>')
        call s:nmap(get(g:,'dbiclient_nmap_table_CT',s:nmap_table_CT), ':<C-u>call <SID>count(<SID>getTableNameSchem(<SID>getPort()),<SID>getPort())<CR>')
        call s:nmap(get(g:,'dbiclient_nmap_table_TW',s:nmap_table_TW), ':<C-u>call <SID>userTables(b:dbiclient_bufmap.alignFlg ,input("TABLE_NAME:",get(<SID>getParams(),"table_name","")) ,get(<SID>getParams(),"tabletype","")                        ,<SID>getPort())<CR>')
        call s:nmap(get(g:,'dbiclient_nmap_table_TT',s:nmap_table_TT), ':<C-u>call <SID>userTables(b:dbiclient_bufmap.alignFlg ,get(<SID>getParams(),"table_name","")                        ,input("TABLE_TYPE:",get(<SID>getParams(),"tabletype","")) ,<SID>getPort())<CR>')
    else
        call s:f.noreadonly(bufnr)
        call s:deletebufline(bufnr,1,'$')
        call setbufvar(bufnr,'dbiclient_bufmap',{})
        call setbufvar(bufnr,'dbiclient_col_line',0)
        call setbufvar(bufnr,'dbiclient_header',[])
        call setbufvar(bufnr,'dbiclient_lines',[])
        call setbufvar(bufnr,'dbiclient_matches',[])
    endif

    let opt = {
                \'noaddhistory'   : 1
                \,'nosql'         : 1
                \,'notablenm'     : 1
                \,'nocols'        : 0
                \,'table_info'    : 1
                \,'linesep'       : ' '
                \,'tabletype'     : tabletype
                \,'table_name'    : tableNm
                \,'reloadBufname' : bufname
                \,'reloadBufnr'   : bufnr}
    call s:appendbufline(bufnr,'$',['Now loading...'])
    call s:f.gotoWin(bufnr)
    call s:getQueryAsync('',s:callbackstr(a:alignFlg),-1,opt,a:port)
endfunction

function! s:getColumnsTableRemarks(data) abort
    let data = a:data

    if !empty(data)
        let itemmap = s:f2.Foldl({x,y -> extend(x,y)}, {}, map(data,{_,x -> empty(trim(get(x,'REMARKS',''))) ? {} : {get(x,'COLUMN_NAME','') : get(x,'REMARKS','')}}))
        call filter(map(itemmap,{k,v -> v==v:null ? '' : v}),{_,x -> !empty(trim(x))})
    else
        let itemmap={}
    endif
    "echom string(itemmap)
    return itemmap
endfunction

function! s:getTableRemarks(data) abort
    let data = a:data

    if !empty(data)
        let itemmap = s:f2.Foldl({x,y -> extend(x,y)}, {}, map(data,{_,x -> empty(trim(get(x,'REMARKS',''))) ? {} : {get(x,'TABLE_NAME','') : get(x,'REMARKS','')}}))
    else
        let itemmap={}
    endif
    return itemmap
endfunction

function! s:selectColumnsTable(alignFlg,wordFlg,table) abort
    if trim(a:table) != ''
        let table = trim(a:table)
    else
        if a:wordFlg
            let table = matchstr(expand('<cWORD>'),'\v(\w|[$#.])+')
        else
            let table = join(s:f.getRangeCurList(getpos("'<"), getpos("'>")))
        endif
    endif
    call s:selectColumnsTableCmn(a:alignFlg,table)
endfunction

function! s:selectColumnsTableCmn(alignFlg,table,...) abort
    let port = s:getCurrentPort()
    if empty(trim(a:table))
        return
    endif
    let table = a:table
    let ymdhms = strftime("%Y%m%d%H%M%S",localtime())
    let bufname = 'Columns_' . s:getuser(s:params[port]) . '_'  . port . '_' . ymdhms
    let bufnr = s:bufnr(bufname)
    let opt = {
                \'noaddhistory'   : 1
                \,'nosql'         : 1
                \,'notablenm'     : 1
                \,'column_info'   : 1
                \,'tableNm'       : table
                \,'reloadBufname' : bufname
                \,'reloadBufnr'   : bufnr}
    call s:getQueryAsync('',s:callbackstr(a:alignFlg),-1,opt,port)
endfunction

function! s:selectValues(selectdict) abort
    let bufnr = s:bufnr('%')
    let selectdictAscDesc = getbufvar(bufnr,'selectdictAscDesc',0)
    let list = sort(items(a:selectdict),{x,y -> x[1] == y[1] ? 0 : x[1] > y[1] ? 1 : -1})
    return map(map(list,{_,x->[x[1],x[0]]}),{_,x-> ((strdisplaywidth(x[1]) == len(x[1]) && trim(x[1]) !~ ' ') ? x[1] : '"' . x[1] . '"') . (selectdictAscDesc[x[1]] ? ' DESC' : '')})
endfunction

function! s:SelectLines(orderFlg) range abort
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

function! s:SelectLineOrder(line) abort
    if s:isDisableline()
        return
    endif
    let bufnr = s:bufnr('%')
    let line = a:line
    let matchadds=[]
    call add(matchadds,['Comment','\v^(\[ASC\]|\[DESC\]).*'])
    let str = getbufline(bufnr,line)[0]
    let selectdict = getbufvar(bufnr,'selectdict',{})
    let selectdictAscDesc = getbufvar(bufnr,'selectdictAscDesc',{})
    let selectdictstr = getbufvar(bufnr,'selectdictstr',{})
    if str !~ '\v^(\[ASC\]|\[DESC\])'
        let selectdict[str] = max(selectdict)+1
        let selectdictAscDesc[str] = 0
        let selectdictstr[str] = '[ASC]' . selectdict[str] . ' ' . str
    elseif str =~ '^\[ASC\]'
        let str = substitute(str,'\v^(\[ASC\]|\[DESC\])+[0-9]+\s','','')
        let selectdictAscDesc[str] = 1
        let selectdictstr[str] = '[DESC]' . selectdict[str] . ' ' . str
    else
        let str = substitute(str,'\v^(\[ASC\]|\[DESC\])+[0-9]+\s','','')
        call remove(selectdict,str)
        call remove(selectdictstr,str)
        call remove(selectdictAscDesc,str)
        let selectdict_tmp={}
        let i = 1
        for [key,val] in sort(items(selectdict),{x,y -> x[1] == y[1] ? 0 : x[1] > y[1] ? 1 : -1})
            let selectdict_tmp[key]=i
            let selectdictstr[key] = substitute(selectdictstr[key],'\v^(\[ASC\]|\[DESC\])+\zs[0-9]+\ze\s',i,'')
            let i+=1
        endfor
        let selectdict = selectdict_tmp
    endif
    let save_cursor = getcurpos()
    call s:f.noreadonly(bufnr)

    let lines = getbufline(bufnr,1,'$')
    call s:deletebufline(bufnr,1,'$')
    call s:appendbufline(bufnr,'$',map(lines, {_,x -> substitute(x,'\v^(\[ASC\]|\[DESC\])+[0-9]+\s','','')}))
    for [key,val] in items(selectdictstr)
        call s:setbufline(bufnr,searchpos('^' . key . '$','cn')[0],val)
    endfor
    call s:f.readonly(bufnr)
    call setbufvar(bufnr,'dbiclient_matches',matchadds)
    call setbufvar(bufnr,'selectdict',selectdict)
    call setbufvar(bufnr,'selectdictstr',selectdictstr)
    call setbufvar(bufnr,'selectdictAscDesc',selectdictAscDesc)
    call s:sethl(bufnr)
    call setpos('.', save_cursor)
endfunction

function! s:SelectLine(line) abort
    if s:isDisableline()
        return
    endif
    let bufnr = s:bufnr('%')
    let line = a:line
    let matchadds=[]
    call add(matchadds,['Comment','^[*].*'])
    let str = getbufline(bufnr,line)[0]
    let selectdict = getbufvar(bufnr,'selectdict',{})
    let selectdictAscDesc = getbufvar(bufnr,'selectdictAscDesc',{})
    let selectdictstr = getbufvar(bufnr,'selectdictstr',{})
    if str !~ '^[*]'
        let selectdict[str] = max(selectdict)+1
        let selectdictAscDesc[str] = 0
        let selectdictstr[str] = '*' . selectdict[str] . ' ' . str
    else
        let str = substitute(str,'\v^[*]+[0-9]+\s','','')
        call remove(selectdict,str)
        call remove(selectdictstr,str)
        call remove(selectdictAscDesc,str)
        let selectdict_tmp={}
        let i = 1
        for [key,val] in sort(items(selectdict),{x,y -> x[1] == y[1] ? 0 : x[1] > y[1] ? 1 : -1})
            let selectdict_tmp[key]=i
            let selectdictstr[key] = substitute(selectdictstr[key],'\v^[*]+\zs[0-9]+\ze\s',i,'')
            let i+=1
        endfor
        let selectdict = selectdict_tmp
    endif
    let save_cursor = getcurpos()
    call s:f.noreadonly(bufnr)
    let lines = getbufline(bufnr,1,'$')
    call s:deletebufline(bufnr,1,'$')
    call s:appendbufline(bufnr,'$',map(lines, {_,x -> substitute(x,'\v^[*]+[0-9]+\s','','')}))
    for [key,val] in items(selectdictstr)
        call s:setbufline(bufnr,searchpos('^' . key . '$','cn')[0],val)
    endfor
    call s:f.readonly(bufnr)
    call setbufvar(bufnr,'dbiclient_matches',matchadds)
    call setbufvar(bufnr,'selectdict',selectdict)
    call setbufvar(bufnr,'selectdictstr',selectdictstr)
    call setbufvar(bufnr,'selectdictAscDesc',selectdictAscDesc)
    call s:sethl(bufnr)
    call setpos('.', save_cursor)
endfunction

function! s:selectExtends(bufname,orderflg,dict) abort
    let bufname = a:bufname
    let curbufnr = s:bufnr('%')
    let matchadds=[]
    call add(matchadds,['Comment','^[*].*'])
    call add(matchadds,['Comment','\v^(\[ASC\]|\[DESC\]).*'])
    let dbiclient_bufmap = getbufvar(curbufnr,'dbiclient_bufmap',{})
    let opt = get(dbiclient_bufmap,'opt',{})
    let precols = get(opt,'precols',[])
    if has_key(a:dict,'selectdict')
        let list=[]
        for key in copy(empty(precols) ? get(dbiclient_bufmap,'cols',[]) : precols)
            call add(list, get(a:dict.selectdictstr, key, key))
        endfor
    else
        let list = map(copy(empty(precols) ? get(dbiclient_bufmap,'cols',[]) : precols),{_,x -> x})
    endif
    let bufnr = s:newBuffer(bufname)
    call s:appendbufline(bufnr,0,list)
    if a:orderflg
        call s:nmap('<SPACE>', ':<C-u>call <SID>SelectLineOrder(line("."))<CR>')
        call s:vmap('<SPACE>', ':call <SID>SelectLines(1)<CR>')
    else
        call s:nmap('<SPACE>', ':<C-u>call <SID>SelectLine(line("."))<CR>')
        call s:vmap('<SPACE>', ':call <SID>SelectLines(0)<CR>')
    endif
    call s:f.readonly(bufnr)
    call setbufvar(bufnr,'dbiclient_matches',matchadds)
    call setbufvar(bufnr,'selectdict',get(a:dict,'selectdict',{}))
    call setbufvar(bufnr,'selectdictstr',get(a:dict,'selectdictstr',{}))
    call setbufvar(bufnr,'selectdictAscDesc',get(a:dict,'selectdictAscDesc',{}))
    call s:sethl(bufnr)
    norm gg
endfunction

function! s:isDisableline(...) abort
    let bufnr = s:bufnr('%')
    let disableline = getbufvar(bufnr,'disableline',[])

    for dl in disableline
        if mode() == 'n'
             if line('.') == dl
                 return 1
             endif
         elseif mode() == 'v' || mode() == 'V'
             for line in range(a:1,a:2)
                 if line == dl
                     return 1
                 endif
             endfor
         endif
    endfor
    return 0
endfunction

function! s:deletebuflineOfFilter(bufnr,regex) abort
    "let old_undolevels = &undolevels
    "setl undolevels=-1
    for line in reverse(filter(range(1,s:endbufline(a:bufnr)),{_,line -> getbufline(a:bufnr,line)[0] =~ a:regex}))
        call deletebufline(a:bufnr, line, line)
    endfor
    "let &undolevels = old_undolevels
endfunction

function! s:deletebufline(bufnr,first,last) abort
    "let old_undolevels = &undolevels
    "setl undolevels=-1
    call deletebufline(a:bufnr, a:first,a:last)
    "let &undolevels = old_undolevels
endfunction

function! s:setbufline(bufnr,line,str) abort
    "let old_undolevels = &undolevels
    "setl undolevels=-1
    call setbufline(a:bufnr,a:line,a:str)
    "let &undolevels = old_undolevels
endfunction

function! s:endbufline(bufnr) abort
    let winid = s:f.getwid(a:bufnr)
    return line('$',winid)
endfunction

function! s:appendbufline(bufnr,line,list,...) abort
    let winid = s:f.getwid(a:bufnr)
    "let old_undolevels = &undolevels
    "setl undolevels=-1
    call appendbufline(a:bufnr,a:line,a:list)
    if getbufline(a:bufnr,'$')[0] == ''
        call s:deletebufline(a:bufnr,s:endbufline(a:bufnr),s:endbufline(a:bufnr))
    endif
    if getbufline(a:bufnr,1)[0] == ''
        call s:deletebufline(a:bufnr,1,1)
    endif
    "silent! call s:deletebuflineOfFilter(a:bufnr, '^$')
    "let &undolevels = old_undolevels
    let matchadds=[]
    if a:0 == 1
        for val in a:list
            call add(matchadds,[a:1,'\v%' . (s:endbufline(a:bufnr)) . 'l' . '^\V'.escape(val,'/') . '\v$'])
        endfor
    endif
    return matchadds
endfunction

function! s:readfile(file) abort
    if filereadable(a:file)
        let lines = readfile(a:file)
    else
        let lines = []
    endif
    return lines
endfunction

function! s:tempname() abort
    let logpath = s:getRootPath()
    let ymdhmss = strftime("%Y%m%d%H%M%S",localtime()) . reltime()[1][-4:] . split(reltimestr(reltime()),'\.')[1]
    let temp = s:Filepath.join(s:getRootPath(),'data/' . ymdhmss . '.dat')
    if !isdirectory(fnamemodify(temp,':p:h'))
        call mkdir(fnamemodify(temp,':p:h'), 'p')
    endif
    return temp
    "return tempname()
endfunction

function! s:getconninfo(dict) abort
    let ret = get(get(a:dict,'data',{}),'connInfo',{})
    return ret
endfunction

function! s:getdsn(dsn) abort
    let dsn = substitute(a:dsn,'\v(\r\n|\r|\n)+','','g')
    return len(dsn) > 100 ? (dsn[:100] . '...') : dsn
endfunction

function! s:getuser(connInfo) abort
    let connInfo = a:connInfo
    let ret  = get(connInfo,'user',v:null)
    return empty(ret) || ret == v:null ? 'NOUSER' : ret
endfunction

function! s:getprelinesep() abort
    return g:dbiclient_prelinesep
endfunction

function! s:getPort() abort
    let bufnr = s:bufnr('%')
    let dbiclient_bufmap = getbufvar(bufnr,'dbiclient_bufmap',{})
    let connInfo = s:getconninfo(dbiclient_bufmap)
    let port = get(connInfo,'port',s:dbi_job_port)
    return port
endfunction

function! s:getCurrentPort() abort
    return s:dbi_job_port
endfunction

function! s:getLimitrows() abort
    return get(s:params,'limitrows',s:limitrows)
endfunction

function! s:newBuffer(bufname,...) abort
    let bufnr = s:f.newBuffer(a:bufname,g:dbiclient_new_window_hight,g:dbiclient_buffer_encoding,0)
    call setbufvar(bufnr,'&filetype','dbiclient')
    return bufnr
endfunction

function! s:peditBuffer(bufname,...) abort
    let bufnr = s:f.newBuffer(a:bufname,g:dbiclient_new_window_hight,g:dbiclient_buffer_encoding,g:dbiclient_previewwindow)
    call setbufvar(bufnr,'&filetype','dbiclient')
    return bufnr
endfunction

function! s:bufnr(bufname) abort
    if empty(a:bufname)
        return -1
    else
        return bufnr(a:bufname)
    endif
endfunction

function! s:Tuple(a,b) abort
    let s:ret = {}
    function! s:ret.Get1() closure abort
        return copy(a:a)
    endfunction
    function! s:ret.Get2() closure abort
        return copy(a:b)
    endfunction
    return s:ret
endfunction

function! s:sethl(bufnr) abort
    "echom 'sethl ' . a:bufnr
    let bufnr = a:bufnr
    let winidList = s:f.getwidlist(bufnr)
    for winid in winidList
        let w_dbiclient_matches = getwinvar(winid,'w_dbiclient_matches',[])
        if !empty(w_dbiclient_matches)
            silent! call map(w_dbiclient_matches,{_,x -> matchdelete(x,winid)})
            let w_dbiclient_matches = []
        endif
        call setwinvar(winid,'w_dbiclient_matches',w_dbiclient_matches)
        "echom 'delete ' . winid
    endfor
    let dbiclient_matches = getbufvar(bufnr,'dbiclient_matches',[])
    for winid in winidList
        if getwinvar(winid,'&filetype','') == 'dbiclient'
            let w_dbiclient_matches = []
            for x in dbiclient_matches
                call add(w_dbiclient_matches,matchadd(x[0],x[1],0,-1,{'window' : winid}))
            endfor
            call setwinvar(winid,'w_dbiclient_matches',w_dbiclient_matches)
            "echom 'create ' . winid
        endif
    endfor
endfunction


function! s:init() abort
    if s:loaded == 0
        if !isdirectory(s:getRootPath())
            call mkdir(s:getRootPath())
        endif
        let path = s:Filepath.join(s:getRootPath() , 'channellog.log')
        if g:dbiclient_debugflg
            "call ch_logfile(path, 'w')
        endif
        if s:getRootPath() == "" || !isdirectory(s:getRootPath())
            call s:echoMsg('EO11',s:getRootPath())
            return 0
        endif
        if s:getPerlmPath() == "" || !filereadable(s:getPerlmPath())
            call s:echoMsg('EO12',s:getPerlmPath())
            return 0
        endif
        let logpath = s:getRootPath()
        if !isdirectory(logpath)
            call mkdir(logpath)
        endif
        call s:deleteHistoryAllCmd()
        call s:zonbie()
    endif
    let s:loaded = 1
endfunction

function! s:zonbie()
    for file in split(glob(s:Filepath.join(s:getRootPath(),'*.lock')),"\n")
        let port = fnamemodify(file,':p:t:r')
        let channel = ch_open('localhost:' . port)
        if s:ch_statusOk(channel)
            sandbox let s:params[port] = eval(join(readfile(file)))
            "let s:jobs[port] = ch_getjob(channel)
            "echom 'ch_getjob'
            "echom s:jobs[port]
        else
            call delete(file)
        endif
        if ch_status(channel) == 'open'
            call ch_close(channel)
        endif
    endfor
endfunction

function! s:ch_statusStrOk(str) abort
    if a:str == 'open' || a:str == 'buffered'
        return 1
    else
        return 0
    endif
endfunction

function! s:ch_statusOk(channel) abort
    return s:ch_statusStrOk(ch_status(a:channel))
endfunction

function! s:input(prompt,...) abort
    let default = get(a:,1,'')
    echohl WarningMsg
    echom a:prompt . default
    echohl None
    let str = str2list(default)
    let c = ''
    while 1
        let c = getchar()
        if c == '27' || c == '13'
            break
        elseif c == '<BS>'
            if len(str) > 0
                call remove(str,-1)
            endif
        else
            call add(str, c)
        endif
    endwhile
    if c == '13'
        return list2str(str)
    else
        return ''
    endif
endfunction

function! s:ch_open2status(port) abort
    if len(filter(s:sendexprList[:],{_,x -> x[0] == a:port})) > 0
        let ret = 'open'
    else
        let ch = ch_open('localhost:' . a:port)
        let ret = ch_status(ch)
        if ret == 'open'
            call ch_close(ch)
        endif
    endif
    "let ret='open'
    return ret
endfunction

augroup BufEnterDbiClient
    autocmd WinNew,BufEnter * call s:sethl(bufnr('%'))
augroup END

augroup dbiclient
    au!
    autocmd VimLeavePre * :call s:jobStopAll()
augroup END

let &cpo = s:cpo_save
unlet s:cpo_save

" vim:fdm=marker:nowrap:ts=4:expandtab:
