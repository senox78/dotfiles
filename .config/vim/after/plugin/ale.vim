" ALE extensions for tools that are part of this dotfiles environment but do
" not have upstream ALE definitions.
if exists(':ALEInfo') != 2
  finish
endif

function! s:FindProjectRoot(buffer, markers) abort
  for marker in a:markers
    let path = ale#path#FindNearestFile(a:buffer, marker)
    if !empty(path)
      return fnamemodify(path, ':h')
    endif
  endfor
  return fnamemodify(bufname(a:buffer), ':p:h')
endfunction

call ale#linter#Define('nix', {
      \ 'name': 'nil',
      \ 'lsp': 'stdio',
      \ 'executable': 'nil',
      \ 'command': '%e',
      \ 'project_root': {buffer -> s:FindProjectRoot(buffer, ['flake.nix', 'default.nix'])},
      \ })

call ale#linter#Define('typst', {
      \ 'name': 'tinymist',
      \ 'lsp': 'stdio',
      \ 'executable': 'tinymist',
      \ 'command': '%e lsp',
      \ 'project_root': {buffer -> s:FindProjectRoot(buffer, ['typst.toml'])},
      \ })

function! s:TaploFix(buffer) abort
  return {
        \ 'command': 'taplo format --colors never --stdin-filepath %s -',
        \ }
endfunction

call ale#fix#registry#Add(
      \ 'taplo',
      \ expand('<SID>') . 'TaploFix',
      \ ['toml'],
      \ 'Format TOML with Taplo'
      \ )
