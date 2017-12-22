## Copyright 2009 The Go Authors. All rights reserved.
## Use of this source code is governed by a BSD-style
## license that can be found in the LICENSE file.
##

## decimal to binary floating point conversion.
## Algorithm:
##   1) Store input in multiprecision decimal.
##   2) Multiply/divide decimal by powers of two until in range [0.5, 1)
##   3) Multiply by 2^precision and round to get mantissa.

import math
import strformat

import strconvTypes
import decimal
import extfloat
import float2bits
import ftoa

const optimize = false ## can change for testing

converter toInt(x: char): int = result = ord(x)
converter toChar(x: int): char = result = chr(x)

proc equalIgnoreCase(s1, s2: string): bool =
  if len(s1) != len(s2):
    return false

  for i in 0..high(s1):
    var c1 = s1[i]
    if 'A' <= c1 and c1 <= 'Z':
      c1 = c1 + ('a' - 'A')

    var c2 = s2[i]
    if 'A' <= c2 and c2 <= 'Z':
      c2 = c2 + ('a' - 'A')

    if c1 != c2:
      return false

  return true


proc special(s: string): (float64, bool) =
  if len(s) == 0:
    return

  case s[0]
  of '+':
    if equalIgnoreCase(s, "+inf") or equalIgnoreCase(s, "+infinity"):
      return (Inf, true)

  of '-':
    if equalIgnoreCase(s, "-inf") or equalIgnoreCase(s, "-infinity"):
      return (-Inf, true)

    if equalIgnoreCase(s, "-nan"):
      return (Nan, true)

  of 'n', 'N':
    if equalIgnoreCase(s, "nan"):
      return (NaN, true)

  of 'i', 'I':
    if equalIgnoreCase(s, "inf") or equalIgnoreCase(s, "infinity"):
      return (Inf, true)
  else:
    return(0.0, false)
  return


proc set(b: var decimal, s: string): bool =
  var i = 0
  b.neg = false
  b.trunc = false

  # optional sign
  if i >= len(s):
    return false

  if s[i] == '+':
    inc(i)
  elif s[i] == '-':
    b.neg = true
    inc(i)

  # digits
  var sawdot = false
  var sawdigits = false

  while i < len(s):
    if s[i] == '.':
      if sawdot:
        return
      sawdot = true
      b.dp = b.nd
      inc(i)
      continue

    elif '0' <= s[i] and s[i] <= '9':
      sawdigits = true
      if s[i] == '0' and b.nd == 0: # ignore leading zeros
        dec(b.dp)
        inc(i)
        continue

      if b.nd < len(b.d):
        b.d[b.nd] = s[i]
        inc(b.nd)
      elif s[i] != '0':
        b.trunc = true
      inc(i)
      continue

    break

  if not sawdigits:
    return false

  if not sawdot:
    b.dp = b.nd

  # optional exponent moves decimal point.
  # if we read a very large, very long number,
  # just be sure to move the decimal point by
  # a lot (say, 100000).  it doesn't matter if it's
  # not the exact number.
  if i < len(s) and (s[i] == 'e' or s[i] == 'E'):
    inc(i)
    if i >= len(s):
      return false

    var esign = 1
    if s[i] == '+':
      inc(i)
    elif s[i] == '-':
      inc(i)
      esign = -1

    if i >= len(s) or s[i] < '0' or s[i] > '9':
      return false

    var e = 0

    while i < len(s) and '0' <= s[i] and s[i] <= '9':
      if e < 10000:
        e = e*10 + (int(s[i]) - '0')
      inc(i)

    b.dp += e * esign

  if i != len(s):
    return false

  return true


## readFloat reads a decimal mantissa and exponent from a float
## string representation. It sets ok to false if the number could
## not fit return types or is invalid.
proc readFloat(s: string): tuple[mantissa: uint64, exp: int, neg, trunc, ok: bool] =
  const uint64digits = 19
  var i = 0

  # optional sign
  if i >= len(s):
    result.ok = false
    return

  if s[i] == '+':
    inc(i)
  elif s[i] == '-':
    result.neg = true
    inc(i)


  # digits
  var sawdot = false
  var sawdigits = false
  var nd = 0
  var ndMant = 0
  var dp = 0
  while i < len(s):
    let c = s[i]
    if c == '.':
      if sawdot:
        result.ok = false
        return

      sawdot = true
      dp = nd
      inc(i)
      continue

    if '0' <= c and c <= '9':
      sawdigits = true
      if c == '0' and nd == 0: # ignore leading zeros
        dec(dp)
        inc(i)
        continue

      inc(nd)
      if ndMant < uint64digits:
        result.mantissa *= 10
        result.mantissa += uint64(c - '0')
        inc(ndMant)
      elif s[i] != '0':
        result.trunc = true
      inc(i)
      continue
    elif c == '_':
      inc(i)
      continue

    break

  if not sawdigits:
    result.ok = false
    return

  if not sawdot:
    dp = nd


  ## optional exponent moves decimal point.
  ## if we read a very large, very long number,
  ## just be sure to move the decimal point by
  ## a lot (say, 100000).  it doesn't matter if it's
  ## not the exact number.
  if i < len(s) and (s[i] == 'e' or s[i] == 'E'):
    inc(i)
    if i >= len(s):
      result.ok = false
      return

    var esign = 1
    if s[i] == '+':
      inc(i)
    elif s[i] == '-':
      inc(i)
      esign = -1

    if i >= len(s) or s[i] < '0' or s[i] > '9':
      result.ok = false
      return

    var e = 0
    while i < len(s) and ('0' <= s[i] and s[i] <= '9'):
      if e < 10000:
        e = e*10 + int(s[i]) - '0'
      inc(i)

    dp += (e * esign)

  if i != len(s):
    result.ok = false
    return

  if result.mantissa != 0:
    result.exp = dp - ndMant

  result.ok = true
  return


# decimal power of ten to binary power of two.
const powtab = [1, 3, 6, 9, 13, 16, 19, 23, 26]

proc floatBits(d: var decimal, flt: floatInfo): tuple[b: uint64, overflow: bool] =
  var exp: int
  var mant: uint64

  var needMoreWork = true
  var haveOverflow = false

  # Zero is always a special case.
  if d.nd == 0:
    mant = 0
    exp = flt.bias
    needMoreWork = false

  block goOn:
    if needMoreWork:
      # Obvious overflow/underflow.
      # These bounds are for 64-bit floats.
      # Will have to change if we want to support 80-bit floats in the future.
      if d.dp > 310:
        haveOverflow = true
        break goOn

      if d.dp < -330:
        # zero
        mant = 0
        exp = flt.bias
        needMoreWork = false
        break goOn

      # Scale by powers of two until in range [0.5, 1.0)
      exp = 0
      while d.dp > 0:
        var n: int
        if d.dp >= len(powtab):
          n = 27
        else:
          n = powtab[d.dp]
        d.Shift(-n)
        exp += n

      while d.dp < 0 or d.dp == 0 and d.d[0] < '5':
        var n: int
        if -d.dp >= len(powtab):
          n = 27
        else:
          n = powtab[-d.dp]

        d.Shift(n)
        exp -= n

      # Our range is [0.5,1) but floating point range is [1,2).
      dec(exp)

      # Minimum representable exponent is flt.bias+1.
      # If the exponent is smaller, move it up and
      # adjust d accordingly.
      if exp < (flt.bias + 1):
        let n = flt.bias + 1 - exp
        d.Shift(-n)
        exp += n

      if (exp - flt.bias) >= ((1 shl flt.expbits) - 1):
        haveOverflow = true
        needMoreWork = false
        break goOn

      # Extract 1+flt.mantbits bits.
      d.Shift(int(1.uint + flt.mantbits))
      mant = d.RoundedInteger()

      # Rounding might have added a bit; shift down.
      if mant == (2.uint shl flt.mantbits):
        mant = mant shr 1
        inc(exp)
        if (exp - flt.bias) >= (1 shl flt.expbits - 1):
          haveOverflow = true
          break goOn

      # Denormalized?
      if (mant and (1.uint shl flt.mantbits)) == 0:
        exp = flt.bias

      break goOn

  if haveOverflow:
    # ±Inf
    mant = 0
    exp = (1 shl flt.expbits) - 1 + flt.bias
    result.overflow = true

  # Assemble bits.
  var bits = mant and ((uint64(1) shl flt.mantbits) - 1)
  bits = bits or (uint64((exp - flt.bias) and (1 shl flt.expbits - 1)) shl flt.mantbits)
  if d.neg:
    bits = bits or (1.uint shl flt.mantbits shl flt.expbits)

  result.b = bits
  return result


## Exact powers of 10.
var float64pow10: array[23,float64]
float64pow10 = [
  1e0, 1e1, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9,
  1e10, 1e11, 1e12, 1e13, 1e14, 1e15, 1e16, 1e17, 1e18, 1e19,
  1e20, 1e21, 1e22,
]

var float32pow10: array[11,float32]
float32pow10 = [1e0'f32, 1e1'f32, 1e2'f32, 1e3'f32, 1e4'f32,
                1e5'f32, 1e6'f32, 1e7'f32, 1e8'f32, 1e9'f32, 1e10'f32]


proc atof64exact(mantissa: uint64, exp: int, neg: bool): tuple[f: float64, ok: bool] =
  ## If possible to convert decimal representation to 64-bit float f exactly,
  ## entirely in floating-point math, do so, avoiding the expense of decimalToFloatBits.
  ## Three common cases:
  ##  value is exact integer
  ##  value is exact integer * exact power of ten
  ##  value is exact integer / exact power of ten
  ## These all produce potentially inexact but correctly rounded answers.
  var exp = exp

  if (mantissa shr float64info.mantbits) != 0:
    return

  var f = float64(mantissa)
  if neg:
    f = -f

  if exp == 0:
    # an integer.
    return (f, true)

  # Exact integers are <= 10^15.
  # Exact powers of ten are <= 10^22.
  elif exp > 0 and exp <= (15 + 22): # int * 10^k
    # If exponent is big but number of digits is not,
    # can move a few zeros into the integer part.
    if exp > 22:
      f *= float64pow10[exp - 22]
      exp = 22

    if f > 1e15 or f < -1e15:
      # the exponent was really too large.
      return

    return (f * float64pow10[exp], true)

  elif exp < 0 and exp >= -22: # int / 10^k
    return (f / float64pow10[-exp], true)

  return


proc atof32exact(mantissa: uint64, exp: int, neg: bool): tuple[f: float32, ok: bool] =
  ## If possible to compute mantissa*10^exp to 32-bit float f exactly,
  ## entirely in floating-point math, do so, avoiding the machinery above.

  if (mantissa shr float32info.mantbits) != 0:
    return

  var f = float32(mantissa)
  if neg:
    f = -f

  var exp = exp
  if exp == 0:
    return (f, true)

  # Exact integers are <= 10^7.
  # Exact powers of ten are <= 10^10.
  elif (exp > 0) and (exp <= 7+10): # int * 10^k
    # If exponent is big but number of digits is not,
    # can move a few zeros into the integer part.
    if exp > 10:
      f *= float32pow10[exp-10]
      exp = 10

    if f > 1e7 or f < -1e7:
      # the exponent was really too large.
      result.ok = false
      return

    return (f * float32pow10[exp], true)

  elif exp < 0 and exp >= -10: # int / 10^k
    return (f / float32pow10[-exp], true)

  return


proc atof32*(s: string): float32 =
  let (val, ok) = special(s)
  if ok:
    return float32(val)

  if optimize:
    # Parse mantissa and exponent.
    let (mantissa, exp, neg, trunc, ok) = readFloat(s)
    if ok:
      # Try pure floating-point arithmetic conversion.
      if not trunc:
        let (f, ok) = atof32exact(mantissa, exp, neg)
        if ok:
          return f

      # Try another fast path.
      var ext:extFloat = (uint64(0), 0, false)
      if ext.AssignDecimal(mantissa, exp, neg, trunc, float32info):
        # let (b, ovf) = ext.floatBits(float32info)
        let (b, _) = ext.floatBits(float32info)
        let f = float32frombits(uint32(b))
        # if ovf:
        #   raise newException(OverflowError, "can't parse " & s & " as float32")

        return f

  var d: decimal
  if not d.set(s):
    raise newException(ValueError, "can't parse " & s & " as float32. invalid number format")

  # let (b, ovf) = d.floatBits(float32info)
  let (b, _) = d.floatBits(float32info)

  let f = float32frombits(cast[uint32](b))
  # if ovf:
  #   raise newException(OverflowError, "can't parse " & s & " as float32")

  return f


proc atof64(s: string): float64 =
  let (val, ok) = special(s)
  if ok:
    return val

  if optimize:
    echo "optimize?"
    # Parse mantissa and exponent.
    let (mantissa, exp, neg, trunc, ok) = readFloat(s)
    if ok:
      # Try pure floating-point arithmetic conversion.
      if not trunc:
        let (f, ok) = atof64exact(mantissa, exp, neg)
        if ok:
          return f

      # Try another fast path.
      var ext:extFloat = (uint64(0), 0, false)
      if ext.AssignDecimal(mantissa, exp, neg, trunc, float64info):
        # let (b, ovf) = ext.floatBits(float64info)
        let (b, _) = ext.floatBits(float64info)
        let f = float64frombits(b)
        # if ovf:
        #   raise newException(OverflowError, "can't parse " & s & " as float64")

        return f

  var d: decimal
  if not d.set(s):
    raise newException(ValueError, "can't parse " & s & " as float64. invalid number format")

  # let (b, ovf) = d.floatBits(float64info)
  let (b, _) = d.floatBits(float64info)
  let f = float64frombits(b)
  # if ovf:
  #   raise newException(OverflowError, "can't parse " & s & " as float64")

  return f


proc ParseFloat*(s: string, bitSize: int): float =
  ## ParseFloat converts the string s to a floating-point number
  ## with the precision specified by bitSize: 32 for float32, or 64 for float64.
  ## When bitSize=32, the result still has type float64, but it will be
  ## convertible to float32 without changing its value.
  ##
  ## If s is well-formed and near a valid floating point number,
  ## ParseFloat returns the nearest floating point number rounded
  ## using IEEE754 unbiased rounding.
  ##
  ## The errors that ParseFloat returns have concrete type ptr NumError
  ## and include err.Num = s.
  ##
  ## If s is not syntactically well-formed, ParseFloat returns err.Err = ErrSyntax.
  ##
  ## If s is syntactically well-formed but is more than 1/2 ULP
  ## away from the largest floating point number of the given size,
  ## ParseFloat returns f = ±Inf, err.Err = ErrRange.

  when defined(js):
    let (val, ok) = special(s)
    if ok:
      return val

    var res: float64
    var cstr = cstring(s)
    {.emit: "`res` = parseFloat(`cstr`);".}
    return res
  else:
    if bitSize == 32:
      return atof32(s)

    return atof64(s)

when isMainModule:
  when not defined(js):
    import os
  import strutils
  import typetraits

  from ftoa import SetOptimize, FormatFloat
  from float2bits import float64bits
  import strformat

  when defined(js):
    discard SetOptimize(false)

  let cornercase = "2.2250738585072012e-308"

  when not defined(js):
    var x = parseFloat(paramStr(1))
    let digits = parseInt(paramStr(2))
  else:
    var args {.importc.}: seq[cstring]
    {.emit: "`args` = process.argv;" .}
    var x: float64
    var str = $args[2]
    echo str[0]
    if str[0] notin {'i', 'I', 'n', 'N'}:
      echo "notin"
      x = parseFloat(str)
    else:
      case str[0]
      of 'i', 'I':
        x = Inf
      of 'n', 'N':
        x = Nan
      else:
        echo "in"
        x = ParseFloat($str, 64)
    let digits = parseInt($args[3])
  echo "hier"
  let startp = -x
  let endp = x
  var i = startp
  while i <= endp:
    let a = strutils.parseFloat($i)
    # let a = i
    # echo fmt"{cast[uint64](parseFloat(cornercase)):064b}"
    # echo fmt"{cast[uint64](a):064b}"

    # let a32 = float32(a)
    # let ab = float32bits(a32)
    # echo "a bits: ", float32bits(a32)

    let b = atof.ParseFloat($i, 64)
    # let b = i
    # echo fmt"{cast[uint64](b):064b}"

    # echo "-".repeat(10), "|", "-".repeat(53)
    let astr = strutils.formatFloat(a, ffDecimal, digits)
    let bstr = ftoa.FormatFloat(b, 'f', digits, 64)
    echo("parseFloat(x): ", astr,
         " ParseFloat($x, 64): ", bstr, " ", a == b and astr == bstr)
    # echo formatFloat(b, 'g', -1, 64)
    # echo formatFloat(b, 'f', 1024, 64)
    # echo formatFloat(b, 'e', -1, 64)
    # echo formatFloat(atof.ParseFloat(cornercase, 64), 'g', -1, 64)
    # # var z = parseFloat(cornercase)
    # echo fmt"{cast[uint64](parseFloat(cornercase)):064b}"
    if a != b:
      echo a - b
    i += 0.1
