vim9script

import autoload 'minimap.vim'

export def OnWinScrolled()
  for id in keys(v:event)
    final m: minimap.Minimap = minimap.GetMinimap(str2nr(id))
    if !!m
      m.OnWinScrolled()
    endif
  endfor
enddef


export def OnBufWinEnter()
  final m: minimap.Minimap = minimap.GetMinimap(win_getid())
  if !!m
    m.OnBufWinEnter()
  endif
enddef


export def OnWinClosed()
  const winid = expand('<amatch>')->str2nr()
  final m: minimap.Minimap = minimap.GetMinimap(winid)
  if !!m
    m.OnWinClosed()
  endif
enddef


# vim: et sw=2 sts=-1
