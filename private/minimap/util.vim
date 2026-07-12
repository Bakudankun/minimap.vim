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

# vim: et sw=2 sts=-1 cc=+1
