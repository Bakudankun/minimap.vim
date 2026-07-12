vim9script

import autoload '../../private/minimap/util.vim'

final defaultConfig = {
  width: 10,
  cell_pixels: null_list,
  colors: {
    base: 'Pmenu',
    window: '',
    frame: '#ff0000ff',
  },
  point_height: 1,
  point_width: 1,
  line_space: 1,
  frame_width: 1,
  popup_options: {
    zindex: 10
  },
  hide_time: 1000,
}

var initialized: bool = false


export def Get(query: string): any
  if !initialized
    Init()
  endif
  if exists('g:minimap_config.' .. query)
    return eval('g:minimap_config.' .. query)
  endif
  return null
enddef


export def GetColor(hlName: string): dict<string>
  const synID = hlID(hlName)->synIDtrans()
  const fg = (synID->synIDattr('fg#')) .. 'ff'
  const bg = (synID->synIDattr('bg#')) .. 'ff'
  if synID->synIDattr('reverse')->str2nr()
    return {fg: bg, bg: fg}
  else
    return {fg: fg, bg: bg}
  endif
enddef


def Init()
  if !exists('g:minimap_config')
    g:minimap_config = {}
  endif

  util.Extend(g:minimap_config, defaultConfig, 'keep')
  initialized = true
enddef


# vim: et sw=2 sts=-1
