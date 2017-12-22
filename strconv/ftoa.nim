## Use of this source code is governed by a BSD-style
## license that can be found in the LICENSE file.
##
## Binary to decimal floating point conversion.
## Algorithm:
##   1) store mantissa in multiprecision decimal
##   2) shift decimal by exponent
##   3) read digits out & format


import math
import sequtils

import strconvTypes
import float2bits
import formatbits
import decimal
import extfloat


var optimize = false

const float32info = floatInfo(mantbits: 23, expbits: 8, bias: -127)
const float64info = floatInfo(mantbits: 52, expbits: 11, bias: -1023)

proc SetOptimize*(b: bool): bool =
  let old = optimize
  optimize = b
  return old


proc fmtE(dst: var string, neg: bool, d: decimalSlice, prec: int, fmt: char): string =
  ## %e: -d.ddddde±dd
  # sign
  if neg:
    add(dst, "-")
  

  # first digit
  var ch = "0"
  if d.nd != 0:
    ch = $d.d[0]
  add(dst, ch)

  # .moredigits
  if prec > 0:
    add(dst, ".")
    var i = 1
    var m = min(d.nd, prec + 1)
    if i < m:
      add(dst, cast[string](d.d[i..m-1]))
      i = m

    while i <= prec:
      add(dst, "0")
      inc(i)

  # e±
  add(dst, $fmt)
  var exp = d.dp - 1
  if d.nd == 0: # special case: 0 has exponent 0
    exp = 0

  if exp < 0:
    ch = "-"
    exp = -exp
  else:
    ch = "+"

  add(dst, $ch)

  # dd or ddd
  if exp < 10:
    add(dst, "0")
    add(dst, $exp)
  elif exp < 100:
    add(dst, $(exp div 10))
    add(dst, $(exp mod 10))
  else:
    add(dst, $(exp div 100))
    add(dst, $((exp div 10) mod 10))
    add(dst, $(exp mod 10))

  return dst


proc fmtF(dst: var string, neg: bool, d: decimalSlice, prec: int): string =
  ## %f: -ddddddd.ddddd
  # sign
  if neg:
    add(dst, "-")

  # integer, padded with zeros as needed.
  if d.dp > 0:
    var m = min(d.nd, d.dp)
    add(dst, cast[string](d.d[0..m-1]))
    while m < d.dp:
      add(dst, "0")
      inc(m)
  else:
    add(dst, "0")

  # fraction
  if prec > 0:
    add(dst, ".")
    for i in countUp(0, prec - 1):
      var ch = "0"
      let j = d.dp + i
      if j >= 0 and j < d.nd:
        ch = $d.d[j]
      add(dst, ch)

  return dst


proc formatDigits(dst: var string, shortest: bool, neg: bool, digs: decimalSlice, prec: int, fmt: char): string =
  case fmt 
  of 'e', 'E':
    return fmtE(dst, neg, digs, prec, fmt)
  of 'f':
    return fmtF(dst, neg, digs, prec)
  of 'g', 'G':
    # trailing fractional zeros in 'e' form will be trimmed.
    var eprec = prec
    if eprec > digs.nd and digs.nd >= digs.dp:
      eprec = digs.nd

    # %e is used if the exponent from the conversion
    # is less than -4 or greater than or equal to the precision.
    # if precision was the shortest possible, use precision 6 for this decision.
    if shortest:
      eprec = 6

    var exp = digs.dp - 1
    var prec = prec
    if exp < -4 or exp >= eprec:
      if prec > digs.nd:
        prec = digs.nd
      return fmtE(dst, neg, digs, prec-1, char(fmt.int + 'e'.int - 'g'.int))
    
    if prec > digs.dp:
      prec = digs.nd

    return fmtF(dst, neg, digs, max(prec-digs.dp, 0))

  else:
    # unknown format
    add(dst, "%")
    add(dst, $fmt)
    return dst

proc roundShortest(d: var decimal, mant: uint64, exp: int, flt: floatInfo) =
  ## roundShortest rounds d (= mant * 2^exp) to the shortest number of digits
  ## that will let the original floating point value be precisely reconstructed.

  # If mantissa is zero, the number is zero; stop now.
  if mant == 0:
    d.nd = 0
    return
  

  ## Compute upper and lower such that any decimal number
  ## between upper and lower (possibly inclusive)
  ## will round to the original floating point number.

  ## We may see at once that the number is already shortest.
  ##
  ## Suppose d is not denormal, so that 2^exp <= d < 10^dp.
  ## The closest shorter number is at least 10^(dp-nd) away.
  ## The lower/upper bounds computed below are at distance
  ## at most 2^(exp-mantbits).
  ##
  ## So the number is already shortest if 10^(dp-nd) > 2^(exp-mantbits),
  ## or equivalently log2(10)*(dp-nd) > exp-mantbits.
  ## It is true if 332/100*(dp-nd) >= exp-mantbits (log2(10) > 3.32).
  var minexp = flt.bias + 1 # minimum possible exponent
  if exp > minexp and (332 * (d.dp - d.nd) >= 100 * (exp - int(flt.mantbits))):
    # The number is already shortest.
    return
  

  ## d = mant << (exp - mantbits)
  ## Next highest floating point number is mant+1 << exp-mantbits.
  ## Our upper bound is halfway between, mant*2+1 << exp-mantbits-1.
  var upper: decimal
  upper.Assign(mant * 2 + 1)
  upper.Shift(exp - int(flt.mantbits) - 1)

  ## d = mant << (exp - mantbits)
  ## Next lowest floating point number is mant-1 << exp-mantbits,
  ## unless mant-1 drops the significant bit and exp is not the minimum exp,
  ## in which case the next lowest is mant*2-1 << exp-mantbits-1.
  ## Either way, call it mantlo << explo-mantbits.
  ## Our lower bound is halfway between, mantlo*2+1 << explo-mantbits-1.
  var mantlo: uint64
  var explo: int
  if mant > (1.uint64 shl flt.mantbits) or exp == minexp:
    mantlo = mant - 1
    explo = exp
  else:
    mantlo = mant * 2 - 1
    explo = exp - 1
  
  var lower: decimal
  lower.Assign(mantlo * 2 + 1)
  lower.Shift(explo - int(flt.mantbits) - 1)

  ## The upper and lower bounds are possible outputs only if
  ## the original mantissa is even, so that IEEE round-to-even
  ## would round to the original mantissa and not the neighbors.
  let inclusive = mant mod 2 == 0

  ## Now we can figure out the minimum number of digits required.
  ## Walk along until d has distinguished itself from upper and lower.
  for i in countUp(0, d.nd - 1):
  # for i := 0; i < d.nd; i++ {
    var lowd = '0' # lower digit
    if i < lower.nd:
      lowd = lower.d[i]
    var m = d.d[i]    # middle digit
    var u = '0' # upper digit
    if i < upper.nd:
      u = upper.d[i]

    ## Okay to round down (truncate) if lower has a different digit
    ## or if lower is inclusive and is exactly the result of rounding
    ## down (i.e., and we have reached the final digit of lower).
    let okdown = lowd != m or inclusive and i + 1 == lower.nd

    ## Okay to round up if upper has a different digit and either upper
    ## is inclusive or upper is bigger than the result of rounding up.
    let okup = m != u and (inclusive or m.int + 1 < u.int or i + 1 < upper.nd)

    ## If it's okay to do either, then round to the nearest one.
    ## If it's okay to do only one, do it.
    if okdown and okup:
      d.Round(i + 1)
      return
    elif okdown:
      d.RoundDown(i + 1)
      return
    elif okup:
      d.RoundUp(i + 1)
      return
    else:
      discard


proc bigFtoa(dst: var string, prec: int, fmt: char, neg: bool, mant: uint64, exp: int, flt: floatInfo): string =
  ## bigFtoa uses multiprecision computations to format a float.
  
  var d: decimal
  d.Assign(mant)
  d.Shift(exp - int(flt.mantbits))
  var digs: decimalSlice
  let shortest = prec < 0
  var prec = prec
  if shortest:
    roundShortest(d, mant, exp, flt)
    digs = decimalSlice(d: d.d, nd: d.nd, dp: d.dp)
    # Precision for shortest representation mode.
    case fmt
    of 'e', 'E':
      prec = digs.nd - 1
    of 'f':
      prec = max(digs.nd-digs.dp, 0)
    of 'g', 'G':
      prec = digs.nd
    else:
      discard
  else:
    # Round appropriately.
    case fmt 
    of 'e', 'E':
      d.Round(prec + 1)
    of 'f':
      d.Round(d.dp + prec)
    of 'g', 'G':
      if prec == 0:
        prec = 1
      
      d.Round(prec)
    else:
      discard
    digs = decimalSlice(d: d.d, nd: d.nd, dp: d.dp, neg: neg)
  return formatDigits(dst, shortest, neg, digs, prec, fmt)


proc fmtB(dst: var string, neg: bool, mant: uint64, exp: int, flt: floatInfo): string =
  ## %b: -ddddddddp±ddd

  # sign
  if neg:
    add(dst, "-")

  # mantissa
  var rslt = formatBits(dst, mant, 10, false, true)
  dst = rslt[0]

  # p
  add(dst, "p")

  # ±exponent
  var exp = exp
  exp = exp -  int(flt.mantbits)
  if exp >= 0:
    add(dst, "+")
  
  rslt = formatBits(dst, uint64(exp), 10, exp < 0, true)
  dst = rslt[0]

  return dst

proc fmtB_js*(f: float64): string =
  case classify(f)
  of fcNormal:
    var sign = "0"
    var f = f
    if f < 0.0:
      sign = "1"
      f = f * -1
    let lg2 = log2(f)
    var exp: int
    if lg2 < 0:
      if lg2 != int(lg2).float:
        exp = 52 - int(lg2) + 1
      else:
        exp = 52 - int(lg2)
      exp = exp * -1
    else:
      exp = int(lg2) - 52

    if exp + 1023 + 52 <= 0: # subnormal
      exp = -1074
    elif exp + 1023 + 52 > 1047: # (2^11 -1: maximal allowed exponent)
      exp = 971

    var mant = f / pow(2.0, exp.float64)
    let manti = int64(mant)
    let binfmt = (if $sign == "1": "-" else: "") & $manti & "p" & (if exp >= 0: "+" else: "") & $exp
    return binfmt
  of fcZero:
    return "0p-1074"
  of fcNegZero:
    return "-0p-1074"
  of fcInf:
    return "+Inf"
  of fcNegInf:
    return "-Inf"
  of fcNan:
    return "NaN"
  else:
    return ""

proc asIntegerRatio*(val: float64, bitSize: int = 64): (int64, int64) =
  var bits: uint64
  var flt: floatInfo

  case bitSize
  of 32:
    bits = uint64(float32bits(float32(val)))
    flt = float32info
  of 64:
    bits = float64bits(val)
    flt = float64info
  else:
    raise newException(ValueError, "strconv: illegal AppendFloat/FormatFloat bitSize")
  
  let neg = (bits shr (flt.expbits + flt.mantbits)) != 0
  var exp = int(bits shr flt.mantbits) and ((1 shl flt.expbits) - 1)
  var mant = bits and (uint64(1) shl flt.mantbits - 1)
  mant = mant or (uint64(1) shl flt.mantbits)

  exp += flt.bias
  exp = 1 shl abs(exp - int(flt.mantbits)) 

  let d = gcd(exp.int64, mant.int64)
  let num = mant.int64 div d
  let den = exp div d.int

  if neg:
    return (-num, den.int64)
  else:
    return (num, den.int64)


proc genericFtoa(dst: var string, val: float64, fmt: char, prec, bitSize: int): string =
  var bits: uint64
  var flt: floatInfo

  case bitSize
  of 32:
    bits = uint64(float32bits(float32(val)))
    flt = float32info
  of 64:
    bits = float64bits(val)
    flt = float64info
  else:
    raise newException(ValueError, "strconv: illegal AppendFloat/FormatFloat bitSize")
  
  # echo repr(bits)

  let neg = (bits shr (flt.expbits + flt.mantbits)) != 0
  var exp = int(bits shr flt.mantbits) and ((1 shl flt.expbits) - 1)
  var mant = bits and (uint64(1) shl flt.mantbits - 1)

  # echo "neg: ", neg
  # echo "exp: ", exp
  # echo "mant: ", int(mant)
  # echo "expbits: ", flt.expbits.int
  # echo 1 shl flt.expbits - 1

  if exp == 1 shl flt.expbits - 1:
    # Inf, NaN
    var s: string
    if mant != 0:
      s = "NaN"
    elif neg:
      s = "-Inf"
    else:
      s = "+Inf"

    add(dst, s)
    return dst

  elif exp == 0:
    # denormalized
    inc(exp)

  else:
    # add implicit top bit
    mant = mant or (uint64(1) shl flt.mantbits)
  
  exp += flt.bias

  # Pick off easy binary format.
  if fmt == 'b':
    return fmtB(dst, neg, mant, exp, flt)
  
  if not optimize:
    return bigFtoa(dst, prec, fmt, neg, mant, exp, flt)
  
  var digs: decimalSlice
  var ok = false
  var prec = prec  
  # Negative precision means "only as much as needed to be exact."
  let shortest = prec < 0
  var f:strconvTypes.extFloat
  f = (mant, exp, neg)

  if shortest:
    # Try Grisu3 algorithm.
    var rslt = assignComputeBounds(f=f, mant=mant, exp=exp, neg=neg, flt=flt)
    var lower = rslt[0]
    var upper = rslt[1]
    ok = f.ShortestDecimal(digs, lower, upper)
    if not ok:
      return bigFtoa(dst, prec, fmt, neg, mant, exp, flt)
    
    # Precision for shortest representation mode.
    case fmt
    of 'e', 'E':
      prec = max(digs.nd - 1, 0)
    of 'f':
      prec = max(digs.nd - digs.dp, 0)
    of 'g', 'G':
      prec = digs.nd
    else:
      discard
  elif fmt != 'f':
    # Fixed number of digits.
    var digits = prec
    case fmt 
    of 'e', 'E':
      inc(digits)
    of 'g', 'G':
      if prec == 0:
        prec = 1
      digits = prec
    else:
      discard
    
    if digits <= 15:
      # try fast algorithm when the number of digits is reasonable.
      #var buf = newSeq[char](24)
      #digs.d = buf
      f = (mant: mant, exp: exp - int(flt.mantbits), neg: neg)
      ok = f.FixedDecimal(digs, digits)
  
  if not ok:
    return bigFtoa(dst, prec, fmt, neg, mant, exp, flt)
  
  return formatDigits(dst, shortest, neg, digs, prec, fmt)


proc AppendFloat*(dst: var string, f: float64, fmt: char, prec, bitSize: int): string =
  ## AppendFloat appends the string form of the floating-point number f,
  ## as generated by FormatFloat, to dst and returns the extended buffer.

  return genericFtoa(dst, f, fmt, prec, bitSize)


proc FormatFloat*(f: float64, fmt: char, prec, bitSize: int): string =
  ## FormatFloat converts the floating-point number f to a string,
  ## according to the format fmt and precision prec. It rounds the
  ## result assuming that the original was obtained from a floating-point
  ## value of bitSize bits (32 for float32, 64 for float64).
  ##
  ## The format fmt is one of
  ## 'b' (-ddddp±ddd, a binary exponent),
  ## 'e' (-d.dddde±dd, a decimal exponent),
  ## 'E' (-d.ddddE±dd, a decimal exponent),
  ## 'f' (-ddd.dddd, no exponent),
  ## 'g' ('e' for large exponents, 'f' otherwise), or
  ## 'G' ('E' for large exponents, 'f' otherwise).
  ##
  ## The precision prec controls the number of digits
  ## (excluding the exponent) printed by the 'e', 'E', 'f', 'g', and 'G' formats.
  ## For 'e', 'E', and 'f' it is the number of digits after the decimal point.
  ## For 'g' and 'G' it is the total number of digits.
  ## The special precision -1 uses the smallest number of digits
  ## necessary such that ParseFloat will return f exactly.
  when defined(js):
    var res: cstring
    var prec = prec
    if prec > 20:
      prec = 20
    case fmt
    of 'b':
      return fmtB_js(f)
    of 'g', 'G':
      if prec < 0:
        prec = 6
      {.emit: "`res` = `f`.toString();".}
    of 'f', 'F':
      if prec < 0:
        prec = 6
      {.emit: "`res` = `f`.toFixed(`prec`);".}
    of 'e', 'E':
      if prec < 0:
        prec = 16
      {.emit: "`res` = `f`.toExponential(`prec`);".}
    else:
      {.emit: "`res` = `f`.toString();".}
    result = $res
  else:
    var dst = ""
    return genericFtoa(dst, f, fmt, prec, bitSize)


when isMainModule:
  let f: float32 = 1587.5678
  let f1: float32 = 2.185
  echo FormatFloat(f.float64, 'b', 10, 32)
  echo FormatFloat(f, 'f', 14, 32)
  echo FormatFloat(f1, 'g', 10, 32)
  echo FormatFloat(f, 'g', 120, 32)
