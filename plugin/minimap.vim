if !has('image')
  echoerr 'Minimap requires Vim 9.2+ with +image support'
  finish
endif

vim9script

import autoload 'minimap.vim'
import autoload '../private/minimap/autocmd.vim'

command -bar MinimapOpen minimap.Open()
command -bar MinimapClose minimap.Close()

augroup Minimap
  autocmd!
  autocmd WinScrolled * autocmd.OnWinScrolled()
  autocmd BufWinEnter * autocmd.OnBufWinEnter()
  autocmd WinClosed * autocmd.OnWinClosed()
augroup END


# vim: et sw=2 sts=-1
