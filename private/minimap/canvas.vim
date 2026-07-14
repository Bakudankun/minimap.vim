vim9script


# Canvas class to manipulate images.
# Currently not working because of bugs of Vim9 script.
export class Canvas
  final canvas: blob
  var width: number
  var height: number
  const numChannels: number = 3

  def new(this.width, this.height, this.numChannels = v:none)
    this.canvas = repeat(0z00, this.width * this.height * this.numChannels)
  enddef

  def newFromBlob(blob: blob, this.width, this.height, this.numChannels = v:none)
    if len(blob) != this.width * this.height * this.numChannels
      throw 'Length of color must be ' .. this.numChannels
    endif
    this.canvas = copy(blob)
  enddef

  def GetLineSize(): number
    return this.width * this.numChannels
  enddef

  def DrawRect(start: tuple<number, number>, end: tuple<number, number>, color: blob)
    if len(color) != this.numChannels
      throw 'Length of color must be ' .. this.numChannels
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
      const startIdx = (y * this.width + startX) * this.numChannels
      this.DrawBlob(startIdx, oneLine)
    endfor
  enddef

  def DrawLines(pos: number, lines: blob)
    const lineSize = this.GetLineSize()
    if len(lines) % lineSize != 0
      throw 'tried to draw invalid length'
    endif
    this.DrawBlob(pos * lineSize, lines)
  enddef

  def DrawBlob(idx: number, blob: blob)
    this.canvas[idx : idx + len(blob) - 1] = blob
  enddef

  def AddLines(lines: blob)
    const lineSize = this.GetLineSize()
    if len(lines) % lineSize != 0
      throw 'tried to insert invalid length'
    endif
    this.canvas += lines
    this.height += len(lines) / lineSize
  enddef

  def InsertLines(pos: number, lines: blob)
    const lineSize = this.GetLineSize()
    const blobSize = len(lines)
    if blobSize % lineSize != 0
      throw 'tried to insert invalid length'
    endif
    this.canvas += this.canvas[-blobSize : -1]
    this.DrawBlob(pos * lineSize,
      lines + this.canvas->slice(pos * lineSize, this.height * lineSize - blobSize))
    this.height += blobSize / lineSize
  enddef

  def InsertZero(pos: number, lineCount: number)
    const lineSize = this.GetLineSize()
    InsertLines(pos, repeat(0z00, lineSize * lineCount))
  enddef

  def RemoveLines(start: number, end: number): blob
    const lineSize = this.GetLineSize()
    return this.canvas->remove(start * lineSize, end * lineSize - 1)
  enddef

  def GetRegion(start: number, end: number): Canvas
    const lineSize = this.GetLineSize()
    const startIdx = start * lineSize
    const endIdx = end * lineSize
    return Canvas.newFromBlob(
      this.canvas->slice(startIdx, endIdx),
      this.width,
      end - start)
  enddef

  def Scale(scale: tuple<number, number>): Canvas
    const lineSize = this.GetLineSize()
    final ret = Canvas.new(this.width * scale[0], this.height * scale[1], this.numChannels)
    for y in range(this.height)
      var line: blob = repeat(0z00, lineSize * scale[0])
      for x in range(this.width)
        line[x * scale[0] * this.numChannels : (x + 1) * scale[0] * this.numChannels - 1] =
          repeat(GetPixel(x, y), scale[0])
      endfor
    endfor
  enddef

  def GetPixel(coord: tuple<number, number>): blob
    const startIdx = (coord[1] * this.width + coord[0]) * this.numChannels
    return this.canvas->slice(startIdx, startIdx + this.numChannels)
  enddef

  def SetPixel(coord: tuple<number, number>, color: blob)
    if len(color) != this.numChannels
      throw 'Length of color must be ' .. this.numChannels
    endif
    const lineSize = this.GetLineSize()
    const startIdx = (coord[1] * this.width + coord[0]) * this.numChannels
    this.canvas[startIdx, startIdx + this.numChannels - 1] = color
  enddef
endclass


# vim: et sw=2 sts=-1
