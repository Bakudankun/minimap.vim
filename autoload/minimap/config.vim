vim9script

import autoload '../../private/minimap/util.vim'

final defaultConfig = {
  width: 10,
  cell_pixels: null_list,
  colors: {
    base: 'Pmenu',
    window: '',
    frame: '#ff0000',
    fold: '',
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
  if !exists('g:minimap_config.' .. query)
    Init()
  endif
  return eval('g:minimap_config.' .. query)
enddef


export def ParseColorConfig(kind: string): dict<blob>
  const config: any = Get('colors.' .. kind)
  if type(config) != v:t_string && typename(config) != 'dict<string>'
    throw $"Invalid configuration for {kind} color."
  endif

  final color: dict<string> = {}

  # If the config is a string, get fg/bg colors of named highlight group.
  if type(config) == v:t_string
    try
      color->extend(GetHighlightColor(config))
    catch
      throw $'Unknown highlight group for {kind} color: "{config}"'
    endtry
  else
    color->extend(config)
  endif

  const normalColor = GetHighlightColor('Normal')

  for key in ['fg', 'bg']
    # If the color information is empty, fallback to the Normal color.
    if get(color, key, '') == ''
      color[key] = normalColor[key]
    endif

    # If colors are not in hex format, try to get them from color names.
    if color[key][0] != '#'
      color[key] = v:colornames->get(color[key]->tolower(), color[key])
    endif

    # If colors do not have alpha channel, add it.
    if len(color[key]) < 9
      color[key] ..= 'ff'
    endif

    # If still invalid, fallback to hardcoded colors.
    if color[key] !~ '^#\x\{8}$'
      echoerr $'minimap.vim: failed to resolve color for {kind} {key}. Fallback to the default.' |
            \ echoerr 'See `:help g:minimap_config.colors` to customize the colors.'
      color[key] = (key == 'bg') == (&background == 'light') ? '#ffffffff' : '#000000ff'
    endif
  endfor

  return color->mapnew((k, v: string): blob => eval('0z' .. v[1 :]))
enddef


def Init()
  if !exists('g:minimap_config')
    g:minimap_config = {}
  endif

  util.Extend(g:minimap_config, defaultConfig, 'keep')
  initialized = true
enddef


def GetHighlightColor(highlight: string): dict<string>
  const synID = hlID(highlight)->synIDtrans()
  if synID == 0
    throw $"Unknown highlight group: {highlight}"
  endif
  final ret: dict<string> = {
    fg: synID->synIDattr('fg#', 'gui'),
    bg: synID->synIDattr('bg#', 'gui'),
  }
  if synID->synIDattr('reverse', 'gui')->str2nr()
    [ret.fg, ret.bg] = [ret.bg, ret.fg]
  endif
  return ret
enddef


# vim: et sw=2 sts=-1
