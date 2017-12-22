# Copyright 2009 The Go Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# Package utf8 implements functions and constants to support text encoded in
# UTF-8. It includes functions to translate between runes and UTF-8 byte sequences.
# package utf8

# The conditions RuneError==unicode.ReplacementChar and
# MaxRune==unicode.MaxRune are verified in the tests.
# Defining them locally avoids this package depending on package unicode.

import strutils

converter toChar(x: uint8): char = result = chr(x)
converter toInt(x: char): uint8 = result = ord(x).uint8

type rune* {.borrow.} = int32

# proc `$`*(r: rune): string =
#   return $(int32(r))
# proc `==`*(a, b: rune): bool =
#   return int32(a) == int32(b)

# Numbers fundamental to the encoding.
const 
  RuneError* = 0xFFFD     # the "error" Rune or "Unicode replacement character"
  RuneSelf*  = 0x80         # characters below Runeself are represented as themselves in a single byte.
  MaxRune*   = 0x0010FFFF # Maximum valid Unicode code point.
  UTFMax*    = 4            # maximum number of bytes of a UTF-8 encoded Unicode character.


# Code points in the surrogate range are not valid for UTF-8.
const 
  surrogateMin* = 0xD800
  surrogateMax* = 0xDFFF

const 
  t1* = 0x00 # 0000 0000
  tx* = 0x80 # 1000 0000
  t2* = 0xC0 # 1100 0000
  t3* = 0xE0 # 1110 0000
  t4* = 0xF0 # 1111 0000
  t5* = 0xF8 # 1111 1000

  maskx = 0x3F # 0011 1111
  mask2 = 0x1F # 0001 1111
  mask3 = 0x0F # 0000 1111
  mask4 = 0x07 # 0000 0111

  rune1Max = 1 shl 7 - 1
  rune2Max = 1 shl 11 - 1
  rune3Max = 1 shl 16 - 1

  # The default lowest and highest continuation byte.
  locb = 0x80'u8 # 1000 0000
  hicb = 0xBF'u8 # 1011 1111

  # These names of these constants are chosen to give nice alignment in the
  # table below. The first nibble is an index into acceptRanges or F for
  # special one-byte cases. The second nibble is the Rune length or the
  # Status for the special one-byte case.
  xx = 0xF1'u8 # invalid: size 1
  aa = 0xF0'u8 # ASCII: size 1
  s1 = 0x02'u8 # accept 0, size 2
  s2 = 0x13'u8 # accept 1, size 3
  s3 = 0x03'u8 # accept 0, size 3
  s4 = 0x23'u8 # accept 2, size 3
  s5 = 0x34'u8 # accept 3, size 4
  s6 = 0x04'u8 # accept 0, size 4
  s7 = 0x44'u8 # accept 4, size 4


# first is information about the first byte in a UTF-8 sequence.
var first: array[256, uint8] = [
  #    1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
  aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, # 0x00-0x0F
  aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, # 0x10-0x1F
  aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, # 0x20-0x2F
  aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, # 0x30-0x3F
  aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, # 0x40-0x4F
  aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, # 0x50-0x5F
  aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, # 0x60-0x6F
  aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, aa, # 0x70-0x7F
  #    1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
  xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, # 0x80-0x8F
  xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, # 0x90-0x9F
  xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, # 0xA0-0xAF
  xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, # 0xB0-0xBF
  xx, xx, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, # 0xC0-0xCF
  s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, # 0xD0-0xDF
  s2, s3, s3, s3, s3, s3, s3, s3, s3, s3, s3, s3, s3, s4, s3, s3, # 0xE0-0xEF
  s5, s6, s6, s6, s7, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, # 0xF0-0xFF
]

# acceptRange gives the range of valid values for the second byte in a UTF-8
# sequence.
type acceptRange = tuple
  lo: uint8 # lowest value for second byte.
  hi: uint8 # highest value for second byte.


const acceptRanges: seq[acceptRange] = @[
  (locb, hicb),
  (0xA0'u8, hicb),
  (locb, 0x9F'u8),
  (0x90'u8, hicb),
  (locb, 0x8F'u8),
]

template ones(n: untyped): untyped = ((1 shl n)-1)

proc FullRune*(p: string): bool =
  ## FullRune reports whether the bytes in p begin with a full UTF-8 encoding of a rune.
  ## An invalid encoding is considered a full Rune since it will convert as a width-1 error rune.

  let n = len(p)
  if n == 0:
    return false
  
  let x = first[ord(p[0])]
  if n >= int(x and 7):
    return true # ASCII, invalid or valid.
  
  # Must be short or invalid.
  let accept = acceptRanges[int(x shr 4)]
  if n > 1:
    let c = p[1]
    if c < accept.lo or accept.hi < c:
      return true
    elif n > 2 and (p[2] < locb or hicb < p[2]):
      return true    
  return false


proc FullRuneInString*(s: string): bool = FullRune(s)
  ## FullRuneInString is like FullRune but its input is a string.


proc DecodeRune*(p: string): tuple[r: rune, size: int] =
  ## DecodeRune unpacks the first UTF-8 encoding in p and returns the rune and
  ## its width in bytes. If p is empty it returns (RuneError, 0). Otherwise, if
  ## the encoding is invalid, it returns (RuneError, 1). Both are impossible
  ## results for correct, non-empty UTF-8.
  ##
  ## An encoding is invalid if it is incorrect UTF-8, encodes a rune that is
  ## out of range, or is not the shortest possible UTF-8 encoding for the
  ## value. No other validation is performed.

  let n = len(p)
  if n < 1:
    return (rune(RuneError), 0)
  
  let p0 = ord(p[0])
  let x = first[p0]

  if x >= aa:
    ## The following code simulates an additional check for x == xx and
    ## handling the ASCII and invalid cases accordingly. This mask-and-or
    ## approach prevents an additional branch.
    var mask: uint32
    if p0 >= 0x80:
      mask = ones(32)
    else:
      mask = 0
    #let mask = rune(x) shl 31 shr 31 # Create 0x0000 or 0xFFFF.

    let rslt = (int32((uint32(p0) and `not`(mask)) or (RuneError.uint32 and mask)), 1)
    return rslt

  let sz = x and 7
  let accept = acceptRanges[int(x shr 4)]
  if n < int(sz):
    return (rune(RuneError), 1)
  
  let b1 = uint8(p[1])
  if b1 < accept.lo or accept.hi < b1:
    return (rune(RuneError), 1)
  
  if sz == 2:
    return (rune(((int(p0) and mask2) shl 6) or (b1 and maskx).int), 2)
  
  let b2 = uint8(p[2])
  if b2 < locb or hicb < b2:
    return (rune(RuneError), 1)
  
  if sz == 3:
    return (rune(((int(p0) and mask3) shl 12) or ((int(b1) and maskx) shl 6) or (int(b2) and maskx)), 3)
  
  let b3 = uint8(p[3])
  if b3 < locb or hicb < b3:
    return (rune(RuneError), 1)
  
  return (rune(((int(p0) and mask4) shl 18) or 
          (int(b1) and maskx) shl 12 or 
          (int(b2) and maskx) shl 6 or 
          (int(b3) and maskx)), 4)


proc DecodeRuneInString*(s: string): tuple[r: rune, size: int] = DecodeRune(s)
  ## DecodeRuneInString is like DecodeRune but its input is a string. If s is
  ## empty it returns (RuneError, 0). Otherwise, if the encoding is invalid, it
  ## returns (RuneError, 1). Both are impossible results for correct, non-empty
  ## UTF-8.
  ##
  ## An encoding is invalid if it is incorrect UTF-8, encodes a rune that is
  ## out of range, or is not the shortest possible UTF-8 encoding for the
  ## value. No other validation is performed.

proc RuneStart*(b: char): bool =
  ## RuneStart reports whether the byte could be the first byte of an encoded,
  ## possibly invalid rune. Second and subsequent bytes always have the top two
  ## bits set to 10.
  return (b and 0xC0) != 0x80

proc DecodeLastRune*(p: string): tuple[r: rune, size: int] =
  ## DecodeLastRune unpacks the last UTF-8 encoding in p and returns the rune and
  ## its width in bytes. If p is empty it returns (RuneError, 0). Otherwise, if
  ## the encoding is invalid, it returns (RuneError, 1). Both are impossible
  ## results for correct, non-empty UTF-8.
  ##
  ## An encoding is invalid if it is incorrect UTF-8, encodes a rune that is
  ## out of range, or is not the shortest possible UTF-8 encoding for the
  ## value. No other validation is performed.

  let endp = len(p)
  if endp == 0:
    return (rune(RuneError), 0)
  
  var start = endp - 1
  var r = uint8(p[start])
  if r < RuneSelf:
    return (rune(r), 1)
  
  # guard against O(n^2) behavior when traversing
  # backwards through strings with long sequences of
  # invalid UTF-8.
  var lim = endp - UTFMax
  if lim < 0:
    lim = 0
  
  dec(start)
  while start >= lim:
  #for start--; start >= lim; start-- {
    if RuneStart(p[start]):
      break
    dec(start)  
  
  if start < 0:
    start = 0
  
  var r1: rune
  var size: int
  (r1, size) = DecodeRune(p[start..endp-1])
  if start + size != endp:
    return (rune(RuneError), 1)
  
  return (r1, size)


proc DecodeLastRuneInString*(s: string): tuple[r: rune, size: int] =
  ## DecodeLastRuneInString is like DecodeLastRune but its input is a string. If
  ## s is empty it returns (RuneError, 0). Otherwise, if the encoding is invalid,
  ## it returns (RuneError, 1). Both are impossible results for correct,
  ## non-empty UTF-8.
  ##
  ## An encoding is invalid if it is incorrect UTF-8, encodes a rune that is
  ## out of range, or is not the shortest possible UTF-8 encoding for the
  ## value. No other validation is performed.
  return DecodeLastRune(s)


proc RuneLen*(r: rune): int =
  ## RuneLen returns the number of bytes required to encode the rune.
  ## It returns -1 if the rune is not a valid value to encode in UTF-8.
  var r = int32(r)
  if r < 0:
    return -1
  elif r <= rune1Max:
    return 1
  elif r <= rune2Max:
    return 2
  elif surrogateMin <= r and r <= surrogateMax:
    return -1
  elif r <= rune3Max:
    return 3
  elif r <= MaxRune:
    return 4
  
  return -1


proc EncodeRune*(p: var string, r: rune): int =
  ## EncodeRune writes into p (which must be large enough) the UTF-8 encoding of the rune.
  ## It returns the number of bytes written.

  var r = int32(r)
  # Negative values are erroneous. Making it unsigned addresses the problem.
  let i = uint32(r)
  if i <= rune1Max:
    p[0] = char(r)
    return 1
  elif i <= rune2Max:
    # _ = p[1] # eliminate bounds checks
    p[0] = char(t2 or (r shr 6))
    p[1] = char(tx or (r and maskx))
    return 2
  elif i > uint32(MaxRune) or (surrogateMin.uint32 <= i and i <= surrogateMax.uint32):
    r = RuneError
#    fallthrough
    p[0] = char(t3 or (r shr 12))
    p[1] = char(tx or (r shr 6) and maskx)
    p[2] = char(tx or (r) and maskx)
    return 3
  elif i <= rune3Max:
    # _ = p[2] # eliminate bounds checks
    p[0] = char(t3 or (r shr 12))
    p[1] = char(tx or (r shr 6) and maskx)
    p[2] = char(tx or (r) and maskx)
    return 3
  else:
    # _ = p[3] // eliminate bounds checks
    p[0] = char(t4 or (r shr 18))
    p[1] = char(tx or (r shr 12) and maskx)
    p[2] = char(tx or (r shr 6) and maskx)
    p[3] = char(tx or r and maskx)
    return 4


proc RuneCount*(p: string): int {.gcsafe.} =
  ## RuneCount returns the number of runes in p. Erroneous and short
  ## encodings are treated as single runes of width 1 byte.

  let np = len(p)
  var n: int
  var i = 0
  while i < np:
  # for i := 0; i < np; {
    inc(n)
    var c = uint8(p[i])
    if c < RuneSelf:
      ## ASCII fast path
      inc(i)
      continue
    
    let x = first[c]
    if x == xx:
      inc(i) # invalid.
      continue
    
    var size = int(x and 7)
    if i + size > np:
      inc(i) # Short or invalid.
      continue
    
    let accept = acceptRanges[int(x shr 4)]
    c = p[i+1]
    if c < accept.lo or accept.hi < c:
      size = 1
    elif size == 2:
      discard
    else: 
      c = p[i+2]
      if c < locb or hicb < c:
        size = 1
      elif size == 3:
        discard
      else:
        c = p[i+3]
        if c < locb or hicb < c:
          size = 1
    
    i += size
  
  return n


proc RuneCountInString*(s: string): int =
  ## RuneCountInString is like RuneCount but its input is a string.
  return RuneCount(s)


proc Valid*(p: string): bool =
  ## Valid reports whether p consists entirely of valid UTF-8-encoded runes.
  let n = len(p)
  var i = 0
  while i < n:
  # for i := 0; i < n; {
    let pi = uint8(p[i])
    if pi < RuneSelf:
      inc(i)
      continue
    
    let x = first[pi]
    if x == xx:
      return false # Illegal starter byte.
    
    var size = int(x and 7)
    if i + size > n:
      return false # Short or invalid.
    
    var accept = acceptRanges[int(x shr 4)]

    var c = p[i+1]
    if c < accept.lo or accept.hi < c:
      return false
    elif size == 2:
      discard
    else:
      c = p[i + 2]
      if c < locb or hicb < c:
        return false
      elif size == 3:
        discard
      else:
        c = p[i + 3]
        if c < locb or hicb < c:
          return false    
    i += size
  return true


proc ValidString*(s: string): bool =
  ## ValidString reports whether s consists entirely of valid UTF-8-encoded runes.
  return Valid(s)


proc ValidRune*(r: rune): bool =
  ## ValidRune reports whether r can be legally encoded as UTF-8.
  ## Code points that are out of range or a surrogate half are illegal.
  var r = int32(r)
  if 0 <= r and r < surrogateMin:
    return true
  elif surrogateMax < r and r <= MaxRune:
    return true
  return false

