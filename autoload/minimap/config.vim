vim9script

import autoload '../../private/minimap/util.vim'

final defaultConfig = {
  width: 10,
  cell_pixels: null_list,
  colors: {
    base: 'Pmenu',
    window: '',
    frame: '#ff0000',
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


export def GetColorConfig(kind: string): dict<blob>
  var config: any = Get('colors.' .. kind)
  if type(config) != v:t_string && type(config) != v:t_dict
    throw $"Invalid configuration for {kind} color."
  endif

  # If the config is a string, get fg/bg colors of named highlight group.
  if type(config) == v:t_string
    const synID = hlID(config)->synIDtrans()
    if synID == 0
      throw $'Unknown highlight group for {kind} color: "{config}"'
    endif
    config = {
      fg: synID->synIDattr('fg#'),
      bg: synID->synIDattr('bg#'),
    }
    if synID->synIDattr('reverse')->str2nr()
      [config.fg, config.bg] = [config.bg, config.fg]
    endif
  endif

  # If colors are not in hex format, try to get them from color names.
  if config.fg[0] != '#'
    config.fg = v:colornames->get(config.fg->tolower(), config.fg)
    if config.fg[0] != '#'
      throw $"Unknown color name for {kind}.fg: \"{config.fg}\"\nYou may need to specify the colors in hex format."
    endif
  endif
  if config.bg[0] != '#'
    config.bg = v:colornames->get(config.bg->tolower(), config.bg)
    if config.bg[0] != '#'
      throw $"Unknown color name for {kind}.bg: \"{config.bg}\"\nYou may need to specify the colors in hex format."
    endif
  endif

  # If colors do not have alpha channel, add it.
  if config.fg =~ '^#\x\{6}$'
    config.fg ..= 'ff'
  endif
  if config.bg =~ '^#\x\{6}$'
    config.bg ..= 'ff'
  endif

  # If the result is not valid, return null.
  if config.fg !~ '^#\x\{8}$' || config.bg !~ '^#\x\{8}$'
    throw $'Invalid {kind} color configuration: {config}'
  endif

  return config->mapnew((k, v: string): blob => eval('0z' .. v[1 :]))
enddef


def Init()
  if !exists('g:minimap_config')
    g:minimap_config = {}
  endif

  util.Extend(g:minimap_config, defaultConfig, 'keep')
  initialized = true
enddef


# vim: et sw=2 sts=-1
