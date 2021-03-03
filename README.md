# oonav - Object Oriented Navigation for vim

## Description

* Navigate to method implementations in derived classes.
* Navigate to method in parent class.
* Use [fzf] - optional.
* Using tags, preferably for the entire project (keeping an updated tags for the
  project should be done manually or with another plugin).

![Naviagate to derived](nav.gif "Navigate to derived")

## Note

Without tags for the entire project this plugin has very little benefit.

## Install

`Plug 'sagi-z/oonav'`

## Configuration

```vim
" To disable default mappings creation use:
let g:oonav#create_mappings = 0

" If you don't want to allow fzf change the value to 0. The default is 1.
let g:oonav#allow_fzf = 1

" If you want to allow fzf without preview change the value to 0. The default
" is 1.
let g:oonav#allow_fzf_preview = 1

" oonav fzf tag preview is using perl. If 'perl' is not in your path the you can
" specify the full path here.
" The default is to use 'perl' from your PATH.
let g:oonav#perl = 'perl'
```

## Usage

These mappings are created by default:

```vim
"Goto derived (down the class hierarchy)
map <unique> <Leader>gd  <Plug>(oonav-down)

"Goto base (up the class hierarchy)
map <unique> <Leader>gb  <Plug>(oonav-up)
```

## License

MIT

[fzf]:   https://github.com/junegunn/fzf.vim

