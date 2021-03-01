" Vim global plugin for navigating to method implementations
" Last Change:	2021 Feb 28
" Maintainer:	Sagi Zeevi <sagi.zeevi@gmail.com>
" License:      MIT


" TODO: uncomment this
" if exists("g:loaded_oonav")
"     finish
" endif
let g:loaded_oonav = 1

" temporarily change compatible option
 let s:save_cpo = &cpo
 set cpo&vim

let s:current_tags = []

let s:bin_dir = expand('<sfile>:p:h:h').'/bin/'
let s:preview = s:bin_dir . 'preview_tag.pl'

function! s:Dbg(msg)
    if g:oonav#debug_on
        echom a:msg
    endif
endfunction


" Return the tag from a tags list which points to current line
function! s:MyTag(tags)
    let line_num = line('.')
    if g:oonav#debug_on | call s:Dbg("line_num is " . line_num) | endif
    for tag in a:tags
        let save_cursor = getcurpos()
        if tag.cmd[0] == '/'
            let pattern = tag.cmd[1:-3]
            if g:oonav#debug_on | call s:Dbg("Trying self search pattern " . pattern) | endif
            let l = search(pattern)
        else
            exe tag.cmd
            let l = line('.')
        endif
        call setpos('.', save_cursor)
        if g:oonav#debug_on | call s:Dbg("l is " . l) | endif
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
        if g:oonav#debug_on | call s:Dbg(cmd) | endif
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
    if g:oonav#debug_on | call s:Dbg('GetBaseClasses(' . a:derived . ',' . a:add_self . ') returning ' . string(res)) | endif
    return res
endfunction


function! s:NavDownOptions(name)
  let list = []
  " Get all method tags for this symbol
  let s:current_tags = filter(taglist('\<' . a:name . '$'), 'v:val.kind == "m"')
  if g:oonav#debug_on | call s:Dbg("method tags found:" . string(s:current_tags)) | endif

  " Find this line in that list
  let my_tag = s:MyTag(s:current_tags)
  if my_tag is v:none
      echoerr 'Did not find self tag for ' . a:name
      return list
  endif
  let base_class = my_tag.class
  if g:oonav#debug_on | call s:Dbg("class is " . base_class) | endif

  " Remove self
  let s:current_tags = filter(s:current_tags, {idx, val -> val.class != base_class})

  " Remove ones which our class is not a base for them
  let s:current_tags = filter(s:current_tags, {idx, val -> count(s:GetBaseClasses(val.class), base_class)})

  " Build the user options
  let i = 0
  for item in s:current_tags
      let i = i + 1
      let s = i . '. ' . item.class . '.' . item.name . ' : ' . item.filename
      call add(list, s)
  endfor
  return list
endfunction


" Actual open the required tag location
function! s:GotoTag(num)
    let tag = s:current_tags[a:num]
    exe 'e ' tag.filename 
    exe tag.cmd
endfunction


" Handles the fzf choice
function! s:FzfSink(choice)
    let i = matchstr(a:choice, '^\d\+') - 1
    let tag = s:current_tags[i]
    exe 'e ' tag.filename 
    exe tag.cmd
endfunction


" Main entry point from outside - nav Down/Up for name under cursor
function! s:Nav(name, direction)
    call s:ClearCache()
    let options = s:Nav{a:direction}Options(a:name)
    if g:oonav#debug_on | call s:Dbg("options are " . string(options)) | endif
    let l = len(options)
    if l
        if l == 1
            call s:GotoTag(0)
        else
            if g:oonav#allow_fzf && exists('*g:fzf#wrap')
                let fzf_options = ''
                if g:oonav#allow_fzf_preview
                    let patterns=''
                    for tag in s:current_tags
                        let patterns .= tag.cmd
                    endfor
                    let fzf_options = ['--ansi', '--prompt', 'Navigate' . a:direction . '?>',
                                \ '--preview', s:preview . " '" . patterns . "' {} 50",
                                \ '--preview-window=down:60%']
                endif
                call fzf#run(fzf#wrap({'source': options, 'sink': funcref('<SID>FzfSink'),
                            \ 'options': fzf_options}))
            else
                call insert(options, 'Please select:')
                let num = inputlist(options)
                if num != 0
                    call s:GotoTag(num - 1)
                endif
            endif
        endif
    endif
endfunction

" map \jd (jump down the class hierarchy)
if !hasmapto('<Plug>(oonav-down)')
    map <unique> <Leader>jd  <Plug>(oonav-down)
endif
noremap <script> <Plug>(oonav-down)  <SID>NavDown
noremap <silent> <SID>NavDown  :call <SID>Nav(expand("<cword>"), 'Down')<CR>

" map \ju (jump up the class hierarchy)
if !hasmapto('<Plug>(oonav-up)')
    map <unique> <Leader>ju  <Plug>(oonav-up)
endif
noremap <script> <Plug>(oonav-up)  <SID>NavUp

noremap <silent> <SID>NavUp  :call <SID>Nav(expand("<cword>"), 'Up')<CR>

" restore compatible option
let &cpo = s:save_cpo
unlet s:save_cpo

