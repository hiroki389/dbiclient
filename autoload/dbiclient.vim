scriptencoding utf-8

if !exists('g:loaded_dbiclient')
    finish
endif

let s:cpo_save = &cpo
set cpo&vim


let s:f=dbiclient#funclib#new()
let s:Filepath = vital#dbiclient#new().import('System.Filepath')
let s:Stream = vital#dbiclient#new().import('Stream')
let s:get_query_owner=""
let s:dbi_job_port=0
let s:SINGLE_QUOTES1="'"
let s:SINGLE_QUOTES2="''"
let s:limitrows=1000
let s:jobs={}
let s:params={}
let s:msg={
            \ 'EO01':'The specified buffer was not found.'
            \,'EO02':'The specified file($1) was not found.'
            \,'EO03':'The specified table($1) was not found.'
            \,'EO04':'A database error has occurred.($1)'
            \,'IO05':'$1'
            \,'IO07':'Please connect to the database.'
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
            \}

let s:connect_opt_gotowinlastbuf='connect_opt_gotowinlastbuf'
let s:connect_opt_table_name='connect_opt_table_name'
let s:connect_opt_table_type='connect_opt_table_type'
let s:connect_opt_primarykeyflg='connect_opt_primarykeyflg'
let s:connect_opt_envdict='connect_opt_envdict'

function! s:debugLog(msg)
    if g:dbiclient_debugflg
        let datetime=strftime("%Y/%m/%d %H:%M:%S")
        echom datetime . ' ' . string(a:msg)
    endif
endfunction
function! dbiclient#loadQueryHistory()
    let sqlpath=s:getHistoryPath()
    if !filereadable(sqlpath)
        return []
    endif
    let sqllist=readfile(sqlpath)
    let list=map(sqllist,{_,x->substitute(x,'\V{DELIMITER_CR}',"\n",'g')})
    return list
endfunction
function! dbiclient#loadQueryHistoryDo()
    let sqlpath=s:getHistoryPathDo()
    if !filereadable(sqlpath)
        return []
    endif
    let sqllist=readfile(sqlpath)
    let list=map(sqllist,{_,x->substitute(x,'\V{DELIMITER_CR}',"\n",'g')})
    return list
endfunction
function! s:getHistoryPath()
    let sqlpath=s:Filepath.join(s:getRootPath(),"history_" . get(get(s:params,s:dbi_job_port,{}),'dsn','') . '_' . (s:get_query_owner == v:null || empty(s:get_query_owner) ? 'NOUSER' : s:get_query_owner))
    return sqlpath
endfunction
function! s:getHistoryPathDo()
    let sqlpath=s:Filepath.join(s:getRootPath(),"history_do_" . get(get(s:params,s:dbi_job_port,{}),'dsn','') . '_' . (s:get_query_owner == v:null || empty(s:get_query_owner) ? 'NOUSER' : s:get_query_owner))
    return sqlpath
endfunction
function! s:getRootPath()
    return g:dbiclient_rootPath
endfunction
function! s:getPerlmPath()
    return g:dbiclient_perlmPath
endfunction
function! dbiclient#sqllog()
    let ymd= strftime("%Y%m%d", localtime())
    let logfile= 'socket_' . ymd . '.log'
    bo new
    exe 'e ' . s:Filepath.join(s:getRootPath(),logfile)
endfunction
function! s:error1()
    if !has_key(s:jobs,s:dbi_job_port) || get(s:params[s:dbi_job_port],'connect',9) != 1
        call s:echoMsg('IO07',s:dbi_job_port)
        return 1
    endif
    if job_status(s:jobs[s:dbi_job_port]) != "run"
        call s:echoMsg('EO04',s:dbi_job_port,job_status(s:jobs[s:dbi_job_port]))
        return 1
    endif
    return 0
endfunction
function! s:error2()
    if bufname('%') == 'Tables' || bufname('%') =~# 'Columns'
        call s:echoMsg('EO17')
        return 1
    endif
    if !exists('b:bufmap') || empty(get(b:bufmap,"cols",[]))
        call s:echoMsg('EO01')
        return 1
    endif
    return 0
endfunction
function! s:error4()
    if !exists('b:bufmap') || empty(get(b:bufmap,"cols",[]))
        call s:echoMsg('EO01')
        return 1
    endif
    return 0
endfunction
function! s:error3()
    if bufname('%') == 'Tables' || bufname('%') =~# 'Columns'
        call s:echoMsg('EO17')
        return 1
    endif
    if !exists('b:bufmap') || empty(get(b:bufmap,"cols",[]))
        call s:echoMsg('EO01')
        return 1
    endif
    if b:bufmap.data.tableJoinNm =~ ' '
        call s:echoMsg('EO10')
        return 1
    endif
    "if b:bufmap.alignFlg==1
    "    call s:echoMsg('EO16')
    "    return 1
    "endif
    return 0
endfunction
function! s:getTableName(sql,table)
    if a:table == v:null || !empty(a:table)
        return a:table
    endif
    let table=matchstr(substitute(a:sql,"[\r\n]",' ','g'),'\v\c[ \t]+from[ \t]+\zs([[:alnum:]_$]+)\ze')
    if table==""
        return 'NONAME'
    else
        return substitute(table,'[ \t;:/]','','g')
    endif
endfunction
function! s:getTableJoinList(sql)
    let suba=substitute(a:sql,'[\r\n]',' ','g')
    let suba=substitute(suba,'\v\c[ \t]+%(from|join)[ \t]+[[:alnum:]_$]+\zs','\n','g')
    let table=dbiclient#funclib#List(s:split(suba,"\n")).matchstr('[ \t]*%(from|join)[ \t]+\zs([[:alnum:]_$]+)\ze').value()
    if empty(table)
        return ['NONAME']
    else
        return table
    endif
endfunction
function! dbiclient#getPrimaryKeys(tablename)
    let opt={'tableNm':a:tablename,'column_info':1}
    return get(dbiclient#getQuery('',-1,opt),'primary_key',[])
endfunction
function! dbiclient#getResultList(fileNm)
    let ret = {}
    let file = readfile(a:fileNm)
    let cols=get(file,1,[])
    let val=dbiclient#funclib#List(file[2:]).filter({x->!empty(x)}).fmap({xs->s:f.zip(s:split(cols,g:dbiclient_col_delimiter),s:split(xs,g:dbiclient_col_delimiter))})
    return val
endfunction
function! s:createInsertRange() range
    function! s:createInsert(keys,vallist,tableNm)
        if a:tableNm==""
            return []
        endif
        let result=[]
        let cols=join(a:keys,",")
        for record in a:vallist
            let res  = "INSERT INTO "
            let res .= a:tableNm
            let res .= "("
            let res .= cols
            let res .= ")VALUES("
            let collist=s:split(record,g:dbiclient_col_delimiter)
            let collist=map(collist,{_,x->s:trim_surround(x)})
            call add(result,res . join(map(collist,{_,xs->s:SINGLE_QUOTES1 . substitute(xs,s:SINGLE_QUOTES1,s:SINGLE_QUOTES2,'g') . s:SINGLE_QUOTES1}),",") . ");")
        endfor
        return result
    endfunction
    if s:isDisableline(a:firstline, a:lastline)
        return
    endif
    if s:error3()
        return
    endif
    let list = getline(a:firstline, a:lastline)
    if b:bufmap.alignFlg==1
        let list = map(list,{_,line->join(map(split(line,g:dbiclient_col_delimiter_align),{_,x->trim(x)}),g:dbiclient_col_delimiter)})
    endif
    if empty(list)
        return
    endif
    let bufname="CreateInsert"
    let cols=b:bufmap.cols
    let tableNm=b:bufmap.data.tableNm
    if s:f.gotoWin(bufname) == -1
        call s:f.newBuffer(bufname,g:dbiclient_new_window_hight,g:dbiclient_buffer_encoding)
    endif
    call s:clearbuf()
    call s:append('$', s:createInsert(cols,list,tableNm))
    call s:gotoLastWin()
endfunction
function s:trim_surround(val)
    if !empty(g:dbiclient_surround)
        return substitute(substitute(a:val,'^\V' . g:dbiclient_surround, '',''),'\V' . g:dbiclient_surround . '\v$', '','')
    else
        return a:val
    endif
endfunction
function! s:createUpdateRange(bang) range
    function! s:createUpdate(vallist,tableNm,refresh)
        let keys=dbiclient#getPrimaryKeys(a:tableNm)
        if a:tableNm==""
            return []
        endif
        let result=[]
        for items in a:vallist
            let dict = dbiclient#funclib#List(items).foldl({x->{x[0]:substitute(x[1],s:SINGLE_QUOTES1 ,s:SINGLE_QUOTES2,'g')}},{}).value()
            let res  = "UPDATE ".a:tableNm." SET "
            let collist=dbiclient#funclib#List(items).foldl({item->',' . item[0] . ' = ' . s:SINGLE_QUOTES1 . s:trim_surround(item[1]) . s:SINGLE_QUOTES1},[]).value()
            let setval = join(collist)
            let res  .= substitute(setval,'^,','','')
            if(len(keys)>0)
                let res .= {key->' WHERE ' . key . ' = ' . s:SINGLE_QUOTES1 . s:trim_surround(get(dict,key,'<*>')) . s:SINGLE_QUOTES1}(keys[0])
                let res .= join(dbiclient#funclib#List(keys[1:]).foldl({key->'  AND ' . key . ' = ' . s:SINGLE_QUOTES1 . s:trim_surround(get(dict,key,'<*>')) . s:SINGLE_QUOTES1},[]).value())
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
    if s:error3()
        return
    endif
    let list = getline(a:firstline, a:lastline)
    if b:bufmap.alignFlg==1
        let list = map(list,{_,line->join(map(split(line,g:dbiclient_col_delimiter_align),{_,x->trim(x)}),g:dbiclient_col_delimiter)})
    endif
    if empty(list)
        return
    endif
    let bufname="CreateUpdate"
    let cols=b:bufmap.cols
    let tableNm=b:bufmap.data.tableNm
    if s:f.gotoWin(bufname) == -1
        call s:f.newBuffer(bufname,g:dbiclient_new_window_hight,g:dbiclient_buffer_encoding)
    endif
    call s:clearbuf()
    let param=dbiclient#funclib#List(list).foldl({x->s:f.zip(cols,s:split(x,g:dbiclient_col_delimiter))},[]).value()
    call s:append('$', s:createUpdate(param,tableNm,a:bang=='!'))
    call s:gotoLastWin()
endfunction
function! s:createDeleteRange(bang) range
    function! s:createDelete(vallist,tableNm,refresh)
        let keys=dbiclient#getPrimaryKeys(a:tableNm)
        if a:tableNm==""
            return []
        endif
        let result=[]
        for items in a:vallist
            let dict = dbiclient#funclib#List(items).foldl({x->{x[0]:x[1]}},{}).value()
            let res  = "DELETE FROM ".a:tableNm
            if(len(keys)>0)
                let res .= {key->' WHERE ' . key . ' = ' . s:SINGLE_QUOTES1 . s:trim_surround(get(dict,key,'<*>')) . s:SINGLE_QUOTES1}(keys[0])
                let res .= join(dbiclient#funclib#List(keys[1:]).foldl({key->'  AND ' . key . ' = ' . s:SINGLE_QUOTES1 . s:trim_surround(get(dict,key,'<*>')) . s:SINGLE_QUOTES1},[]).value())
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
    if s:error3()
        return
    endif
    let list = getline(a:firstline, a:lastline)
    if b:bufmap.alignFlg==1
        let list = map(list,{_,line->join(map(split(line,g:dbiclient_col_delimiter_align),{_,x->trim(x)}),g:dbiclient_col_delimiter)})
    endif
    if empty(list)
        return
    endif
    let bufname="CreateDelete"
    let cols=b:bufmap.cols
    let tableNm=b:bufmap.data.tableNm
    if s:f.gotoWin(bufname) == -1
        call s:f.newBuffer(bufname,g:dbiclient_new_window_hight,g:dbiclient_buffer_encoding)
    endif
    call s:clearbuf()
    let param=dbiclient#funclib#List(list).foldl({x->s:f.zip(cols,s:split(x,g:dbiclient_col_delimiter))},[]).value()
    call s:append('$', s:createDelete(param,tableNm,a:bang=='!'))
    call s:gotoLastWin()
endfunction
function! dbiclient#joblist()
    function! s:dbinfo(port)
        let info= ''
        let info= info . 'INFO:[DBD=' . get(s:params[a:port],'dsn','') . ']'
        let info= info . '[SCHEMA=' . s:getuser() . ']'
        return info
    endfunction
    let list=map(keys(s:jobs),{_,x->x . ' ' . s:dbinfo(x)})
    if empty(list)
        return
    endif
    call s:f.newBuffer('JOBS',g:dbiclient_new_window_hight,g:dbiclient_buffer_encoding)
    call s:append(0,list)
    call s:f.readonly()
    norm gg
    nmap <buffer> <nowait> <silent> <CR> :<C-u>call dbiclient#chgjob(matchstr(getline("."),'\v^\w+'))<CR>:quit<CR>
endfunction
function! dbiclient#chgjob(port)
    if !has_key(s:jobs,a:port)
        return
    endif
    let s:get_query_owner = get(s:params[a:port],'user','')
    let s:limitrows = get(s:params[a:port],'limitrows','')
    let s:dbi_job_port = a:port
    call dbiclient#jobStat()
endfunction
function! dbiclient#jobNext()
    let breakflg=0
    let port=get(sort(keys(s:jobs)),0,-1)
    if port == -1
        return
    endif
    for key in sort(keys(s:jobs))
        if breakflg
            let port = key
            break
        endif
        if port == s:dbi_job_port
            let breakflg=1
        endif
    endfor
    call dbiclient#chgjob(port)
endfunction
function! dbiclient#connect(port,dsn,user,pass,limitrows,encoding,...) abort
    let opt = get(a:,1,{})
    function! s:cb_jobout(ch,dict) abort closure
        if a:dict == a:port
            call s:connect(a:dsn,a:user,a:pass,a:limitrows,a:encoding,opt)
        endif
    endfunction
    function! s:cb_joberr(ch,dict) abort closure
        echoerr iconv(string(a:dict),get(get(s:params,s:dbi_job_port,{}),'encoding',&enc),g:dbiclient_buffer_encoding)
    endfunction

    if has_key(s:jobs,s:dbi_job_port) && !empty(get(opt,s:connect_opt_envdict,{})) && !has_key(opt,'reconnect')
        let opt.reconnect=1
        let Exitcb={ch,dict->dbiclient#connect(a:port,a:dsn,a:user,a:pass,a:limitrows,a:encoding,opt)}
        call job_setoptions(s:jobs[s:dbi_job_port],{
                    \ 'exit_cb':Exitcb
                    \ })
        call dbiclient#jobStop(0)
        return
    endif
    call s:init()
    if a:port !~ '\v^[[0-9]+$'
        throw 'port error'
    endif
    if !has_key(s:jobs,a:port) && ch_status(ch_open('localhost:' . a:port)) != 'fail'
        call s:echoMsg('IO18',a:port)
        return
    endif
    if has_key(s:jobs,a:port) && ch_status(ch_open('localhost:' . a:port)) != 'fail'
        if get(get(s:params,s:dbi_job_port,{}),'connect',9) == 1
            let c=dbiclient#close()
        endif
        call s:connect(a:dsn,a:user,a:pass,a:limitrows,a:encoding,opt)
    else
        let logpath=s:getRootPath()
        let cmdlist=['perl', s:getPerlmPath() ,a:port,logpath,g:dbiclient_perl_binmode]
        call s:debugLog(join(cmdlist,' '))
        let s:dbi_job_port = a:port
        if has_key(opt,'reconnect')
            let opt.reconnect=1
        endif
        let s:jobs[s:dbi_job_port] = job_start(cmdlist,{
                    \  'err_cb':funcref('s:cb_joberr')
                    \ ,'out_cb':funcref('s:cb_jobout')
                    \ })

        let s:params[s:dbi_job_port]={}
        let s:params[s:dbi_job_port].port=s:dbi_job_port
    endif
    "call dbiclient#jobStat()
endfunction
function! dbiclient#jobStat()
    call s:debugLog(s:params[s:dbi_job_port])
    if has_key(s:jobs,s:dbi_job_port)
        let msg ='Connection Info:[STATUS=' . job_status(s:jobs[s:dbi_job_port]) . ']'
        let msg .='[PORT=' . s:dbi_job_port . ']'
        let msg .='[SCHEMA=' . s:getuser() . ']'
        let msg .='[LIMIT=' . get(s:params[s:dbi_job_port],'limitrows','') . ']'
        call s:echoMsg('IO05', msg)
    else
        call s:echoMsg('IO07')
    endif
endfunction
function! dbiclient#Kill_job()
    if empty(s:jobs)
        return 0
    endif
    call job_stop(s:jobs[s:dbi_job_port])
    call remove(s:jobs,s:dbi_job_port)
    call s:echoMsg('IO08',s:dbi_job_port)
endfunction
function! dbiclient#jobStopAll()
    while dbiclient#jobStop(0)
    endwhile
endfunction
function! dbiclient#jobStop(msgflg)
    if empty(s:jobs)
        return 0
    endif
    if has_key(s:jobs,s:dbi_job_port)
        if get(get(s:params,s:dbi_job_port,{}),'connect',9) == 1
            let c=dbiclient#close()
        endif
        call job_stop(s:jobs[s:dbi_job_port])
        call remove(s:jobs,s:dbi_job_port)
        call remove(s:params,s:dbi_job_port)
        if a:msgflg
            call s:echoMsg('IO08',s:dbi_job_port)
        endif
        call dbiclient#jobNext()
    endif
    return 1
endfunction
function! dbiclient#cancel()
    if empty(s:jobs)
        return 0
    endif
    call job_stop(s:jobs[s:dbi_job_port], 'int')
endfunction
function! dbiclient#selectRangeSQL(bang,...) range
    if s:error1()
        return {}
    endif
    let limitrows=get(a:,1,s:limitrows)
    let list = s:f.getRangeCurList(getpos("'<"), getpos("'>"))
    if empty(list)
        return
    endif
    let i=0
    for sql in split(join(list,"\n"),'\v' . g:dbiclient_sql_delimiter1 .'\s*%(\n|$)')
        call dbiclient#getQueryAsync(sql,s:callbackstr(a:bang),limitrows,{})
        if i == 0
            sleep 1
        endif
        let i+=1
    endfor
endfunction

function! s:split(str,delim)
    "if a:str =~ a:delim . '$'
    return split(a:str,a:delim,'1')
    "else
    "    return split(a:str,a:delim)
    "endif
endfunction
function! s:echoMsg(id,...)
    let msg=get(s:msg,a:id)
    for i in range(a:0)
        let msg=substitute(msg,'\V$' . (i+1),a:000[i],'')
    endfor
    echom msg
endfunction

function! dbiclient#dBExecRangeSQLDoAuto() range
    let list = s:f.getRangeCurList(getpos("'<"), getpos("'>"))
    if empty(trim(join(list)))
        return
    endif
    if join(list, "\n") =~ '\v\n\s*' . g:dbiclient_sql_delimiter2 . '\s*%(\n|$)'
        let delim =g:dbiclient_sql_delimiter2
        let mode=2
    else
        let delim =g:dbiclient_sql_delimiter1
        let mode=1
    endif
    call dbiclient#dBExecRangeSQLDo(delim,mode)
endfunction
function! dbiclient#dBExecRangeSQLDo(delim, mode) range
    let list = s:f.getRangeCurList(getpos("'<"), getpos("'>"))
    if empty(trim(join(list)))
        return
    endif
    if a:mode == 2
        let delim = '\n\s*' . a:delim
        let delim2 = "\n" . a:delim
    else
        let delim = a:delim
        let delim2 = a:delim
    endif
    let sqllist =s:split(join(list,"\n"),'\v' . delim . '\s*%(\n|$)')
    call dbiclient#dBCommandAsync({"do":sqllist},'s:cb_do',delim2)
endfunction

function! dbiclient#getQuery(sql,limitrows,opt)
    if s:error1()
        return {}
    endif
    let tableNm = s:getTableName(a:sql,get(a:opt,'tableNm',''))
    let tableJoinNm = join(uniq(s:getTableJoinList(a:sql))," ")
    let channel = ch_open('localhost:' . s:dbi_job_port)
    if ch_status(channel) != 'open'
        echom 'channel:' . channel
        return {}
    endif
    let bufmap = get(a:opt,'bufmap',{})
    if empty(bufmap)
        let param = {
                    \"sql"          : a:sql
                    \,"tableNm"     : tableNm
                    \,"tableJoinNm" : tableJoinNm
                    \,"limitrows"   : a:limitrows
                    \,'linesep'     : g:dbiclient_linesep
                    \,'surround'    : g:dbiclient_surround
                    \,'null'        : g:dbiclient_null
                    \,'table_info'  : get(a:opt,'table_info',0)
                    \,'column_info' : get(a:opt,'column_info',0)
                    \,'tempfile'    : tempname()}
        let result=ch_evalexpr(channel, param , {"timeout":30000})
    else
        let data = b:bufmap.data
        let data.tempfile = tempname()
        let data.opt=a:opt
        let result=ch_evalexpr(channel, data , {"timeout":30000})
    endif
    if type(result)==v:t_dict
        call ch_close(channel)
        return result
    else
        call ch_close(channel)
        return {}
    endif
endfunction
function! dbiclient#getQuerySync(sql,callback,limitrows,opt)
    if s:error1()
        return
    endif
    let channel = dbiclient#getQueryAsync(a:sql,a:callback,a:limitrows,a:opt)
    while ch_status(channel) == "open"
        sleep 1
    endwhile
endfunction
function! dbiclient#getQueryAsync(sql,callback,limitrows,opt)
    function! s:callback2(c,m) closure
        call function(a:callback)(a:c,a:m)
    endfunction
    if s:error1()
        return {}
    endif
    if get(a:opt,'noaddhistory',0) == 0
        call writefile([join(split(a:sql,"\n"),"{DELIMITER_CR}")],s:getHistoryPath(),'a')
        call dbiclient#uniqHistory(dbiclient#loadQueryHistory(),[a:sql],s:getHistoryPath(),'')
    endif
    let sql = a:sql
    let tableNm = s:getTableName(a:sql,get(a:opt,'tableNm',''))
    let tableJoinNm =join(uniq(s:getTableJoinList(sql))," ")
    let channel = ch_open('localhost:' . s:dbi_job_port)
    if ch_status(channel) != 'open'
        echom 'channel:' . channel
        return channel
    endif
    let bufmap = get(a:opt,'bufmap',{})
    if empty(bufmap)
        let param = {
                    \"opt"          : a:opt
                    \,"sql"         : sql
                    \,"tableNm"     : tableNm
                    \,"tableJoinNm" : tableJoinNm
                    \,"limitrows"   : a:limitrows
                    \,'linesep'     : g:dbiclient_linesep
                    \,'surround'    : g:dbiclient_surround
                    \,'null'        : g:dbiclient_null
                    \,'table_info'  : get(a:opt ,'table_info' ,0)
                    \,'column_info' : get(a:opt ,'column_info' ,0)
                    \,'table_name'  : get(a:opt ,'table_name' ,v:null)
                    \,'tabletype'   : get(a:opt ,'tabletype' ,v:null)
                    \,'tempfile'    : tempname()}
        call ch_sendexpr(channel, param ,{"callback": funcref('s:callback2')})
    else
        let data = bufmap.data
        let data.tempfile=tempname()
        let data.opt=a:opt
        call ch_sendexpr(channel, data,{"callback": funcref('s:callback2')})
    endif
    return channel
endfunction
function! dbiclient#commit()
    call dbiclient#dBCommandAsync({"commit":"1"},'s:cb_do','')
endfunction
function! dbiclient#rollback()
    call dbiclient#dBCommandAsync({"rollback":"1"},'s:cb_do','')
endfunction
function! dbiclient#set(key,value)
    let ret=dbiclient#dBCommand({'setkey':a:key,'setvalue':a:value})
    return ret
endfunction
function! dbiclient#close()
    let ret=dbiclient#dBCommand({"close":"1"})
    let s:params[s:dbi_job_port].connect=0
    return ret
endfunction
function! s:connect(dsn,user,pass,limitrows,encoding,opt)
    let opt = a:opt
    let s:get_query_owner = empty(a:user) ? v:null : a:user
    let s:limitrows = a:limitrows
    if has_key(s:jobs,s:dbi_job_port)
        let s:params[s:dbi_job_port]={}
        let s:params[s:dbi_job_port].user=s:get_query_owner
        let s:params[s:dbi_job_port].limitrows=a:limitrows
        let s:params[s:dbi_job_port].port=s:dbi_job_port
        let s:params[s:dbi_job_port].encoding=a:encoding
        let s:params[s:dbi_job_port].gotowinlastbuf=get(opt,s:connect_opt_gotowinlastbuf,0)
        let s:params[s:dbi_job_port].dsn=matchstr(a:dsn,'\v\s*\zs\w+')
        let s:params[s:dbi_job_port].tabletype=get(opt,s:connect_opt_table_type,'')
        let s:params[s:dbi_job_port].table_name=get(opt,s:connect_opt_table_name,'')
        let command = {
                    \"datasource"     : substitute(a:dsn ,'\v^\s*','','')
                    \,'user'          : s:get_query_owner
                    \,'pass'          : a:pass
                    \,'limitrows'     : a:limitrows
                    \,'encoding'      : a:encoding
                    \,'table_name'    : get(opt,s:connect_opt_table_name,v:null)
                    \,'tabletype'     : get(opt,s:connect_opt_table_type,v:null)
                    \,'primarykeyflg' : get(opt,s:connect_opt_primarykeyflg,1)
                    \,'envdict'       : get(opt,s:connect_opt_envdict,{})
                    \ }
        let ret=s:dBCommandNoChk(command)
        let s:params[s:dbi_job_port].connect=get(ret,'status',9)
        if s:params[s:dbi_job_port].connect == 1
            call dbiclient#UserTables('!')
        endif
    else
        call s:echoMsg('IO19',s:dbi_job_port)
    endif
endfunction
function! s:dBCommandNoChk(command)
    let channel = ch_open('localhost:' . s:dbi_job_port)
    if ch_status(channel) != 'open'
        echom 'channel:' . channel
        return {}
    endif
    let command = a:command
    let command.tempfile = tempname()
    let result=ch_evalexpr(channel, command, {"timeout":60000})
    if type(result)==v:t_dict
        call ch_close(channel)
        return result
    else
        call ch_close(channel)
        return {}
    endif
endfunction
function! s:dBCommand(command)
    if s:error1()
        return {}
    endif
    return s:dBCommandNoChk(a:command)
endfunction
function! dbiclient#dBCommand(command)
    return s:dBCommand(a:command)
endfunction
function! dbiclient#dBCommandAsync(command,callback,delim)
    function! s:callback3(c,m) closure
        call function(a:callback)(a:c,a:m)
    endfunction
    if s:error1()
        return {}
    endif
    let hist=[]
    for sql in get(a:command,'do',[])[:]
        if trim(sql) != ''
            "let sql .= a:delim
            call add(hist,join(split(sql . a:delim,"\n"),"{DELIMITER_CR}"))
        endif
    endfor
    call writefile(hist,s:getHistoryPathDo(),'a')
    call dbiclient#uniqHistory(dbiclient#loadQueryHistoryDo(),get(a:command,'do',[]),s:getHistoryPathDo(),a:delim)
    let channel = ch_open('localhost:' . s:dbi_job_port)
    if ch_status(channel) != 'open'
        echom 'channel:' . channel
        return {}
    endif
    let command = a:command
    let command.tempfile = tempname()
    call ch_sendexpr(channel, command,{"callback": funcref('s:callback3')})
endfunction

function! s:cb_do(ch,dict) abort
    call ch_close(a:ch)
    if type(a:dict)==v:t_dict
        if get(a:dict,"status",9) == 9
            let deletesql=[get(a:dict,'lastsql','') . "\n" . g:dbiclient_sql_delimiter2, get(a:dict,'lastsql','') . g:dbiclient_sql_delimiter1]
            call dbiclient#deleteHistory(dbiclient#loadQueryHistoryDo(),deletesql,s:getHistoryPathDo())
        endif
        if has_key(a:dict,'commit')
            if get(a:dict,"status",9) == 1
                call s:echoMsg('IO13')
            endif
        elseif has_key(a:dict,'rollback')
            if get(a:dict,"status",9) == 1
                call s:echoMsg('IO14')
            endif
        else
            let info= ''
            let info= info . '"Connection Info:[PORT=' . s:dbi_job_port . ']'
            let info= info . '[DBD=' . s:params[s:dbi_job_port].dsn . ']'
            let info= info . '[SCHEMA=' . s:getuser(a:dict) . ']'
            let info= info . '[TIME=' . get(a:dict,'time',-1) . 'ms]'
            let info= info . '[COUNT=' . get(a:dict,'cnt',-1) . ']'
            let matchadds=[]
            let ymdhms=strftime("%Y%m%d%H%M%S",localtime())
            call s:f.newBuffer('EXECUTE_' . s:getuser(a:dict) . '_' . ymdhms,g:dbiclient_new_window_hight,g:dbiclient_buffer_encoding)
            call extend(matchadds,s:append('$',[info],'Comment'))
            call add(matchadds,['String','\v^SQL\>.*'])
            call extend(matchadds,s:append('$',['"Quick Help<nmap>:'],'Comment'))
            let i=0
            for sql in get(a:dict.data,'do',[])
                if len(a:dict.outputline) < i+1
                    break
                endif
                if trim(sql) != ''
                    if len(sql) > 200
                        let sqlstr='SQL>' . s:getSqlLine(sql)[0:200] . '...'
                        call s:append('$',[sqlstr])
                    else
                        let sqlstr='SQL>' . s:getSqlLine(sql)
                        call s:append('$',[sqlstr])
                    endif
                    call s:append('$',get(a:dict.outputline,i,[]))
                    let i+=1
                endif
            endfor
            let b:matches_dbiclient=matchadds
            call s:sethl()

            if get(a:dict,"status",9) == 1
                if filereadable(a:dict.data.tempfile . '.err')
                    let lines=readfile(a:dict.data.tempfile . '.err')
                    call map(lines,{i,x->iconv(x,get(get(s:params,s:dbi_job_port,{}),'encoding',&enc),g:dbiclient_buffer_encoding)})
                    if !empty(lines)
                        let matchadds=[]
                        let ymdhmss=strftime("%Y%m%d%H%M%S",localtime()) . reltime()[1][-4:]
                        call s:f.newBuffer('ERROR_' . s:getuser(a:dict) . '_' . ymdhmss,g:dbiclient_new_window_hight,g:dbiclient_buffer_encoding)
                        call extend(matchadds,s:append('$',[info],'Comment'))
                        call extend(matchadds,s:append('$',['"Quick Help<nmap>:'],'Comment'))
                        call s:append('$',lines)
                        let b:matches_dbiclient=matchadds
                        call s:sethl()
                    endif
                endif
            endif
        endif
    else
        call s:echoMsg('EO04',s:dbi_job_port,'')
    endif
    call s:sethl()
    call s:debugLog(a:dict)
    call s:gotoLastWin()
endfunction
function! s:cb_outputResultCmn(ch,dict) abort
    call ch_close(a:ch)
    let opt = get(a:dict.data,'opt',{})
    if get(a:dict,"status",9) == 1
        if bufloaded(get(opt,'closebufnr',-1))
            exe 'silent! bd! ' . opt.closebufnr
        endif
    endif
    let info= ''
    let info= info . '"Connection Info:[PORT=' . s:dbi_job_port . ']'
    let info= info . '[DBD=' . s:params[s:dbi_job_port].dsn . ']'
    let info= info . '[SCHEMA=' . s:getuser(a:dict) . ']'
    let info= info . '[TIME=' . get(a:dict,'time',-1) . 'ms]'
    let info= info . '[COUNT=' . get(a:dict,'cnt',-1) . ']'
    let matchadds=[]
    call add(matchadds,['String','\v^SQL\>.*'])
    if get(a:dict,"status",9) == 9
        let deletesql=[get(a:dict,'lastsql','')]
        call dbiclient#deleteHistory(dbiclient#loadQueryHistory(),deletesql,s:getHistoryPath())
    endif
    if get(a:dict,"status",9) == 1
        let ymdhmss=strftime("%Y%m%d%H%M%S",localtime()) . reltime()[1][-4:]
        call s:f.newBuffer(get(opt,'bufname','Select_' . s:getuser(a:dict) . '_' . ymdhmss),g:dbiclient_new_window_hight,g:dbiclient_buffer_encoding)
        let w:disableline = []
        call extend(matchadds,s:append('$',[info],'Comment'))
        call add(w:disableline,line('$'))
        if get(a:dict.data,'table_info',0) != 1 && get(a:dict.data,'column_info',0) != 1
            call extend(matchadds,s:append('$',['"Quick Help<nmap>: S:SELECT W:WHERE <C-g>:GROUP O:ORDER A:ALIGN R:RELOAD'],'Comment'))
            call add(w:disableline,line('$'))
            call extend(matchadds,s:append('$',['"Quick Help<vmap>: <C-I>:create inssert <C-U>:create update <C-D>:create delete'],'Comment'))
            call add(w:disableline,line('$'))
        elseif get(a:dict.data,'table_info',0) == 1
            call extend(matchadds,s:append('$',['"Quick Help: <CR>:SQL W:TABLE_NAME T:TABLE_TYPE'],'Comment'))
            call add(w:disableline,line('$'))
        endif
        let lines=readfile(a:dict.data.tempfile)
        if get(opt,"nosql",0) == 0 && !empty(a:dict.data.sql)
            let tmp='SQL>' . s:getSqlLine(a:dict.data.sql)
            call s:append('$',[tmp])
            call add(w:disableline,line('$'))
            call s:append('$',[substitute(tmp,'.','-','g')])
            call add(w:disableline,line('$'))
        endif
        if get(opt,"notablenm",0) == 0 && !empty(lines[0])
            call extend(matchadds,s:append('$',[lines[0]],'String'))
            call add(w:disableline,line('$'))
        endif
        if get(opt,"nocols",0) == 0 && !empty(lines[1])
            call s:append('$',[lines[1]])
            let b:dbiclient_col_line=line('$')
            call add(w:disableline,line('$'))
            call add(matchadds,['Type','\v\w%' . (line('$')) . 'l'])
            for key in get(a:dict,'primary_key',[])
                call add(matchadds,['Title','\v<' . key . '>%' . (line('$')) . 'l'])
            endfor
        endif
        if get(a:dict.data,'column_info',0) == 1
            for key in get(a:dict,'primary_key',[])
                call add(matchadds,['Title','\v<' . key . '>%>' . (line('$')) . 'l'])
            endfor
        endif
        call s:append('$',lines[2:])
        norm gg
        if g:dbiclient_col_delimiter != "\t"
            exe 'silent! %s/\t/' . g:dbiclient_col_delimiter . '/g'
        endif
    else
        if has_key(a:dict.data,'tempfile')
            let ymdhmss=strftime("%Y%m%d%H%M%S",localtime()) . reltime()[1][-4:]
            call s:f.newBuffer('ERROR_' . s:getuser(a:dict) . '_' . ymdhmss,g:dbiclient_new_window_hight,g:dbiclient_buffer_encoding)
            call extend(matchadds,s:append('$',[info],'Comment'))
            let lines=readfile(a:dict.data.tempfile)
            call s:append('$',lines)
        else
            return 0
        endif
    endif
    for lines in get(a:dict,'outputline',[])
        for line in lines
            echom 'DBMS.OUTPUT:'.line
        endfor
    endfor
    let b:bufmap={}
    let b:bufmap.alignFlg=0
    if has_key(a:dict,"cols")
        let b:bufmap.cols=get(a:dict,'cols',[])
        let b:bufmap.data=get(a:dict,'data',{})
    endif
    let b:bufmap.opt=opt
    for cmd in get(opt,'aftercmd',[])
        exe cmd
    endfor
    let b:matches_dbiclient=matchadds
    call s:sethl()
    call s:f.readonly()
endfunction
function! s:cb_outputResult(ch,dict) abort
    call s:cb_outputResultCmn(a:ch,a:dict)
    if get(a:dict,"status",9) == 1
        let b:bufmap.alignFlg = 0
        if b:bufmap.data.table_info != 1 && b:bufmap.data.column_info != 1
            nmap <buffer> <nowait> <silent> A :<C-u>call <SID>align(!get(b:bufmap,"alignFlg",0))<CR>
            nmap <buffer> <nowait> <silent> W :<C-u>call <SID>where()<CR>
            nmap <buffer> <nowait> <silent> R :<C-u>call dbiclient#reload()<CR>
            nmap <buffer> <nowait> <silent> S :<C-u>call <SID>select()<CR>
            nmap <buffer> <nowait> <silent> <C-G> :<C-u>call <SID>group()<CR>
            nmap <buffer> <nowait> <silent> O :<C-u>call <SID>order()<CR>
            vmap <buffer> <nowait> <silent> <C-I> :call <SID>createInsertRange()<CR>
            vmap <buffer> <nowait> <silent> <C-D> :call <SID>createDeleteRange('')<CR>
            vmap <buffer> <nowait> <silent> <C-U> :call <SID>createUpdateRange('')<CR>
        endif
        call s:align('!')
    endif
    call s:gotoLastWin()
endfunction
function! s:cb_outputResultEasyAlign(ch,dict)
    call s:cb_outputResultCmn(a:ch,a:dict)
    if get(a:dict,"status",9) == 1
        let b:bufmap.alignFlg = 1
        if b:bufmap.data.table_info != 1 && b:bufmap.data.column_info != 1
            nmap <buffer> <nowait> <silent> A :<C-u>call <SID>align(!get(b:bufmap,"alignFlg",0))<CR>
            nmap <buffer> <nowait> <silent> W :<C-u>call <SID>where()<CR>
            nmap <buffer> <nowait> <silent> R :<C-u>call dbiclient#reload()<CR>
            nmap <buffer> <nowait> <silent> S :<C-u>call <SID>select()<CR>
            nmap <buffer> <nowait> <silent> <C-G> :<C-u>call <SID>group()<CR>
            nmap <buffer> <nowait> <silent> O :<C-u>call <SID>order()<CR>
            vmap <buffer> <nowait> <silent> <C-I> :call <SID>createInsertRange()<CR>
            vmap <buffer> <nowait> <silent> <C-D> :call <SID>createDeleteRange('')<CR>
            vmap <buffer> <nowait> <silent> <C-U> :call <SID>createUpdateRange('')<CR>
        endif
        call s:align('')
    endif
    call s:gotoLastWin()
endfunction
function s:gotoLastWin()
    if s:params[s:dbi_job_port].gotowinlastbuf && !exists('b:bufmap.opt.closebufnr')
        call s:f.gotoWin(s:f.getLastBufnr(bufnr('%')))
    endif
endfunction
function! s:align(bang)
    if !exists('b:bufmap') || empty(get(b:bufmap,"cols",[]))
        return
    endif
    let colsize=len(b:bufmap.cols)
    let save_cursor = getcurpos()
    "norm gg
    "let breakflg=0
    "while len(split(getline('.'),'\t')) != colsize
    "    if line('.') == line('$')
    "        let breakflg=1
    "        break
    "    endif
    "    norm j
    "endwhile
    let b:bufmap.alignFlg=(a:bang!='!')
    if !exists('b:dbiclient_lines')
        let b:dbiclient_header = getline(0, b:dbiclient_col_line-1)
        let b:dbiclient_lines = getline(b:dbiclient_col_line, '$')
    endif
    call s:f.noreadonly()
    call s:clearbuf()
    call s:append('$',b:dbiclient_header)
    if exists('b:bufmap') && get(b:bufmap,'alignFlg',0) == 0
        let lines = b:dbiclient_lines
    else
        let lines = s:getalignlist(b:dbiclient_lines)
    endif
    call s:append('$',lines)
    if b:bufmap.alignFlg
        call s:f.readonly()
    endif
    call setpos('.', save_cursor)
endfunction
function! s:rpad(x,n,c)
    let len=a:n - strwidth(a:x)
    return a:x . repeat(a:c,a:n - strwidth(a:x))
endfunction

function! s:getalignlist(lines)
    if empty(a:lines)
        return []
    endif
    let colsize=len(split(a:lines[0],g:dbiclient_col_delimiter,1))
    let maxsize=200000/colsize
    call s:debugLog('align:start:maxsize ' . maxsize)
    let lines=a:lines[:maxsize]
    call s:debugLog('align:lines ' . len(lines))
    let lines2=a:lines[maxsize+1:]
    call s:debugLog('align:lines2 ' . len(lines2))
    let lines=map(lines,{_,x->split(x,g:dbiclient_col_delimiter,1)})
    call s:debugLog('align:copy')
    let linesLen=map(deepcopy(lines),{_,x->map(x,{_,y->strwidth(y)})})
    call s:debugLog('align:linesLen')
    let maxCols=copy(linesLen[0])
    call map(copy(linesLen),{_,cols->map(maxCols,{i,col->colsize == len(cols) && col < cols[i] ? cols[i] : col})})
    call s:debugLog('align:maxCols' . string(maxCols))
    let lines=map(lines,{_,cols->colsize == len(cols) ? join(map(cols,{i,col->col . repeat(' ',maxCols[i] + 1 - strwidth(col))}),g:dbiclient_col_delimiter_align . ' ') : join(cols,g:dbiclient_col_delimiter)})
    call s:debugLog('align:end')
    return extend(lines,lines2)
endfunction
function! dbiclient#selectTableOfList(table)
    if s:isDisableline()
        return
    endif
    call dbiclient#selectTableCmn('!',a:table)
endfunction
function! dbiclient#selectTable(bang,wordFlg, ...)
    let limitrows=get(a:,1,s:limitrows)
    if a:wordFlg
        let table=expand('<cWORD>')
    else
        let table=join(s:f.getRangeCurList(getpos("'<"), getpos("'>")))
    endif
    call dbiclient#selectTableCmn(a:bang,table,limitrows)
endfunction
function! dbiclient#selectTableCmn(bang,table,...)
    if empty(trim(a:table))
        return
    endif
    let limitrows=get(a:,1,s:limitrows)
    let list = ['SELECT * FROM ' . a:table]
    call dbiclient#getQueryAsync(join(list,"\n"),s:callbackstr(a:bang),limitrows,{'single_table':a:table})
endfunction
function! dbiclient#editHistory(line,mode)
    if s:isDisableline()
        return
    endif
    call s:f.newBuffer('EDIT_' . s:getuser() ,g:dbiclient_new_window_hight,g:dbiclient_buffer_encoding)
    if a:mode == 1
        let list=dbiclient#loadQueryHistoryDo()
    else
        let list=dbiclient#loadQueryHistory()
    endif
    call s:append('$',split(list[a:line-1],"\n"))
endfunction
function! dbiclient#deleteHistoryIdxRange(histlist,path) range
    if s:isDisableline()
        return
    endif
    let histlist=a:histlist
    for idx in reverse(range(a:firstline, a:lastline))
        call remove(histlist,idx - 1 - len(w:disableline))
    endfor
    call writefile(map(histlist,{_,x->join(split(x,"\n"),'{DELIMITER_CR}')}),a:path)
endfunction
function! dbiclient#deleteHistory(histlist,sqllist,path)
    let histlist=a:histlist
    let res=[]
    let sqllist=a:sqllist[:]
    for sql in histlist
        let ret=0
        for sql2 in sqllist
            if s:getSqlLine(sql) == s:getSqlLine(sql2)
                let ret=1
                break
            endif
        endfor
        if !ret
            call add(res,sql)
        endif
    endfor
    call writefile(map(res,{_,x->join(split(x,"\n"),'{DELIMITER_CR}')}),a:path)
endfunction
function! dbiclient#uniqHistory(histlist,sqllist,path,delim)
    let histlist=a:histlist
    call extend(histlist,map(filter(a:sqllist[:],{_,x->x !~ '\v^\s*$'}),{_,x->x . a:delim}))
    let histlist=sort(map(histlist,{i,x->[i,x]}),{x,y->x[1] == y[1] ? 0 : x[1] > y[1] ? 1 : -1})
    "let histlist=uniq(histlist,{x,y->x[1] == y[1] ? 0 : x[1] > y[1] ? 1 : -1})
    let res=[]
    let ret=''
    for [i,sql] in reverse(histlist)
        if ret!=sql
            if trim(sql)!=''
                call add(res,[i,sql])
            endif
        endif
        let ret=sql
    endfor
    call writefile(map(sort(res,{x,y->x[0] == y[0] ? 0 : x[0] > y[0] ? 1 : -1}),{_,x->join(split(x[1],"\n"),'{DELIMITER_CR}')}),a:path)
endfunction
function! s:getSqlLineDelComment(sql)
    if a:sql == ''
        return
    endif
    let ret = map(split(a:sql,"\n"),{_,x->substitute(x,'\v^%(%((--)@!.(-)@!.)|%(''%([^'']|('''')){-}''))*\zs\s*--.*$','','g')})
    let ret = join(map(ret,{_,x->substitute(x,'\v(^\s*|\s*$)','','g')}))
    "return len(ret) > 300 ? ret[:300] . '...' : ret
    return ret
endfunction
function! s:getSqlLine(sql)
    if a:sql == ''
        return
    endif
    "let ret = map(split(a:sql,"\n"),{_,x->substitute(x,'\v^%(%((--)@!.(-)@!.)|%(''%([^'']|('''')){-}''))*\zs\s*--.*$','','g')})
    let ret = split(a:sql,"\n")
    let ret = join(map(ret,{_,x->substitute(x,'\v(^\s*|\s*$)','','g')}))
    "return len(ret) > 300 ? ret[:300] . '...' : ret
    return ret
endfunction
function! s:selectHistory(mode)
    if get(get(s:params,s:dbi_job_port,{}),'connect',9) != 1
        return
    endif
    if a:mode == 1
        let list=map(dbiclient#loadQueryHistoryDo(),{_,x->substitute(x,'\n',' ','g')})
        call s:f.newBuffer('DB_HISTORY_DO_' . s:getuser() ,g:dbiclient_new_window_hight,g:dbiclient_buffer_encoding)
    else
        let list=map(dbiclient#loadQueryHistory(),{_,x->substitute(x,'\n',' ','g')})
        call s:f.newBuffer('DB_HISTORY_' . s:getuser() ,g:dbiclient_new_window_hight,g:dbiclient_buffer_encoding)
    endif
    let matchadds=[]
    let w:disableline = []
    call extend(matchadds,s:append('$',['"Quick Help<nmap>: <S-D>:DELETE <S-E>:EDIT'],'Comment'))
    call add(w:disableline,line('$'))
    call extend(matchadds,s:append('$',['"Quick Help<vmap>: <S-D>:DELETE'],'Comment'))
    call add(w:disableline,line('$'))
    call s:append('$',list)
    norm G
    let b:matches_dbiclient=matchadds
    call s:sethl()
    call s:f.readonly()
endfunction
function! s:extendquery(bang,select,where,order,group)
    if s:error1() || s:error2()
        return
    endif
    let limitrows=b:bufmap.data.limitrows
    let sql = s:getSqlLineDelComment(b:bufmap.data.sql)
    if sql =~ '\v\/\*PRESQL\*\/\zs.{-}\ze\/\*PRESQL\*\/'
        let sql = matchstr(sql,'\v\/\*PRESQL\*\/\s*\zs.{-}\ze\s*\/\*PRESQL\*\/')
    endif
    if get(b:bufmap.opt,'single_table','') != ''
        let sql = 'SELECT ' . a:select . ' FROM ' . get(b:bufmap.opt,'single_table','') . ' T ' . trim(a:where . ' ' . a:group . ' ' . a:order)
    else
        let sql = 'SELECT ' . a:select . ' FROM (/*PRESQL*/ ' . sql . ' /*PRESQL*/) T ' . trim(a:where . ' ' . a:group . ' ' . a:order)
    endif
    let opt=b:bufmap.opt
    let opt.where=get(b:bufmap,'where',[])
    let opt.extend={}
    let opt.extend.select=a:select
    let opt.extend.where=a:where
    let opt.extend.order=a:order
    let opt.extend.group=a:group
    if !has_key(opt,'precols')
        let opt.precols=b:bufmap.cols
    endif
    call dbiclient#getQueryAsync(sql,s:callbackstr(a:bang),limitrows,opt)
    quit
endfunction
function! s:order()
    if s:error1() || s:error2()
        return
    endif
    let bufmap=deepcopy(b:bufmap)
    let bufmap.opt.closebufnr=bufnr('%')
    call s:selectExtends('SQL_ORDER',1,get(bufmap.opt,'order',{}))
    let b:bufmap=bufmap
    nmap <buffer> <nowait> <silent> <CR> :<C-u>call <SID>orderQuery(b:bufmap.alignFlg ? '!' : '')<CR>
endfunction
function! s:orderQuery(bang)
    if s:isDisableline()
        return
    endif
    if !exists('b:bufmap.opt.extend')
        let b:bufmap.opt.extend = {}
    endif
    if empty(b:selectdict)
        let b:bufmap.opt.extend.order = ''
    else
        let list1 = map(s:selectValues(b:selectdict),{_,x->'T.' . x})
        let order = ' ORDER BY ' . join(list1,',')
        let b:bufmap.opt.extend.order = order
    endif
    let b:bufmap.opt.order = {}
    let b:bufmap.opt.order.selectdict = b:selectdict
    let b:bufmap.opt.order.selectdictstr = b:selectdictstr
    let b:bufmap.opt.order.selectdictAscDesc = b:selectdictAscDesc
    let extend=b:bufmap.opt.extend
    call s:extendquery(a:bang,get(extend,'select','T.*'),get(extend,'where',''),get(extend,'order',''),get(extend,'group',''))
endfunction
function! s:select()
    if s:error1() || s:error2()
        return
    endif
    let bufmap=deepcopy(b:bufmap)
    let bufmap.opt.closebufnr=bufnr('%')
    call s:selectExtends('SQL_SELECT',0,get(bufmap.opt,'select',{}))
    let b:bufmap=bufmap
    nmap <buffer> <nowait> <silent> <CR> :<C-u>call <SID>selectQuery(b:bufmap.alignFlg ? '!' : '')<CR>
endfunction
function! s:selectQuery(bang)
    if s:isDisableline()
        return
    endif
    if !exists('b:bufmap.opt.extend')
        let b:bufmap.opt.extend = {}
    endif
    if empty(b:selectdict)
        let b:bufmap.opt.extend.select = 'T.*'
    else
        let list1 = map(s:selectValues(b:selectdict),{_,x->'T.' . x})
        let select = join(list1,',')
        let b:bufmap.opt.extend.select = select
    endif
    let b:bufmap.opt.select = {}
    let b:bufmap.opt.select.selectdict = b:selectdict
    let b:bufmap.opt.select.selectdictstr = b:selectdictstr
    let b:bufmap.opt.select.selectdictAscDesc = b:selectdictAscDesc
    let extend=b:bufmap.opt.extend
    call s:extendquery(a:bang,get(extend,'select','T.*'),get(extend,'where',''),get(extend,'order',''),get(extend,'group',''))
endfunction
function! s:group()
    if s:error1() || s:error2()
        return
    endif
    let bang=b:bufmap.alignFlg ? '!' : ''
    let bufmap=deepcopy(b:bufmap)
    let bufmap.opt.closebufnr=bufnr('%')
    call s:selectExtends('SQL_GROUP',0,get(bufmap.opt,'group',{}))
    let b:bufmap=bufmap
    nmap <buffer> <nowait> <silent> <CR> :<C-u>call <SID>groupQuery(b:bufmap.alignFlg ? '!' : '')<CR>
endfunction
function! s:groupQuery(bang)
    if s:isDisableline()
        return
    endif
    if !exists('b:bufmap.opt.extend')
        let b:bufmap.opt.extend = {}
    endif
    if empty(b:selectdict)
        let b:bufmap.opt.extend.group = ''
        let b:bufmap.opt.extend.select = 'T.*'
    else
        let list1 = map(s:selectValues(b:selectdict),{_,x->'T.' . x})
        let group = 'GROUP BY ' . join(list1,',')
        let b:bufmap.opt.extend.group = group
        let b:bufmap.opt.extend.select = join(s:selectValues(b:selectdict),',')
    endif
    let b:bufmap.opt.group = {}
    let b:bufmap.opt.group.selectdict = b:selectdict
    let b:bufmap.opt.group.selectdictstr = b:selectdictstr
    let b:bufmap.opt.group.selectdictAscDesc = b:selectdictAscDesc
    let extend=b:bufmap.opt.extend
    call s:extendquery(a:bang,get(extend,'select','T.*'),get(extend,'where',''),get(extend,'order',''),get(extend,'group',''))
endfunction
function! s:where()
    if s:error1() || s:error2()
        return
    endif
    let bufmap=deepcopy(b:bufmap)
    let bufmap.opt.closebufnr=bufnr('%')
    call s:selectWhere()
    norm gg$
    let b:bufmap=bufmap
    nmap <buffer> <nowait> <silent> <CR> :<C-u>call <SID>whereQuery(b:bufmap.alignFlg ? '!' : '')<CR>
endfunction
function! s:whereQuery(bang)
    if s:isDisableline()
        return
    endif
    if !exists('b:bufmap.opt.extend')
        let b:bufmap.opt.extend = {}
    endif
    let b:bufmap.where=getline(0,'$')
    let list1 = filter(getline(0,'$'),{_,x->x !~ '\v^[^=]+\=\s*$'})
    let list1 = filter(list1,{_,x->!empty(x) && x != '\V1=1'})
    let list1 = map(list1,{_,x->'T.' . x})
    let listeq = filter(list1[:],{_,x->x =~ '\v^[^=]+\=([^%_]|\\\%|\\_)+$'})
    let listlike = filter(list1[:],{_,x->x !~ '\v^[^=]+\=([^%_]|\\\%|\\_)+$'})
    let F={x,y->trim(matchstr(x,'\v\zs^[^=]+\ze\=.*')) . y . s:SINGLE_QUOTES1 . matchstr(x,'\v^[^=]+\=\zs.*') . s:SINGLE_QUOTES1}
    let listeq = map(listeq,{_,x->' AND ' . F(substitute(substitute(substitute(x,'''','''''','g'),'\V\\_','_','g'),'\V\\%','%','g'),' = ')})
    let listlike = map(listlike,{_,x->' AND ' . F(x,' LIKE ')})
    let limitrows=b:bufmap.data.limitrows
    let whereStr=join(extend(listeq,listlike),"\n")
    let where = 'WHERE 1=1 ' . whereStr
    let b:bufmap.opt.extend.where = where
    let extend=b:bufmap.opt.extend
    call s:extendquery(a:bang,get(extend,'select','T.*'),get(extend,'where',''),get(extend,'order',''),get(extend,'group',''))
endfunction
function! dbiclient#dbhistoryDo()
    call s:selectHistory(1)
    nmap <buffer> <nowait> <silent> <S-d> :<C-u>call dbiclient#deleteHistoryIdxRange(dbiclient#loadQueryHistoryDo(),<SID>getHistoryPathDo())<CR>:call dbiclient#dbhistoryDo()<CR>
    vmap <buffer> <nowait> <silent> <S-d> :'<,'>call dbiclient#deleteHistoryIdxRange(dbiclient#loadQueryHistoryDo(),<SID>getHistoryPathDo())<CR>:call dbiclient#dbhistoryDo()<CR>
    nmap <buffer> <nowait> <silent> <S-E> :call dbiclient#editHistory(line('.')  - len(w:disableline),1)<CR>
    return
endfunction
function! dbiclient#dbhistory()
    call s:selectHistory(0)
    nmap <buffer> <nowait> <silent> <CR> :<C-u>call <SID>dbhistoryQuery(line('.')  - len(w:disableline))<CR>
    nmap <buffer> <nowait> <silent> <S-d> :<C-u>call dbiclient#deleteHistoryIdxRange(dbiclient#loadQueryHistory(),<SID>getHistoryPath())<CR>:call dbiclient#dbhistory()<CR>
    vmap <buffer> <nowait> <silent> <S-d> :'<,'>call dbiclient#deleteHistoryIdxRange(dbiclient#loadQueryHistory(),<SID>getHistoryPath())<CR>:call dbiclient#dbhistory()<CR>
    nmap <buffer> <nowait> <silent> <S-E> :call dbiclient#editHistory(line('.')  - len(w:disableline),0)<CR>
    return
endfunction
function! s:dbhistoryQuery(no)
    if s:isDisableline()
        return
    endif
    quit
    let sql=dbiclient#loadQueryHistory()[a:no - 1]
    call dbiclient#getQueryAsync(sql,s:callbackstr('!'),s:limitrows,{})
endfunction
function! dbiclient#reload(...)
    if s:error1() || s:error4()
        return
    endif
    let bang=b:bufmap.alignFlg ? '!' : ''
    let limitrows=get(a:,1,b:bufmap.data.limitrows)
    let sql = b:bufmap.data.sql
    let opt=b:bufmap.opt
    let opt.closebufnr=bufnr('%')
    call dbiclient#getQueryAsync(sql,s:callbackstr(bang),limitrows,opt)
endfunction
function! s:callbackstr(bang)
    return a:bang=='!' ? 's:cb_outputResultEasyAlign' : 's:cb_outputResult'
endfunction

function! dbiclient#UserTables2()
    let opt={
                \'noaddhistory' : 1
                \,'nosql'       : 1
                \,'notablenm'   : 1
                \,'nocols'      : 0
                \,'table_info'  : 1
                \,'tableNm'     : v:null}
    return dbiclient#getQuery('',-1,opt)
endfunction
function! dbiclient#UserTables(bang)
    if s:error1()
        return
    endif
    let tableNm=s:params[s:dbi_job_port].table_name
    let tabletype=s:params[s:dbi_job_port].tabletype
    call s:UserTables(a:bang,tableNm,tabletype)
endfunction
function! s:UserTables(bang,tableNm,tabletype)
    let tableNm=a:tableNm == v:null || a:tableNm =~ '\v^\s*$' ? v:null : a:tableNm
    let tableNm=substitute(a:tableNm,"'","",'g')
    let tabletype=a:tabletype == v:null || a:tabletype =~ '\v^\s*$' ? v:null : a:tabletype
    let tabletype=substitute(a:tabletype,"'","",'g')
    let s:params[s:dbi_job_port].tabletype=tabletype == v:null ? '' : tabletype
    let s:params[s:dbi_job_port].table_name=tableNm == v:null ? '' : tableNm
    let cmd= []
    call add(cmd,'nmap <buffer> <nowait> <silent> <CR> :<C-u>call dbiclient#selectTableOfList(trim(matchstr(getline("."),''\v^[^\' . g:dbiclient_col_delimiter_align . ']+'')))<CR>')
    call add(cmd,'nmap <buffer> <nowait> <silent> W :<C-u>call <SID>UserTables(b:bufmap.alignFlg ? "!" : "",input(''TABLE_NAME:'',''' . escape(s:params[s:dbi_job_port].table_name,'|') . '''),''' . escape(s:params[s:dbi_job_port].tabletype,'|') . ''')<CR>')
    call add(cmd,'nmap <buffer> <nowait> <silent> T :<C-u>call <SID>UserTables(b:bufmap.alignFlg ? "!" : "",''' . escape(s:params[s:dbi_job_port].table_name,'|') . ''',input(''TABLE_TYPE:'',''' . escape(s:params[s:dbi_job_port].tabletype,'|') . '''))<CR>')
    call add(cmd,'norm gg')
    let opt = {
                \'noaddhistory' : 1
                \,'nosql'       : 1
                \,'notablenm'   : 1
                \,'nocols'      : 0
                \,'table_info'  : 1
                \,'tabletype'   : tabletype
                \,'table_name'  : tableNm
                \,'bufname'     : 'Tables_' . s:getuser()
                \,'aftercmd'    : cmd}
    call dbiclient#getQueryAsync('',s:callbackstr(a:bang),-1,opt)
endfunction
function! dbiclient#selectColumnsTable(bang,wordFlg)
    if a:wordFlg
        let table=expand('<cWORD>')
    else
        let table=join(s:f.getRangeCurList(getpos("'<"), getpos("'>")))
    endif
    call s:selectColumnsTableCmn(a:bang,table)
endfunction
function! s:selectColumnsTableCmn(bang,table,...)
    if empty(trim(a:table))
        return
    endif
    let cmd= []
    call add(cmd,'norm gg')
    let ymdhms=strftime("%Y%m%d%H%M%S",localtime())
    let opt = {
                \'noaddhistory' : 1
                \,'nosql'       : 1
                \,'notablenm'   : 1
                \,'column_info' : 1
                \,'tableNm'     : a:table
                \,'bufname'     : 'Columns_' . s:getuser() . '_' . ymdhms
                \,'aftercmd'    : cmd}
    call dbiclient#getQueryAsync('',s:callbackstr(a:bang),-1,opt)
endfunction

let s:loaded=0
function! s:init()
    if s:loaded == 0
        if !isdirectory(s:getRootPath())
            call mkdir(s:getRootPath())
        endif
        let path=s:Filepath.join(s:getRootPath() , 'channellog.log')
        if g:dbiclient_debugflg
            call ch_logfile(path, 'w')
        endif
        if s:getRootPath() == "" || !isdirectory(s:getRootPath())
            call s:echoMsg('EO11',s:getRootPath())
            return 0
        endif
        if s:getPerlmPath() == "" || !filereadable(s:getPerlmPath())
            call s:echoMsg('EO12',s:getPerlmPath())
            return 0
        endif
        let logpath=s:getRootPath()
        if !isdirectory(logpath)
            call mkdir(logpath)
        endif
    endif
    let s:loaded=1
endfunction
function! s:selectValues(selectdict)
    let list=sort(items(a:selectdict),{x,y->x[1] == y[1] ? 0 : x[1] > y[1] ? 1 : -1})
    return map(map(list,{_,x->[x[1],x[0]]}),{_,x->x[1] . (b:selectdictAscDesc[x[1]] ? ' DESC' : '')})
endfunction
function! s:SelectLines(orderFlg) range
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
function! s:SelectLineOrder(line)
    if s:isDisableline()
        return
    endif
    let line=a:line
    let matchadds=[]
    call add(matchadds,['Comment','\v^(\[ASC\]|\[DESC\]).*'])
    let str = getline(line)
    if str !~ '\v^(\[ASC\]|\[DESC\])'
        let b:selectdict[str] = max(b:selectdict)+1
        let b:selectdictAscDesc[str] = 0
        let b:selectdictstr[str] = '[ASC]' . b:selectdict[str] . ' ' . str
    elseif str =~ '^\[ASC\]'
        let str=substitute(str,'\v^(\[ASC\]|\[DESC\])+[0-9]+\s','','')
        let b:selectdictAscDesc[str] = 1
        let b:selectdictstr[str] = '[DESC]' . b:selectdict[str] . ' ' . str
    else
        let str=substitute(str,'\v^(\[ASC\]|\[DESC\])+[0-9]+\s','','')
        call remove(b:selectdict,str)
        call remove(b:selectdictstr,str)
        call remove(b:selectdictAscDesc,str)
        let selectdict={}
        let i=1
        for [key,val] in sort(items(b:selectdict),{x,y->x[1] == y[1] ? 0 : x[1] > y[1] ? 1 : -1})
            let selectdict[key]=i
            let b:selectdictstr[key] = substitute(b:selectdictstr[key],'\v^(\[ASC\]|\[DESC\])+\zs[0-9]+\ze\s',i,'')
            let i+=1
        endfor
        let b:selectdict=selectdict
    endif
    let save_cursor = getcurpos()
    call s:f.noreadonly()
    silent! %s/\v^(\[ASC\]|\[DESC\])+[0-9]+\s//
    norm gg
    for [key,val] in items(b:selectdictstr)
        call s:setline(searchpos('^' . key . '$','cn')[0],val)
    endfor
    call s:f.readonly()
    call setpos('.', save_cursor)
    let b:matches_dbiclient=matchadds
    call s:sethl()
endfunction
function! s:SelectLine(line)
    if s:isDisableline()
        return
    endif
    let line=a:line
    let matchadds=[]
    call add(matchadds,['Comment','^[*].*'])
    let str = getline(line)
    if str !~ '^[*]'
        let b:selectdict[str] = max(b:selectdict)+1
        let b:selectdictAscDesc[str] = 0
        let b:selectdictstr[str] = '*' . b:selectdict[str] . ' ' . str
    else
        let str=substitute(str,'\v^[*]+[0-9]+\s','','')
        call remove(b:selectdict,str)
        call remove(b:selectdictstr,str)
        call remove(b:selectdictAscDesc,str)
        let selectdict={}
        let i=1
        for [key,val] in sort(items(b:selectdict),{x,y->x[1] == y[1] ? 0 : x[1] > y[1] ? 1 : -1})
            let selectdict[key]=i
            let b:selectdictstr[key] = substitute(b:selectdictstr[key],'\v^[*]+\zs[0-9]+\ze\s',i,'')
            let i+=1
        endfor
        let b:selectdict=selectdict
    endif
    let save_cursor = getcurpos()
    call s:f.noreadonly()
    silent! %s/\v^[*]+[0-9]+\s//
    norm gg
    for [key,val] in items(b:selectdictstr)
        call s:setline(searchpos('^' . key . '$','cn')[0],val)
    endfor
    call s:f.readonly()
    call setpos('.', save_cursor)
    let b:matches_dbiclient=matchadds
    call s:sethl()
endfunction
function! s:selectWhere()
    if !empty(get(b:bufmap.opt,'where',[]))
        let list=b:bufmap.opt.where
    else
        let maxcol = max(map(b:bufmap.cols[:],{_,x->strwidth(x)}))
        let list=map(b:bufmap.cols[:],{_,x->x . repeat(' ' , maxcol - strwidth(x) +1) . '='})
    endif
    call s:f.newBuffer('SQL_WHERE',g:dbiclient_new_window_hight,g:dbiclient_buffer_encoding)
    inoremap <buffer> <silent> <CR> <ESC>
    call s:append(0,list)
    norm gg
endfunction
function! s:selectExtends(bufname,orderflg,dict)
    let matchadds=[]
    call add(matchadds,['Comment','^[*].*'])
    call add(matchadds,['Comment','\v^(\[ASC\]|\[DESC\]).*'])
    let opt=get(b:bufmap,'opt',{})
    let precols=get(opt,'precols',[])
    if has_key(a:dict,'selectdict')
        let list=[]
        for key in copy(empty(precols) ? b:bufmap.cols : precols)
            call add(list, get(a:dict.selectdictstr, key, key))
        endfor
    else
        let list=map(copy(empty(precols) ? b:bufmap.cols : precols),{_,x->x})
    endif
    call s:f.newBuffer(a:bufname,g:dbiclient_new_window_hight,g:dbiclient_buffer_encoding)
    let b:selectdict=get(a:dict,'selectdict',{})
    let b:selectdictstr=get(a:dict,'selectdictstr',{})
    let b:selectdictAscDesc=get(a:dict,'selectdictAscDesc',{})
    call s:append(0,list)
    norm gg
    if a:orderflg
        nmap <buffer> <nowait> <silent> <SPACE> :<C-u>call <SID>SelectLineOrder(line("."))<CR>
        vmap <buffer> <nowait> <silent> <SPACE> :call <SID>SelectLines(1)<CR>
    else
        nmap <buffer> <nowait> <silent> <SPACE> :<C-u>call <SID>SelectLine(line("."))<CR>
        vmap <buffer> <nowait> <silent> <SPACE> :call <SID>SelectLines(0)<CR>
    endif
    call s:f.readonly()
    let b:matches_dbiclient=matchadds
    call s:sethl()
endfunction
function! s:isDisableline(...)
    if exists('w:disableline')
        for dl in w:disableline
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
    endif
    return 0
endfunction
function! s:clearbuf()
    let old_undolevels = &undolevels
    setl undolevels=-1
    silent 0,$delete_
    let &undolevels = old_undolevels
endfunction
function! s:setline(line,str)
    let old_undolevels = &undolevels
    setl undolevels=-1
    call setline(a:line,a:str)
    let &undolevels = old_undolevels
endfunction
function! s:append_nodel_zerostring(line,list)
    let old_undolevels = &undolevels
    setl undolevels=-1
    call append(a:line,a:list)
    silent g/^$/ delete_
    let &undolevels = old_undolevels
endfunction
function! s:append(line,list,...)
    let old_undolevels = &undolevels
    setl undolevels=-1
    call append(a:line,a:list)
    silent g/^$/ delete_
    let &undolevels = old_undolevels
    let matchadds=[]
    for val in a:list
        if a:0 == 1
            call add(matchadds,[a:1,'^\V'.escape(val,'/') . '\v$'])
        endif
    endfor
    return matchadds
endfunction
function! s:getuser(...)
    let ret=get(get(a:,1,{}),'user','')
    if ret == ''
        let ret=get(get(s:params,s:dbi_job_port,{}),'user','')
    endif
    return ret == v:null ? 'NOUSER' : ret
endfunction
function! s:sethl()
    if exists('w:matches_dbiclient')
        call map(w:matches_dbiclient,{_,x->matchdelete(x)})
        unlet w:matches_dbiclient
    endif
    if exists('b:matches_dbiclient')
        let w:matches_dbiclient = []
        for x in b:matches_dbiclient
            call add(w:matches_dbiclient,matchadd(x[0],x[1],0,-1))
        endfor
    endif
endfunction
augroup BufEnterDbiClient
    autocmd WinNew,BufEnter * call s:sethl()
augroup END

let &cpo = s:cpo_save
unlet s:cpo_save

" vim:fdm=marker:nowrap:ts=4:expandtab:
