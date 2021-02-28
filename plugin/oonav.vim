" Vim global plugin for navigating to method implementations
" Last Change:	2021 Feb 28
" Maintainer:	Sagi Zeevi <sagi.zeevi@gmail.com>
" License:	    MIT


" TODO: uncomment this
" if exists("g:loaded_oonav")
"     finish
" endif
let g:loaded_oonav = 1

" temporarily change compatible option
 let s:save_cpo = &cpo
 set cpo&vim

let s:current_tags = []
let s:debug_on = 0

function! s:turn_on_debug()
    s:debug_on = 1
endfunction

function! s:turn_off_debug()
    s:debug_on = 0
endfunction

function! s:dbg(msg)
    if s:debug_on
        echom a:msg
    endif
endfunction

" Return the tag from a tags list which points to current line
function! s:MyTag(tags)
    let line_num = line('.')
    if s:debug_on | call s:dbg("line_num is " . line_num) | endif
    for tag in a:tags
        let save_cursor = getcurpos()
        if tag.cmd[0] == '/'
            let pattern = tag.cmd[1:-3]
            if s:debug_on | call s:dbg("Trying self search pattern " . pattern) | endif
            let l = search(pattern)
        else
            exe tag.cmd
            let l = line('.')
        endif
        call setpos('.', save_cursor)
        if s:debug_on | call s:dbg("l is " . l) | endif
        if l == line_num
            return tag
        endif
    endfor
    return v:none
endfunction

let s:base_classes = {}
function! s:ClearCache()
    let s:base_classes = {}
endfunction

function! s:GetBaseClasses(derived, add_self=0)
    if has_key(s:base_classes, a:derived)
        return s:base_classes[a:derived]
    endif
    let tags = filter(taglist('\<' . a:derived . '$'), 'v:val.kind == "c"')
    let res = {}
    if a:add_self
        let res[a:derived] = 1
    endif
    if ! empty(tags)
        let cmd = tags[0].cmd
        if s:debug_on | call s:dbg(cmd) | endif
        let potentials = []
        let m = matchstrpos(cmd, '\<' . a:derived)
        let start = m[2]
        " All the words after the derived class name are
        " potential parent classes
        while start != -1
            let m = matchstrpos(cmd, '\w\+', start)
            let word = m[0]
            let start = m[2]
            if word != ''
                call add(potentials, word)
            endif
        endwhile
        for p in potentials
            for k in s:GetBaseClasses(p, 1)
               let res[k] = 1
            endfor
        endfor
    endif
    let res = keys(res)
    let s:base_classes[a:derived] = res
    if s:debug_on | call s:dbg('GetBaseClasses(' . a:derived . ',' . a:add_self . ') returning ' . string(res)) | endif
    return res
endfunction

function! s:MethodTaglist(name)
  let list = []
  " Get all method tags for this symbol
  let s:current_tags = filter(taglist('\<' . a:name . '$'), 'v:val.kind == "m"')
  if s:debug_on | call s:dbg("method tags found:" . string(s:current_tags)) | endif


  " Find this line in that list
  let my_tag = s:MyTag(s:current_tags)
  if my_tag is v:none
      echoerr 'Did not find self tag for ' . a:name
      return list
  endif
  let base_class = my_tag.class
  if s:debug_on | call s:dbg("class is " . base_class) | endif


  " Remove self
  let s:current_tags = filter(s:current_tags, {idx, val -> val.class != base_class})

  " Remove ones which our class is not a base for them
  let s:current_tags = filter(s:current_tags, {idx, val -> count(s:GetBaseClasses(val.class), base_class)})

  let i = 0
  for item in s:current_tags
      let i = i + 1
      let s = i . '. ' . item.class . '.' . item.name . ' : ' . item.filename
      call add(list, s)
  endfor
  return list
endfunction

" Handles the user choice for tag
function! s:TagsSink(choice)
    let i = matchstr(a:choice, '^\d\+') - 1
    let tag = s:current_tags[i]
    exe 'e ' tag.filename 
    exe tag.cmd
endfunction

function! s:NavShow(name)
    call s:ClearCache()
    echo s:MethodTaglist(a:name)
endfunction

if !hasmapto('<Plug>OonavShow;')
    map <unique> <Leader>ji  <Plug>OonavShow;
endif
noremap <script> <Plug>OonavShow;  <SID>NavShow

noremap <silent> <SID>NavShow  :call <SID>NavShow(expand("<cword>"))<CR>

 if !exists(":NavImp")
     command -nargs=1  NavImp  :call s:NavShow(<q-args>)
 endif

" restore compatible option
let &cpo = s:save_cpo
unlet s:save_cpo

