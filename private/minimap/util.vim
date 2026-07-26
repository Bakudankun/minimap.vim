vim9script


# Extend dictionaries recursively. (in-place)
export def Extend(base: dict<any>, merge: dict<any>, mode: string = 'force')
  for [key, val] in items(merge)
    if !base->has_key(key) || base[key] == null
      base[key] = val->deepcopy()
      continue
    endif

    if type(base[key]) == v:t_dict && type(val) == v:t_dict && val != null
      base[key]->Extend(val, mode)
      continue
    endif

    if mode ==# 'force'
      base[key] = val->deepcopy()
    endif
  endfor
enddef


export def DoAutocmd(event: string)
  if exists('#User#Minimap' .. event)
    :doautocmd event
  endif
enddef


var win_call_ret: any
var WinCallFunc: func

# Call a function in the specified window.
# Returns its result.
export def WinCall(winid: number, Func: func): any
  if winid == win_getid()
    return Func()
  endif
  WinCallFunc = Func
  win_execute(winid, 'win_call_ret = WinCallFunc()')
  return win_call_ret
enddef


export def GetHighlightColor(highlight: string): dict<string>
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


# vim: et sw=2 sts=-1 cc=+1
