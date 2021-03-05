" Vim global plugin for navigating to method implementations
" Last Change:	2021 March 02
" Maintainer:	Sagi Zeevi <sagi.zeevi@gmail.com>
" License:      MIT


if exists("g:loaded_oonav")
    finish
endif
let g:loaded_oonav = 1

" temporarily change compatible option
let s:save_cpo = &cpo
set cpo&vim

let s:current_tags = []

let s:bin_dir = expand('<sfile>:p:h:h').'/bin'
let s:preview = s:bin_dir . '/preview_tag.pl'

function! s:Dbg(msg)
    if g:oonav#debug_on
        echom a:msg
    endif
endfunction

function! s:PreviewExe()
    if executable(g:oonav#perl)
        if g:oonav#debug_on
            let flags="--debug"
        else
            let flags=""
        endif
        return g:oonav#perl . ' ' . s:preview . " " . flags
    else
        throw 'Perl ' . g:oonav#perl . ' was not found (change g:oonav#perl)'
    endif
endfunction

" Return the tag from a tags list which points to current line
function! s:MyTag(tags)
    let line_num = line('.')
    if g:oonav#debug_on | call s:Dbg("line_num is " . line_num) | endif
    let current_file = expand('%:p')
    if g:oonav#debug_on | call s:Dbg("current_file is " . current_file) | endif
    let this_file_tags = copy(a:tags)
    call filter(this_file_tags, {idx, val -> val.filename == current_file})
    if g:oonav#debug_on | call s:Dbg("this_file_tags are " . string(this_file_tags)) | endif
    for tag in this_file_tags
        let save_cursor = getcurpos()
        if tag.cmd[0] == '/'
            let pattern = tag.cmd[1:-3]
            if g:oonav#debug_on
                call s:Dbg("Trying self search pattern " . pattern)
            endif
            let move_cursor = copy(save_cursor)
            let move_cursor[1] = move_cursor[1] - 1
            call setpos('.', move_cursor)
            let l = search(pattern)
        else
            exe tag.cmd
            let l = line('.')
        endif
        call setpos('.', save_cursor)
        if g:oonav#debug_on | call s:Dbg("l is " . l) | endif
        if l == line_num
            if g:oonav#debug_on | call s:Dbg("my_tag is " . string(tag)) | endif
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
        return s:base_classes[a:derived].classes
    endif
    let tags = filter(taglist('\<' . a:derived . '$'), 'v:val.kind == "c"')
    let res = {}
    if a:add_self
        let res[a:derived] = 1
    endif
    let tag = v:none
    if ! empty(tags)
        let tag = tags[0]
        let cmd = tag.cmd
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
    let s:base_classes[a:derived] = {'classes': res, 'tag': tag}
    if g:oonav#debug_on
        call s:Dbg('GetBaseClasses(' . a:derived . ',' . a:add_self .
                    \ ') returning ' . string(res))
    endif
    return res
endfunction


function! s:PrepareTaglist(name)
    " Get all method/class tags for this symbol
    let s:current_tags = filter(taglist('\<' . a:name . '$'), 'v:val.kind == "m"')
    for tag in s:current_tags
        let tag.filename = fnamemodify(tag.filename, ':p')
    endfor
    if g:oonav#debug_on | call s:Dbg("method/class tags found:" . string(s:current_tags)) | endif

    " Find what we are it the tags
    let my_tag = s:MyTag(s:current_tags)
    if my_tag isnot v:none
        " We're working on a specific kind of tags - 'c' or 'm'
        call filter(s:current_tags, {idx, val -> val.kind == my_tag.kind})
    else
        throw 'Did not find self tag for ' . a:name
    endif
    return my_tag
endfunction


function! s:PrepareDownTaglist(name)
    " Find this line in that list
    let my_tag = s:PrepareTaglist(a:name)
    if my_tag.kind == "m"
        let my_class = my_tag.class
    else
        throw "Only supporting methods"
    endif
    if g:oonav#debug_on | call s:Dbg("class is " . my_class) | endif

    " Remove self
    call filter(s:current_tags, {idx, val -> val.class != my_class})

    " Remove ones which our class is not a base for them
    call filter(s:current_tags, {idx, val -> count(s:GetBaseClasses(val.class), my_class)})
endfunction


function! s:PrepareUpTaglist(name)
    " Find this line in that list
    let my_tag = s:PrepareTaglist(a:name)
    if my_tag.kind == "m"
        let my_class = my_tag.class
    else
        throw "Only supporting methods"
    endif
    if g:oonav#debug_on | call s:Dbg("class is " . my_class) | endif
    let base_classes = s:GetBaseClasses(my_class)
    if g:oonav#debug_on | call s:Dbg("base classes are " . string(base_classes)) | endif

    " Remove self
    call filter(s:current_tags, {idx, val -> val.class != my_class})

    " Filter in only base_classes
    call filter(s:current_tags, {idx, val -> count(base_classes, val.class)})
endfunction


function! s:NavOptions(name, direction)
    let list = []

    call s:Prepare{a:direction}Taglist(a:name)

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
    if tag.kind == "m"
        " Try to jump to the class first if its in the same file
        let class_tags = filter(taglist('\<' . tag.class . '$'),
                    \ {idx, val -> val.kind == "c" && val.filename == tag.filename})
        if g:oonav#debug_on | call s:Dbg("class_tags are " . string(class_tags)) | endif
        exe 'e ' tag.filename
        exe 'goto 1'
        if ! empty(class_tags)
            exe class_tags[0].cmd
        endif
        exe tag.cmd
        normal z
    else
        exe 'e ' tag.filename
        exe 'goto 1'
        exe tag.cmd
        normal z
    endif
endfunction


" Handles the fzf choice
function! s:FzfSink(choice)
    let i = matchstr(a:choice, '^\d\+') - 1
    call s:GotoTag(i)
endfunction


" Main entry point from outside - nav Down/Up for name under cursor
function! s:Nav(name, direction)
    call s:ClearCache()
    let options = s:NavOptions(a:name, a:direction)
    if g:oonav#debug_on | call s:Dbg("options are " . string(options)) | endif
    let l = len(options)
    if l
        if l == 1
            call s:GotoTag(0)
        else
            if g:oonav#allow_fzf && exists('*g:fzf#wrap')
                let fzf_options = ''
                if g:oonav#allow_fzf_preview
                    let method_patterns=''
                    for tag in s:current_tags
                        let method_patterns .= tag.cmd
                    endfor
                    let class_patterns=''
                    for tag in s:current_tags
                        let class_patterns .= s:base_classes[tag.class].tag.cmd
                        if g:oonav#debug_on | call s:Dbg("new class pattern " . s:base_classes[tag.class].tag.cmd) | endif
                    endfor
                    let fzf_options = ['--ansi',
                                \ '--prompt', 'Navigate' . a:direction . '?>',
                                \ '--preview',
                                \ s:PreviewExe() . " '" . method_patterns .
                                \ "' '" . class_patterns . "' {} 50",
                                \ '--preview-window=down:50%']
                    if g:oonav#debug_on | call s:Dbg("fzf_options are " . string(fzf_options)) | endif
                endif
                call fzf#run(fzf#wrap({'source': options,
                            \ 'sink': funcref('<SID>FzfSink'),
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

nnoremap <script> <Plug>(oonav-down)  <SID>NavDown
nnoremap <silent> <SID>NavDown  :call <SID>Nav(expand("<cword>"), 'Down')<CR>

nnoremap <script> <Plug>(oonav-up)  <SID>NavUp
nnoremap <silent> <SID>NavUp  :call <SID>Nav(expand("<cword>"), 'Up')<CR>

if g:oonav#create_mappings
    " map \gd (goto derived down the class hierarchy)
    if !hasmapto('<Plug>(oonav-down)')
        map <unique> <Leader>gd  <Plug>(oonav-down)
    endif

    " map \gb (goto base up the class hierarchy)
    if !hasmapto('<Plug>(oonav-up)')
        map <unique> <Leader>gb  <Plug>(oonav-up)
    endif
endif

" restore compatible option
let &cpo = s:save_cpo
unlet s:save_cpo

