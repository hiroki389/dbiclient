scriptencoding utf-8
" Turn on support for line continuations when creating the script
let s:cpo_save = &cpo
set cpo&vim

let s:_plugin_name=expand('<sfile>:p:h:t')
let s:funclibbuflist=[]
let s:lastbufnrDict={}
function! {s:_plugin_name}#funclib#RangeList() range
    let s:val={s:_plugin_name}#funclib#List(getline(a:firstline, a:lastline))
    let s:val.firstline=a:firstline
    let s:val.lastline=a:lastline
    function! s:val.setpos()
        exe s:val.firstline . ',' . s:val.lastline . 'delete'
        call append(s:val.firstline-1, s:val.value())
        return s:val
    endfunction
    return s:val
endfunction
function! {s:_plugin_name}#funclib#ReadBuf()
    return {s:_plugin_name}#funclib#List(getline(0,'$'))
endfunction
function! {s:_plugin_name}#funclib#List(x)
    let s:val={}
    let s:val.func={xs->xs}
    let s:f1={s:_plugin_name}#funclib#new()
    let s:f2={s:_plugin_name}#funclib#new2()
    function! s:val.dropWith(func)
        let F=s:val.func
        let s:val.func={xs->s:takedropWith(F(xs),a:func)[1]}
        return s:val
    endfunction
    function! s:val.takeWith(func)
        let F=s:val.func
        let s:val.func={xs->s:takedropWith(F(xs),a:func)[0]}
        return s:val
    endfunction
    function! s:takedropWith(xs,func)
        let idx=0
        for val in a:xs
            if !a:func(val)
                return [s:val.List[idx:],s:val.List[:idx]]
            endif
            let idx+=1
        endfor
        return [[],s:val.List]
    endfunction
    function! s:val.awk(rep,...)
        function! s:awk(lines,rep,...)
            let list = a:lines
            if a:0 > 0
                let sep=a:1
            else
                let sep='\t'
            endif
            " タブ区切り文字を置換する
            let F= {str,rep-> s:f2.Substitute(str,(len(split(str,sep)) < 2 ? '' : repeat('(.{-})' . sep,len(split(str,sep))-1)) . '(.*)',rep,"g")}
            return s:f2.Foldl({x->F(x,a:rep)},[],list)
        endfunction
        let F=s:val.func
        let s:val.func={xs->s:awk(F(xs),a:rep,a:0==0 ? '\t' : a:1)}
        return s:val
    endfunction
    function! s:val.return(x)
        let s:val.List=s:f2.Return(a:x)
        return s:val
    endfunction
    function! s:val.uniq()
        let F=s:val.func
        let s:val.func={xs->uniq(sort(F(xs)))}
        return s:val
    endfunction
    function! s:val.filter(f)
        let F=s:val.func
        let s:val.func={xs->s:f2.Filter({x->a:f(x)},F(xs))}
        return s:val
    endfunction
    function! s:val.insert(x)
        let s:val.List=s:val.value()
        let s:val.func={xs->xs}
        call insert(s:val.List,a:x)
        return s:val
    endfunction
    function! s:val.add(x)
        let s:val.List=s:val.value()
        let s:val.func={xs->xs}
        call add(s:val.List,a:x)
        return s:val
    endfunction
    function! s:val.match(pat,...)
        let F=s:val.func
        let s:val.func={xs->s:f2.Filter({x->s:f2.Match(x,a:pat,a:0==0 ? '' : a:1)},F(xs))}
        return s:val
    endfunction
    function! s:val.unmatch(pat,...)
        let F=s:val.func
        let s:val.func={xs->s:f2.Filter({x->s:f2.UnMatch(x,a:pat,a:0==0 ? '' : a:1)},F(xs))}
        return s:val
    endfunction
    function! s:val.matchstr(pat,...)
        let F=s:val.func
        let s:val.func={xs->s:f2.Filter({x->x != ""},s:f2.Fmap({x->s:f2.Matchstr(x,a:pat,a:0==0 ? '' : a:1)},F(xs)))}
        return s:val
    endfunction
    function! s:val.matchstrg(pat,...)
        let F=s:val.func
        let s:val.func={xs->s:f2.Filter({x->x != ""},s:f1.joinHs(s:f2.Fmap({x->s:f2.GetMatchedValue(x,a:pat,a:0==0 ? '' : a:1)},F(xs))))}
        return s:val
    endfunction
    function! s:val.substitute(pat,rep,mode,...)
        let F=s:val.func
        let s:val.func={xs->s:f2.Fmap({x->s:f2.Substitute(x,a:pat,a:rep,a:mode,a:0==0 ? '' : a:1)},F(xs))}
        return s:val
    endfunction
    function! s:val.foldl(f,acc)
        function! s:Mappend(seed,x)
            let res = a:seed
            if(type(res)==v:t_number)
                let res += a:x
            elseif(type(res)==v:t_string)
                let res .= a:x
            elseif(type(res)==v:t_list)
                let res = add(copy(res),a:x)
            elseif(type(res)==v:t_dict)
                let res = extend(copy(res),a:x)
            elseif(type(res)==v:t_float)
                let res += a:x
            endif
            return res
        endfunction
        let F=s:val.func
        let s:val.type=type(a:acc)
        let s:val.func={xs->s:f2.Foldl({x,y->s:Mappend(x,a:f(y))},a:acc,F(xs))}
        return s:val
    endfunction
    function! s:val.fmap(f)
        let F=s:val.func
        let s:val.func={xs->s:f2.Fmap(a:f,F(xs))}
        return s:val
    endfunction
    function! s:val.bind(f)
        let F=s:val.func
        let s:val.func={xs->s:f2.Bind(a:f,F(xs))}
        return s:val
    endfunction

    function! s:setlist(x)
        let s:val.type=type(a:x)
        if(s:val.type==v:t_number)
            let s:val.List=[a:x]
        elseif(s:val.type==v:t_string)
            let s:val.List=split(a:x,'.\zs')
        elseif(s:val.type==v:t_list)
            let s:val.List=copy(a:x)
        elseif(s:val.type==v:t_dict)
            let s:val.List=copy(a:x)
        elseif(s:val.type==v:t_float)
            let s:val.List=[a:x]
        else
            let s:val.List=[a:x]
        endif
    endfunction
    function! s:val.value()
        if(s:val.type==v:t_number)
            return s:val.func(s:val.List)
        elseif(s:val.type==v:t_string)
            return join(s:val.func(s:val.List),"")
        elseif(s:val.type==v:t_list)
            return s:val.func(s:val.List)
        elseif(s:val.type==v:t_dict)
            return s:val.func(s:val.List)
        elseif(s:val.type==v:t_float)
            return s:val.func(s:val.List)
        else
            return s:val.func(s:val.List)
        endif
    endfunction
    call s:setlist(a:x)
    return s:val
endfunction
function! {s:_plugin_name}#funclib#new()
    let s:res={}
    function! s:res.compose(...)
        function! s:compose2(list)
            if empty(a:list)
                return {x->x}
            endif
            return {x->a:list[0](s:compose2(a:list[1:])(x))}
        endfunction
        return s:compose2(a:000)
    endfunction
    " 配列の2番目以降を取得
    function! s:res.tail(xs)
        return a:xs[1:]
    endfunction
    " 配列の一番目を取得
    function! s:res.head(xs)
        return a:xs[0]
    endfunction
    " 配列の最後以外を取得
    function! s:res.init(xs)
        return a:xs[0:-2]
    endfunction
    " 配列の最後を取得
    function! s:res.last(xs)
        return a:xs[-1:-1]
    endfunction
    " いずれかが一致
    function! s:res.any(xs,fuc)
        for x in a:xs
            if a:fuc(x)
                return 1
            endif
        endfor
        return 0
    endfunction
    " すべて一致
    function! s:res.all(xs,fuc)
        return {s:_plugin_name}#funclib#List(a:xs).foldl(a:fuc,0).value() == len(a:xs)
    endfunction
    " haskellのjoin
    function! s:res.joinHs(xs)
        if(empty(a:xs))
            return []
        endif
        let ret=[]
        for x in a:xs
            if(type(x)==v:t_list)
                call extend(ret,s:f1.joinHs(x))
            else
                call extend(ret,[x])
            endif
        endfor
        return ret
    endfunction
    function! s:res.zip(keys,vals)
        return {s:_plugin_name}#funclib#List(range(len(a:keys))).foldl({i->i<len(a:vals)?[a:keys[i],a:vals[i]]:[]},[]).filter({x->!empty(x)}).value()
    endfunction
    " 文字の配列に変換する
    function! s:res.chars(str)
        return split(a:str,'.\zs')
    endfunction
    function! s:res.joinPath(path1,path2)
        return substitute(s:res.trim(a:path1),'\v[\/]$','','') . '/' . substitute(s:res.trim(a:path2),'\v^[\/]','','')
    endfunction
    function! s:res.trim(str)
        let idxs = matchend(a:str,'^\s*')
        let idx = match(a:str,'\s*$')
        return a:str[idxs == -1 ? 0 : idxs :idx == -1 ? idx : idx - 1]
    endfunction

    " 新規バッファーに結果を出力
    function! s:res.outputConvertTsv(rep) range
        let res=s:res.awk(s:res.getline(a:from, a:to),a:rep)
        new
        call s:res.foldl(range(len(res)),[], {i->[setline(i+1,res[i])]})
    endfunction
    " カウントアップ関数
    function! s:res.cntupGen()
        return {->[execute("let cnt=0"),{->[execute("let cnt+=1"),cnt][-1]}][-1]}()
    endfunction

    " バッファーテキストを指定した文字コードに変換したリストを返却
    function! s:res.encodeBuffer(from,to)
        return map(getline(0,'$'),{i,x->iconv(x,a:from,a:to)})
    endfunction
    " 
    function! s:res.edit(editcmd, hight, bufname,enc)
        return s:res.newBufferBase(a:editcmd, a:bufname,a:enc,1,0)
    endfunction
    function! s:res.editWrite(editcmd, hight, bufname,enc)
        return s:res.newBufferBase(a:editcmd, a:hight, a:bufname,a:enc,0,0)
    endfunction
    " 一時バッファーを作成
    function! s:res.newBuffer(editcmd, hight, bufname,enc,previewFlg)
        return s:res.newBufferBase(a:editcmd, a:hight, a:bufname,a:enc,1,a:previewFlg)
    endfunction
    function! s:res.newBufferWrite(editcmd, hight, bufname,enc,previewFlg)
        return s:res.newBufferBase(a:editcmd, a:hight, a:bufname,a:enc,0,a:previewFlg)
    endfunction
    function! s:res.newBufferBase(editcmd, hight, bufname,enc,roflg,previewFlg)
        let cbufnr = bufnr('%')
        let bufnr=bufnr(a:bufname)
        call s:res.delbuf(bufnr)
        let wid = s:res.getwid(bufnr('%'))
        keepjumps silent! exe a:editcmd . " ++enc=" . a:enc . " " . a:bufname
        if a:previewFlg
            wincmd P
        endif
        call s:res.chngeBuftype(a:roflg)
        let bufnr=bufnr('%')
        "nnoremap <buffer> <silent> <nowait> q :silent! quit!<CR>
        let s:lastbufnrDict[bufnr] = a:bufname
        "setlocal readonly            "読み込み専用
        call clearmatches()
        if string(a:hight) =~ '\v[0-9]+'
            exe 'resize ' .. a:hight
        endif
        if a:previewFlg
            if wid != -1
                call win_gotoid(wid)
            endif
        endif
        return [bufnr, cbufnr]
    endfunction
    function! s:res.getLastBufnr(bufnr)
        let bufnr = get(s:lastbufnrDict,a:bufnr,-1)
        if has_key(s:lastbufnrDict,a:bufnr)
            call remove(s:lastbufnrDict,a:bufnr)
        endif
        return bufnr
    endfunction
    function! s:res.enew(bufname, enc, roflg)
        let bufnr=bufnr(a:bufname)
        call s:res.delbuf(bufnr)
        keepjumps silent! exe "edit ++enc=" .. a:enc .. ' ' .. a:bufname
        setlocal buftype=nofile
        setlocal nobuflisted
        let bufnr=bufnr('%')
        call s:res.chngeBuftype(a:roflg)
        return bufnr
    endfunction
    function! s:res.chngeBuftype(roflg)
        if a:roflg
            setlocal buftype=nofile
            setlocal nobuflisted
        endif
        setlocal noswapfile          "スワップファイルを作成しない
        "setlocal bufhidden=wipe      "バッファがウィンドウ内から表示されなくなったら削除
        setlocal nowrap              "ラップしない
        "setlocal readonly            "読み込み専用
        call add(s:funclibbuflist,bufnr('%'))
    endfunction
    function! s:res.readonly(bufnr)
        call setbufvar(a:bufnr,'&readonly',1)
        call setbufvar(a:bufnr,'&modifiable',0)
    endfunction
    function! s:res.noreadonly(bufnr)
        call setbufvar(a:bufnr,'&readonly',0)
        call setbufvar(a:bufnr,'&modifiable',1)
    endfunction
    " 指定したバッファー名のウィンドウに遷移
    function! s:res.gotoWin(bufnr)
        let wid = s:res.getwid(a:bufnr)
        if wid != -1
            call win_gotoid(wid)
            return 1
        endif
        return -1
    endfunction
    function! s:res.gotoWinCurrentTab(bufnr)
        let wid = s:res.getwidCurrentTab(a:bufnr)
        if wid != -1
            call win_gotoid(wid)
            return 1
        endif
        return -1
    endfunction
    function! s:res.getwidlist(bufnr)
        let ret=[]
        for tabnr in range(1,tabpagenr('$'))
            for wid in map(range(tabpagewinnr(tabnr,'$')),{_,x->win_getid(x+1,tabnr)})
                if(s:res.any(map(win_findbuf(a:bufnr),{_,x->wid==x}),{x->x!=0}))
                    call add(ret, wid)
                endif
            endfor
        endfor
        return ret
    endfunction
    function! s:res.getwidCurrentTab(bufnr)
        let tabnr = tabpagenr()
        for wid in map(range(tabpagewinnr(tabnr,'$')),{_,x->win_getid(x+1,tabnr)})
            if(s:res.any(map(win_findbuf(a:bufnr),{_,x->wid==x}),{x->x!=0}))
                return wid
            endif
        endfor
        return -1
    endfunction
    function! s:res.getwid(bufnr)
        for tabnr in range(1,tabpagenr('$'))
            for wid in map(range(tabpagewinnr(tabnr,'$')),{_,x->win_getid(x+1,tabnr)})
                if(s:res.any(map(win_findbuf(a:bufnr),{_,x->wid==x}),{x->x!=0}))
                    return wid
                endif
            endfor
        endfor
        return -1
    endfunction
    function! s:res.delbuf(bufnr)
        if a:bufnr != -1
            exe 'silent! bwipeout! ' . a:bufnr
        endif
    endfunction
    " 指定した範囲の行をリストにして返却
    function! s:res.getRangeCurList(posS,posE)
        let y1=a:posS[1]
        let y2=a:posE[1]
        let x1=a:posS[2]
        let x2=a:posE[2]
        if y1==0 && y2==0 && x1==0 && x2==0
            return []
        endif
        let line= getline(y1, y2)
        if y2-y1==0
            let lineS= [remove(line,0)[x1-1:x2-1]]
            let lineE=[]
        else
            let lineS= [remove(line,0)[x1-1:]]
            let lineE= [remove(line,-1)[:x2-1]]
        endif
        return lineS+line+lineE
    endfunction
    " 指定した範囲の行をリストにして返却
    function! s:res.getRangeCurList3() range
        let lines= getline(a:firstline, a:lastline)
        let posS=getpos("'<")
        let posE=getpos("'>")
        call feedkeys('"0y','x')
        let vlines=split(@0,"\n")
        echo s:res.getRangeCurList2(lines,vlines,posS,posE,'')
    endfunction
    function! s:res.getRangeCurList2(lines,vlines,posS,posE,mode)
        let y1=a:posS[1]
        let y2=a:posE[1]
        let x1=a:posS[2]
        let x2=a:posE[2]
        " one line
        if y2-y1==0
            let ret= [[y1,x1,x1 + x2]]
        else
            let ret=[]
            "echom string(a:lines)
            "echom string(a:vlines)
            for [i,line,vline] in map(copy(a:lines),{i,x->[i,x,a:vlines[i]]})
                let pos=[]
                if x1 < x2
                    let basepos=x1
                else
                    let basepos=x2
                endif
                if a:mode == 'v' && i==0
                    let pos= [x1,x1 + len(vline)-1]
                elseif a:mode == 'v' && i==len(a:lines)-1
                    let pos= [0,len(vline)-1]
                elseif a:mode == 'v' || a:mode == 'V'
                    let pos=[0,len(vline)-1]
                elseif basepos < len(line)
                    let pos=[basepos,basepos + len(vline)-1]
                endif
                "echom i
                call add(ret,[y1+i]+pos)
            endfor
        endif
        return ret
    endfunction
    return s:res
endfunction

function! {s:_plugin_name}#funclib#new2()
    let s:res2={}
    function! s:res2.Flip(func)
        return {...->a:0==0 ? a:func() : a:0==1 ? a:func(a:1) : a:func(a:2,a:1)}
    endfunction

    function! s:res2.Foldl(f,init,xs)
        "return empty(a:xs) ? a:init : s:res2.Foldl(a:f,a:f(copy(a:init),a:xs[0]),a:xs[1:])
        let ret=a:init
        for x in copy(a:xs)
            let ret=a:f(ret,x)
        endfor
        return ret
    endfunction
    function! s:res2.Foldl1(f,xs)
        return s:res2.Foldl(a:f,a:xs[0],a:xs[1:])
    endfunction

    "function! s:res2.Foldr(f,init,xs)
    "    return s:res2.FoldrGen(a:f,a:init,a:xs)()
    "endfunction
    "function! s:res2.FoldrGen(f,init,xs)
    "    return empty(a:xs) ? {->[]} : {->a:f(s:res2.FoldrGen(a:f,[],a:xs[1:])(),a:xs[0])}
    "endfunction
    function! s:res2.Foldr(f,init,xs)
        let ret=a:init
        for i in reverse(range(len(a:xs)))
            let ret=a:f(ret,a:xs[i])
        endfor
        return ret
    endfunction

    function! s:res2.Filter(f,xs)
        "return s:res2.Foldl({acc,x->a:f(x) ? acc+[x] : acc},[],a:xs)
        return filter(a:xs,{_,x->a:f(x)})
    endfunction

    function! s:res2.Fmap(f,xs)
        "return s:res2.Foldl({acc,x->acc+[a:f(x)]}, [], a:xs)
        return map(a:xs,{_,x->a:f(x)})
    endfunction

    function! s:res2.Pure(x)
        return [a:x]
    endfunction
    function! s:res2.Applicative(mf,xs)
        return s:res2.Foldl({acc,f->acc+s:res2.Fmap(f, copy(a:xs))}, [], a:mf)
    endfunction

    function! s:res2.Mconcat(xs)
        return s:res2.Foldl({init,x->extend(init,x)},s:res2.Mempty(),a:xs)
    endfunction
    function! s:res2.Mappend(init,x)
        return extend(a:init,a:x)
    endfunction
    function! s:res2.Mempty()
        return []
    endfunction

    function! s:res2.Return(x)
        return [a:x]
    endfunction
    function! s:res2.Bind(xs,f)
        return s:res2.Mconcat(s:res2.Fmap(a:f, a:xs))
    endfunction

    function! s:res2.Xargs(cmd) range
        return split(system('xargs ' . a:cmd,getline(a:firstline, a:lastline)),"\n")
    endfunction

    function! s:res2.IsIgnore(args)
        return len(a:args) != 0 && a:args[0]=='I' ? '\C' : '\c'
    endfunction

    function! s:res2.Substitute(x,pat,rep,mode,...)
        let ignore=s:res2.IsIgnore(a:000)
        return substitute(a:x, '\v' . ignore . a:pat,a:rep,a:mode)
    endfunction
    function! s:res2.Matchstr(x,pat,...)
        let ignore=s:res2.IsIgnore(a:000)
        return matchstr(a:x, '\v' . ignore . a:pat)
    endfunction
    function! s:res2.Match(x,pat,...)
        let ignore=s:res2.IsIgnore(a:000)
        return a:x =~ '\v' . ignore . a:pat
    endfunction

    function! s:res2.UnMatch(x,pat,...)
        let ignore=s:res2.IsIgnore(a:000)
        return a:x !~ '\v' . ignore . a:pat
    endfunction
    function! s:res2.GetMatchedValue(str, pat,...)
        let ignore=s:res2.IsIgnore(a:000)
        let ret=[]
        let end = 0
        while end != -1
            let [substr,start,end] = matchstrpos(a:str,'\v' . ignore . a:pat,end)
            if start != -1
                call add(ret,substr)
            endif
        endwhile
        return ret
    endfunction
    function! s:res2.Searchpair(list,start,end,...)
        let with=a:0 == 1 && a:1 == 1
        let ret=[]
        let spos=0
        let epos=0
        for i in range(len(a:list))
            if spos == 0 && a:list[i] == a:start
                let spos=i + with
            endif
            if a:list[i] == a:end
                let epos=i - with
                break
            endif
        endfor
        return a:list[spos:epos]
    endfunction
    function! s:res2.AwkPattern(...)
        return s:res2.AwkPatternFunc(a:000)
    endfunction
    function! s:res2.AwkPatternFunc(args)
        let pat=''
        for val in a:args
            let pat .= pat == '' ? '' : '\s{-}'
            let pat .= val
        endfor
        return '\v' . pat
    endfunction
    function! s:res2.DeleteSearchTag(pat)
        let result=""
        let pos = s:res2.SearchCloseTag(a:pat)
        if !empty(pos)
            call cursor(pos[0])
            norm mm
            call cursor(pos[1])
            let tmp=@a
            norm f>v`m"ad
            let result=@a
            let @a=tmp
        endif
        return result
    endfunction
    function! s:res2.SearchTagMoveStart(pat)
        return s:res2.SearchCloseTagCmn(a:pat, 2)
    endfunction
    function! s:res2.SearchTagMoveEnd(pat)
        return s:res2.SearchCloseTagCmn(a:pat, 1)
    endfunction
    function! s:res2.SearchCloseTag(pat)
        return s:res2.SearchCloseTagCmn(a:pat,0)
    endfunction
    function! s:res2.SearchCloseTagCmn(pat,mode)
        let pos=getpos('.')[1:2]
        let targetpos=[]
        let sposlist=[]
        while s:res2.Search('\<' , a:pat) > 0
            if empty(targetpos)
                let targetpos=getpos('.')[1:2]
            endif
            call add(sposlist, getpos('.')[1:2])
        endwhile
        call cursor(pos)
        let eposlist=[]
        while s:res2.Search('\<\/' , a:pat . '|' . a:pat . '\_[^<]{-}\/\s{-}\>') > 0
            call add(eposlist, getpos('.')[1:2])
        endwhile
        let mergelist=[]
        for cpos in eposlist
            if empty(sposlist)
                break
            endif
            let max=filter(sposlist[:], {_,x->x[0] < cpos[0]||(x[0] == cpos[0] && x[1] < cpos[1])})
            if !empty(max)
                for i in range(len(sposlist))
                    if max[-1]==sposlist[i]
                        call remove(sposlist, i)
                        break
                    endif
                endfor
                call add(mergelist, [max[-1],cpos])
            endif
        endfor
        let ret=filter(mergelist, {_,x->x[0][0]==targetpos[0] && x[0][1]==targetpos[1]})
        if !empty(ret)
            if a:mode == 1
                call cursor(ret[0][1])
            elseif a:mode == 2
                call cursor(ret[0][0])
            else
                call cursor(pos)
            endif
            return ret[0]
        endif
        call cursor(pos)
        return []
    endfunction
    function! s:res2.SearchB(...)
        return search(s:res2.AwkPatternFunc(a:000),'b')
    endfunction
    function! s:res2.Search(...)
        return search(s:res2.AwkPatternFunc(a:000))
    endfunction
    function! s:res2.Sub(pat, rep, mode)
        let sub=substitute(getline('.'),a:pat, a:rep, a:mode)
        call setline(line('.'),sub)
    endfunction
    function! s:res2.ReplaceInputTagSlash()
        norm gg
        while s:res2.Search('\<',' input','. {-}',' type' ,'\=','"','button') > 0
            norm %hv"ay
            if @a != '/'
                norm a/
            endif
        endwhile
    endfunction
    return s:res2
endfunction
function! s:deleteallbuf()
    for val in s:funclibbuflist
        if bufexists(val)
            exe 'silent! bwipeout! ' . val
        endif
    endfor
endfunction
augroup funclib_deleteallbuf
    autocmd VimLeavePre *    call <SID>deleteallbuf()
augroup END

let &cpo = s:cpo_save
unlet s:cpo_save

" vim:fdm=marker:nowrap:ts=4:expandtab:
