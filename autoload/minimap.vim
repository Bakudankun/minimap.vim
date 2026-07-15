vim9script

import autoload 'minimap/config.vim'
import autoload '../private/minimap/util.vim'


export class Minimap
  var canvas: blob
  var width: number
  var height: number
  var listener: number
  var hideTimer: number
  const winid: number
  const parent: number
  const baseColor: dict<blob>
  const windowColor: dict<blob>
  const frameColor: blob
  const foldColor: dict<blob>
  const pointHeight: number
  const pointWidth: number
  const lineSpace: number
  const frameWidth: number
  static const NUM_CHANNELS = 4
  static var _drawingImg: blob
  static var _refImg: blob
  static var _currentCropInfo: dict<any>

  static def Open(parent: number): Minimap
    var minimap: Minimap = getwinvar(win_getid(), 'minimap', null_object)
    if !minimap
      minimap = Minimap._new(parent)
    endif
    return minimap
  enddef

  def Close()
    popup_close(this.winid)
    this._Delete()
  enddef

  def Show()
    popup_show(this.winid)
  enddef

  def Hide()
    popup_hide(this.winid)
  enddef

  def Redraw()
    _UpdatePopup()
  enddef

  def IsValid(): bool
    if win_gettype(this.winid) != 'popup' || getwininfo(this.parent)->len() <= 0
      return false
    endif
    return true
  enddef

  def OnWinScrolled()
    if !this.IsValid()
      this._Delete()
      return
    endif

    this._UpdatePopup()
    if stridx('iR', mode()) < 0
      this.Show()
      if !!config.Get('hide_time')
        this._StartHideTimer()
      endif
    endif
  enddef

  def OnBufWinEnter()
    if !this.IsValid()
      this._Delete()
      return
    endif

    listener_remove(this.listener)
    this._DrawAllLines()
    this._MakeListener()
    this._UpdatePopup()
    this.Show()
    if !!config.Get('hide_time')
      this._StartHideTimer()
    endif
  enddef

  def OnWinClosed()
    this.Close()
  enddef

  def _new(parent: number)
    this.parent = parent

    this.baseColor = config.GetColorConfig('base')
    if !config.Get('colors.window')->empty()
      this.windowColor = config.GetColorConfig('window')
    endif
    if !config.Get('colors.fold')->empty()
      this.foldColor = config.GetColorConfig('fold')
    endif

    var frame: string = config.Get('colors.frame')
    if frame[0] != '#'
      frame = v:colornames->get(frame->tolower(), frame)
      if frame[0] != '#'
        throw $"Unknown color name for frame: \"{frame}\"\nYou may need to specify the colors in hex format."
      endif
    endif
    if frame =~ '^#\x\{6}$'
      frame ..= 'ff'
    endif
    if frame !~ '^#\x\{8}$'
      throw $"Invalid frame color format: {frame}"
    endif
    this.frameColor = eval('0z' .. frame[1 :])

    this.pointHeight = config.Get('point_height')
    this.pointWidth = config.Get('point_width')
    this.lineSpace = config.Get('line_space')
    this.frameWidth = config.Get('frame_width')
    this.winid = this._CreatePopup()
    this._DrawAllLines()
    this._MakeListener()
    this._UpdatePopup()
    this.Show()
    if !!config.Get('hide_time')
      this._StartHideTimer()
    endif
  enddef

  def _CreatePopup(): number
    const tabnr = win_id2tabwin(this.parent)[0]
    final opts: dict<any> = {
      hidden: true,
      pos: 'topright',
      tabpage: tabnr,
    }
    util.Extend(opts, config.Get('popup_options'), 'keep')
    const winid = popup_create('', opts)
    if !winid
      throw 'Failed to create popup window'
    endif
    setwinvar(winid, 'minimap', this)
    setwinvar(this.parent, 'minimap', this)
    return winid
  enddef

  def _UpdatePopup()
    if !this.IsValid()
      this._Delete()
      return
    endif

    const pos = this._DesiredPos()
    const cropInfo = this._CalcCropInfo()
    const lineSize = this.width * NUM_CHANNELS
    _currentCropInfo = cropInfo
    _refImg = this.canvas->slice(cropInfo.start * lineSize, cropInfo.end * lineSize)
    _drawingImg = copy(_refImg)

    if !!this.windowColor
      this._HighlightWindow()
    endif
    if !!this.foldColor
      this._HighlightFolds()
    endif
    if !!this.frameColor && this.frameWidth > 0
      this._HighlightFrame()
    endif

    const height = len(_drawingImg) / lineSize

    g:minimap_draw_info = {
      minimap: this,
      height: height,
      num_channels: NUM_CHANNELS,
      img: _drawingImg,
    }
    util.DoAutocmd('Draw')
    unlet g:minimap_draw_info

    popup_setoptions(this.winid, {
      line: pos[0],
      col: pos[1],
      image: {
        data: _drawingImg,
        width: this.width,
        height: height,
      }})
  enddef

  def _StartHideTimer()
    timer_stop(this.hideTimer)
    this.hideTimer = timer_start(config.Get('hide_time'), this._HideTimerCallback)
  enddef

  def _HideTimerCallback(_: number)
    this.Hide()
    this.hideTimer = 0
  enddef

  def _DesiredDimension(): tuple<number, number>
    const lineCount = line('$', this.parent)
    const cellPixels = GetCellPixels()
    const lineHeight: number = this.pointHeight + this.lineSpace
    return (cellPixels[0] * config.Get('width'), lineHeight * lineCount)
  enddef

  def _DesiredPos(): tuple<number, number>
    const info = getwininfo(this.parent)[0]
    return (info.winrow + info.winbar, info.wincol + info.width - 1)
  enddef

  def _PrepareCanvas()
    const dimension = this._DesiredDimension()
    this.width = dimension[0]
    this.height = dimension[1]
    this.canvas = repeat(this.baseColor.bg, this.width * this.height)
  enddef

  def _DrawBufLines(start: number, end: number, redraw: bool = false)
    const lines = getbufline(winbufnr(this.parent), start, end)
    const width = this.width
    const lineHeight: number = this.pointHeight + this.lineSpace

    if redraw
      this._DrawRect(this.canvas, (0, (start - 1) * lineHeight), (this.width - 1, end * lineHeight - 1), this.baseColor.bg)
    endif

    for [idx, line] in items(lines)
      const sS = split(line, '\s\zs\ze\S\|\S\zs\ze\s')
      var col: number = 0
      for j in sS
        const strWidth = strdisplaywidth(j, col)
        if j[0] =~# '\S'
          const rectStart = (col * this.pointWidth, (idx + start - 1) * lineHeight)
          const rectEnd = ((col + strWidth) * this.pointWidth - 1, rectStart[1] + this.pointHeight - 1)
          this._DrawRect(this.canvas, rectStart, rectEnd, this.baseColor.fg)
        endif
        col += strWidth
        if col * this.pointWidth >= width
          break
        endif
      endfor
    endfor
  enddef

  def _DrawAllLines()
    this._PrepareCanvas()
    this._DrawBufLines(1, line('$', this.parent))
  enddef

  def _DrawRect(canvas: blob, start: tuple<number, number>, end: tuple<number, number>, color: blob)
    if len(color) != NUM_CHANNELS
      throw 'Length of color must be ' .. NUM_CHANNELS
    endif
    const startX = max([start[0], 0])
    const startY = max([start[1], 0])
    const endX = min([end[0], this.width - 1])
    const endY = min([end[1], this.height - 1])
    if startX >= this.width || startY >= this.height || endX < 0 || endY < 0 ||
        startX > endX || startY > endY
      return
    endif
    const oneLine = repeat(color, endX - startX + 1)
    for y in range(startY, endY)
      const startIdx = (y * this.width + startX) * NUM_CHANNELS
      const endIdx = startIdx + len(oneLine) - 1
      canvas[startIdx : endIdx] = oneLine
    endfor
  enddef

  def _CalcCropInfo(): dict<any>
    const wininfo = getwininfo(this.parent)[0]
    const cellPixels = GetCellPixels()
    const winHeight = cellPixels[1] * wininfo.height
    const lineSize = this.width * NUM_CHANNELS
    const lineHeight: number = this.pointHeight + this.lineSpace

    final ret: dict<any> = {
        wininfo: wininfo,
        winHeight: winHeight,
    }

    if this.height <= winHeight
      ret.start = 0
      ret.end = len(this.canvas) / lineSize
    else
      const midline = (wininfo.topline - 1 + wininfo.botline) * lineHeight / 2
      ret.start = min([max([midline - winHeight / 2, 0]), this.height - winHeight])
      ret.end = ret.start + winHeight
    endif

    ret.topline = ret.start / lineHeight + 1
    ret.botline = ret.end / lineHeight + (ret.end % lineHeight == 0 ? 0 : 1)

    return ret
  enddef

  def _MakeListener()
    this.listener = listener_add(this._ListenerCallback, winbufnr(this.parent))
  enddef

  def _ListenerCallback(_: number, _: number, _: number, _: number, changes: list<dict<number>>)
    if !this.IsValid()
      this._Delete()
      return
    endif

    const lineHeight: number = this.pointHeight + this.lineSpace
    for change in changes
      const added = change.added

      if added > 0
        const startIdx = this.width * (change.lnum - 1) * lineHeight * NUM_CHANNELS
        const addition = this.width * lineHeight * added
        this.canvas = this.canvas->slice(0, startIdx) + repeat(this.baseColor.bg, addition) + this.canvas->slice(startIdx)
        this._DrawBufLines(change.lnum, change.lnum + added - 1, true)
      elseif added < 0
        const startIdx = this.width * (change.lnum - 1) * lineHeight * NUM_CHANNELS
        remove(this.canvas, startIdx, startIdx + this.width * lineHeight * (- added) * NUM_CHANNELS - 1)
      else
        this._DrawBufLines(change.lnum, change.end - 1, true)
      endif
    endfor

    this.height = len(this.canvas) / NUM_CHANNELS / this.width

    this._UpdatePopup()
  enddef

  def HighlightLines(start: number, end: number, color: dict<blob>)
    const cropInfo = _currentCropInfo
    const lineHeight: number = this.pointHeight + this.lineSpace
    const lineSize = this.width * NUM_CHANNELS
    const startIdx: number = max([(start - 1) * lineHeight - cropInfo.start, 0]) * lineSize
    const endIdx: number = min([end * lineHeight - cropInfo.start, cropInfo.winHeight]) * lineSize

    if startIdx >= len(_drawingImg) || endIdx <= 0
      return
    endif

    for i in range(startIdx, min([endIdx - NUM_CHANNELS, len(_drawingImg) - NUM_CHANNELS]), NUM_CHANNELS)
      if _refImg->slice(i, i + NUM_CHANNELS) == this.baseColor.fg
        _drawingImg[i : i + NUM_CHANNELS - 1] = color.fg
      else
        _drawingImg[i : i + NUM_CHANNELS - 1] = color.bg
      endif
    endfor
  enddef

  def _HighlightWindow()
    const cropInfo = _currentCropInfo
    const wininfo: dict<any> = cropInfo.wininfo
    this.HighlightLines(wininfo.topline, wininfo.botline, this.windowColor)
  enddef

  def _HighlightFolds()
    const cropInfo = _currentCropInfo
    const wininfo: dict<any> = cropInfo.wininfo
    var lnum: number = cropInfo.topline
    while lnum <= cropInfo.botline
      const foldStart: number = util.WinCall(wininfo.winid, function('foldclosed', [lnum]))
      if foldStart != -1
        const foldEnd = util.WinCall(wininfo.winid, function('foldclosedend', [lnum]))
        this.HighlightLines(foldStart, foldEnd, this.foldColor)
        lnum = foldEnd + 1
      else
        lnum += 1
      endif
    endwhile
  enddef

  def _HighlightFrame()
    const cropInfo = _currentCropInfo
    const wininfo: dict<any> = cropInfo.wininfo
    const lineHeight: number = this.pointHeight + this.lineSpace
    const winStart: number = max([(wininfo.topline - 1) * lineHeight - cropInfo.start, 0])
    const winEnd: number = min([wininfo.botline * lineHeight - cropInfo.start, cropInfo.winHeight])
    const topleft = (0, winStart)
    const botright = (this.width - 1, winEnd - 1)
    const width = this.frameWidth - 1
    this._DrawRect(_drawingImg, topleft, (botright[0], topleft[1] + width), this.frameColor)
    this._DrawRect(_drawingImg, topleft, (topleft[0] + width, botright[1]), this.frameColor)
    this._DrawRect(_drawingImg, (botright[0] - width, topleft[1]), botright, this.frameColor)
    this._DrawRect(_drawingImg, (topleft[0], botright[1] - width), botright, this.frameColor)
  enddef

  def _Delete()
    listener_remove(this.listener)
    setwinvar(this.parent, 'minimap', null_object)
  enddef

  static def GetCellPixels(): list<number>
    return config.Get('cell_pixels') ?? getcellpixels() ?? [10, 20]
  enddef
endclass


export def Open()
  Minimap.Open(win_getid())
enddef


export def Close()
  final minimap: Minimap = GetMinimap(win_getid())
  if !!minimap
    minimap.Close()
  endif
enddef


export def GetMinimap(winid: number): Minimap
  # getwinvar()はどういうわけかタブページが閉じられる直前のWinClosedイベントで
  # 不正な値を返すのでgetwininfo()を使う
  final info = getwininfo(winid)
  if len(info) <= 0
    return null_object
  endif
  return get(info[0].variables, 'minimap', null_object)
enddef


# vim: et sw=2 sts=-1
