## Copyright 2011 The Go Authors. All rights reserved.
## Use of this source code is governed by a BSD-style
## license that can be found in the LICENSE file.
import strfmt
import strconvTypes

## Powers of ten taken from double-conversion library.
## http://code.google.com/p/double-conversion/
const
  firstPowerOfTen = -348
  stepPowerOfTen  = 8


var smallPowersOfTen: seq[strconvTypes.extFloat]
smallPowersOfTen = @[
  (uint64(1 shl 63), -63, false),        # 1
  (uint64(0xa shl 60), -60, false),      # 1e1
  (uint64(0x64 shl 57), -57, false),     # 1e2
  (uint64(0x3e8 shl 54), -54, false),    # 1e3
  (uint64(0x2710 shl 50), -50, false),   # 1e4
  (uint64(0x186a0 shl 47), -47, false),  # 1e5
  (uint64(0xf4240 shl 44), -44, false),  # 1e6
  (uint64(0x989680 shl 40), -40, false), # 1e7
]

var powersOfTen: seq[strconvTypes.extFloat]
powersOfTen = @[
  (uint64(0xfa8fd5a0081c0288), -1220, false), # 10^-348
  (uint64(0xbaaee17fa23ebf76), -1193, false), # 10^-340
  (uint64(0x8b16fb203055ac76), -1166, false), # 10^-332
  (uint64(0xcf42894a5dce35ea), -1140, false), # 10^-324
  (uint64(0x9a6bb0aa55653b2d), -1113, false), # 10^-316
  (uint64(0xe61acf033d1a45df), -1087, false), # 10^-308
  (uint64(0xab70fe17c79ac6ca), -1060, false), # 10^-300
  (uint64(0xff77b1fcbebcdc4f), -1034, false), # 10^-292
  (uint64(0xbe5691ef416bd60c), -1007, false), # 10^-284
  (uint64(0x8dd01fad907ffc3c), -980, false),  # 10^-276
  (uint64(0xd3515c2831559a83), -954, false),  # 10^-268
  (uint64(0x9d71ac8fada6c9b5), -927, false),  # 10^-260
  (uint64(0xea9c227723ee8bcb), -901, false),  # 10^-252
  (uint64(0xaecc49914078536d), -874, false),  # 10^-244
  (uint64(0x823c12795db6ce57), -847, false),  # 10^-236
  (uint64(0xc21094364dfb5637), -821, false),  # 10^-228
  (uint64(0x9096ea6f3848984f), -794, false),  # 10^-220
  (uint64(0xd77485cb25823ac7), -768, false),  # 10^-212
  (uint64(0xa086cfcd97bf97f4), -741, false),  # 10^-204
  (uint64(0xef340a98172aace5), -715, false),  # 10^-196
  (uint64(0xb23867fb2a35b28e), -688, false),  # 10^-188
  (uint64(0x84c8d4dfd2c63f3b), -661, false),  # 10^-180
  (uint64(0xc5dd44271ad3cdba), -635, false),  # 10^-172
  (uint64(0x936b9fcebb25c996), -608, false),  # 10^-164
  (uint64(0xdbac6c247d62a584), -582, false),  # 10^-156
  (uint64(0xa3ab66580d5fdaf6), -555, false),  # 10^-148
  (uint64(0xf3e2f893dec3f126), -529, false),  # 10^-140
  (uint64(0xb5b5ada8aaff80b8), -502, false),  # 10^-132
  (uint64(0x87625f056c7c4a8b), -475, false),  # 10^-124
  (uint64(0xc9bcff6034c13053), -449, false),  # 10^-116
  (uint64(0x964e858c91ba2655), -422, false),  # 10^-108
  (uint64(0xdff9772470297ebd), -396, false),  # 10^-100
  (uint64(0xa6dfbd9fb8e5b88f), -369, false),  # 10^-92
  (uint64(0xf8a95fcf88747d94), -343, false),  # 10^-84
  (uint64(0xb94470938fa89bcf), -316, false),  # 10^-76
  (uint64(0x8a08f0f8bf0f156b), -289, false),  # 10^-68
  (uint64(0xcdb02555653131b6), -263, false),  # 10^-60
  (uint64(0x993fe2c6d07b7fac), -236, false),  # 10^-52
  (uint64(0xe45c10c42a2b3b06), -210, false),  # 10^-44
  (uint64(0xaa242499697392d3), -183, false),  # 10^-36
  (uint64(0xfd87b5f28300ca0e), -157, false),  # 10^-28
  (uint64(0xbce5086492111aeb), -130, false),  # 10^-20
  (uint64(0x8cbccc096f5088cc), -103, false),  # 10^-12
  (uint64(0xd1b71758e219652c), -77, false),   # 10^-4
  (uint64(0x9c40000000000000), -50, false),   # 10^4
  (uint64(0xe8d4a51000000000), -24, false),   # 10^12
  (uint64(0xad78ebc5ac620000), 3, false),     # 10^20
  (uint64(0x813f3978f8940984), 30, false),    # 10^28
  (uint64(0xc097ce7bc90715b3), 56, false),    # 10^36
  (uint64(0x8f7e32ce7bea5c70), 83, false),    # 10^44
  (uint64(0xd5d238a4abe98068), 109, false),   # 10^52
  (uint64(0x9f4f2726179a2245), 136, false),   # 10^60
  (uint64(0xed63a231d4c4fb27), 162, false),   # 10^68
  (uint64(0xb0de65388cc8ada8), 189, false),   # 10^76
  (uint64(0x83c7088e1aab65db), 216, false),   # 10^84
  (uint64(0xc45d1df942711d9a), 242, false),   # 10^92
  (uint64(0x924d692ca61be758), 269, false),   # 10^100
  (uint64(0xda01ee641a708dea), 295, false),   # 10^108
  (uint64(0xa26da3999aef774a), 322, false),   # 10^116
  (uint64(0xf209787bb47d6b85), 348, false),   # 10^124
  (uint64(0xb454e4a179dd1877), 375, false),   # 10^132
  (uint64(0x865b86925b9bc5c2), 402, false),   # 10^140
  (uint64(0xc83553c5c8965d3d), 428, false),   # 10^148
  (uint64(0x952ab45cfa97a0b3), 455, false),   # 10^156
  (uint64(0xde469fbd99a05fe3), 481, false),   # 10^164
  (uint64(0xa59bc234db398c25), 508, false),   # 10^172
  (uint64(0xf6c69a72a3989f5c), 534, false),   # 10^180
  (uint64(0xb7dcbf5354e9bece), 561, false),   # 10^188
  (uint64(0x88fcf317f22241e2), 588, false),   # 10^196
  (uint64(0xcc20ce9bd35c78a5), 614, false),   # 10^204
  (uint64(0x98165af37b2153df), 641, false),   # 10^212
  (uint64(0xe2a0b5dc971f303a), 667, false),   # 10^220
  (uint64(0xa8d9d1535ce3b396), 694, false),   # 10^228
  (uint64(0xfb9b7cd9a4a7443c), 720, false),   # 10^236
  (uint64(0xbb764c4ca7a44410), 747, false),   # 10^244
  (uint64(0x8bab8eefb6409c1a), 774, false),   # 10^252
  (uint64(0xd01fef10a657842c), 800, false),   # 10^260
  (uint64(0x9b10a4e5e9913129), 827, false),   # 10^268
  (uint64(0xe7109bfba19c0c9d), 853, false),   # 10^276
  (uint64(0xac2820d9623bf429), 880, false),   # 10^284
  (uint64(0x80444b5e7aa7cf85), 907, false),   # 10^292
  (uint64(0xbf21e44003acdd2d), 933, false),   # 10^300
  (uint64(0x8e679c2f5e44ff8f), 960, false),   # 10^308
  (uint64(0xd433179d9c8cb841), 986, false),   # 10^316
  (uint64(0x9e19db92b4e31ba9), 1013, false),  # 10^324
  (uint64(0xeb96bf6ebadf77d9), 1039, false),  # 10^332
  (uint64(0xaf87023b9bf0ee6b), 1066, false),  # 10^340
]


proc Normalize*(f: var strconvTypes.extFloat): uint64 =
  ## Normalize normalizes f so that the highest bit of the mantissa is
  ## set, and returns the number by which the mantissa was left-shifted.

  var mant = f.mant 
  var exp = f.exp

  if mant == 0:
    return 0

  if mant shr (64 - 32) == 0:
    mant = mant shl 32
    exp -= 32
  
  if mant shr (64 - 16) == 0:
    mant = mant shl 16
    exp -= 16
  
  if mant shr (64 - 8) == 0:
    mant = mant shl 8
    exp -= 8
  
  if mant shr (64 - 4) == 0:
    mant = mant shl 4
    exp -= 4
  
  if mant shr (64 - 2) == 0:
    mant = mant shl 2
    exp -= 2
  
  if mant shr (64 - 1) == 0:
    mant = mant shl 1
    exp -= 1
  
  let shift = uint(f.exp - exp)
  (f.mant, f.exp) = (mant, exp)
  return shift


proc floatBits*(f: var strconvTypes.extFloat, flt: floatInfo): tuple[bits: uint64, overflow: bool] =
  ## floatBits returns the bits of the float64 that best approximates
  ## the extFloat passed as receiver. Overflow is set to true if
  ## the resulting float64 is ±Inf.

  discard f.Normalize()

  var exp = f.exp + 63

  # Exponent too small.
  if exp < flt.bias + 1:
    let n = flt.bias + 1 - exp
    f.mant = f.mant shr uint(n)
    exp += n

  # Extract 1+flt.mantbits bits from the 64-bit mantissa.
  var mant = f.mant shr (63.uint64 - flt.mantbits)
  if (f.mant and (1.uint64 shl (62.uint64 - flt.mantbits))) != 0:
    # Round up.
    mant += 1

  # Rounding might have added a bit; shift down.
  if mant == 2.uint64 shl flt.mantbits:
    mant = mant shr 1
    inc(exp)

  # Infinities.
  if exp - flt.bias >= 1 shl flt.expbits - 1:
    # ±Inf
    mant = 0
    exp = 1 shl flt.expbits - 1 + flt.bias
    result.overflow = true
  elif (mant and (1.uint64 shl flt.mantbits)) == 0:
    # Denormalized?
    exp = flt.bias

  # Assemble bits.
  var bits = mant and (uint64(1) shl flt.mantbits - 1)
  bits = bits or uint64((exp - flt.bias) and (1 shl flt.expbits - 1)) shl flt.mantbits
  if f.neg:
    bits = bits or 1.uint64 shl (flt.mantbits + flt.expbits)
  result.bits = bits    
  return


proc assignComputeBounds*(f: var strconvTypes.extFloat, mant: uint64, exp: int, 
                         neg: bool, flt: floatInfo): (strconvTypes.extFloat, strconvTypes.extFloat) =
  ## AssignComputeBounds sets f to the floating point value
  ## defined by mant, exp and precision given by flt. It returns
  ## lower, upper such that any number in the closed interval
  ## [lower, upper] is converted back to the same floating point number.
  f.mant = mant
  f.exp = exp - int(flt.mantbits)
  f.neg = neg

  # Nim uses circular shifts, so this test can't be literally translated.
  # The Go version tests if one of the last -f.exp bits in the mantissa are
  # different from zero. They would be shifted out by the Go right shift,
  # and the following left shift by -f.exp bits would give a different
  # mantissa. 
  #if (f.exp <= 0) and (mant == ((mant shr cast[uint](-f.exp)) shl cast[uint](-f.exp))):
  if (f.exp <= 0) and (uint(-f.exp) < flt.mantbits) and ((mant and (1.uint shl -f.exp - 1)) == 0):
    when defined(debug):
      echo "f.exp:  ", f.exp
      echo "f.mant: ", f.mant
      echo f.mant.format("064b")
      echo((1.uint shl -f.exp - 1).format("064b"))
      echo "shifted out bits of mantissa are zero: ", (mant and (1.uint shl - f.exp - 1)) == 0

    # An exact integer
    f.mant = f.mant shr uint(-f.exp)
    f.exp = 0
    return (f, f)

  var expBiased = exp - flt.bias

  let upper = (mant: 2.uint64 * f.mant + 1, exp: f.exp - 1, neg: f.neg)
  var lower: strconvTypes.extFloat
  if (mant != (1.uint64 shl flt.mantbits)) or (expBiased == 1):
    lower = (mant: 2.uint64 * f.mant - 1, exp: f.exp - 1, neg: f.neg)
  else:
    lower = (mant: 4.uint64 * f.mant - 1, exp: f.exp - 2, neg: f.neg)
  return (lower, upper)



proc Multiply*(f: var strconvTypes.extFloat, g: strconvTypes.extFloat) =
  ## Multiply sets f to the product f*g: the result is correctly rounded,
  ## but not normalized.

  var (fhi, flo) = (f.mant shr 32, uint64(uint32(f.mant)))
  var (ghi, glo) = (g.mant shr 32, uint64(uint32(g.mant)))

  # Cross products.
  var cross1 = fhi * glo
  var cross2 = flo * ghi

  # f.mant*g.mant is fhi*ghi << 64 + (cross1+cross2) << 32 + flo*glo
  f.mant = fhi * ghi + (cross1 shr 32) + (cross2 shr 32)
  var rem = uint64(uint32(cross1)) + uint64(uint32(cross2)) + ((flo * glo) shr 32)
  
  # Round up.
  rem += (1 shl 31)

  f.mant += (rem shr 32)
  f.exp = f.exp + g.exp + 64


var uint64pow10: seq[uint64] = @[
  uint64(1), uint64(1e1), uint64(1e2), uint64(1e3), uint64(1e4), uint64(1e5), uint64(1e6), 
  uint64(1e7), uint64(1e8), uint64(1e9), uint64(1e10), uint64(1e11), uint64(1e12), 
  uint64(1e13), uint64(1e14), uint64(1e15), uint64(1e16), uint64(1e17), uint64(1e18), uint64(1e19)
]

## AssignDecimal sets f to an approximate value mantissa*10^exp. It
## reports whether the value represented by f is guaranteed to be the
## best approximation of d after being rounded to a float64 or
## float32 depending on flt.
proc AssignDecimal*(f: var strconvTypes.extFloat, mantissa: uint64, exp10: int, 
                   neg: bool, trunc: bool, flt: floatInfo): bool =
  const uint64digits = 19
  const errorscale = 8
  var errors = 0 # An upper bound for error, computed in errorscale*ulp.
  if trunc:
    ## the decimal number was truncated.
    errors += (errorscale div 2)
  
  f.mant = mantissa
  f.exp = 0
  f.neg = neg

  # Multiply by powers of ten.
  var i = (exp10 - firstPowerOfTen) div stepPowerOfTen
  if exp10 < firstPowerOfTen or i >= len(powersOfTen):
    return false
  
  var adjExp = (exp10 - firstPowerOfTen) mod stepPowerOfTen

  ## We multiply by exp % step
  if adjExp < uint64digits and mantissa < uint64pow10[uint64digits-adjExp]:
    # We can multiply the mantissa exactly.
    f.mant *= uint64pow10[adjExp]
    discard f.Normalize()
  else:
    discard f.Normalize()
    f.Multiply(smallPowersOfTen[adjExp])
    errors += (errorscale div 2)
  

  # We multiply by 10 to the exp - exp % step.
  f.Multiply(powersOfTen[i])
  if errors > 0:
    errors += 1
  
  errors += (errorscale div 2)

  # Normalize
  var shift = f.Normalize()
  errors = errors shl shift

  # Now f is a good approximation of the decimal.
  # Check whether the error is too large: that is, if the mantissa
  # is perturbated by the error, the resulting float64 will change.
  # The 64 bits mantissa is 1 + 52 bits for float64 + 11 extra bits.
  #
  # In many cases the approximation will be good enough.
  let denormalExp = flt.bias - 63
  var extrabits: uint64
  if f.exp <= denormalExp:
    # f.mant * 2^f.exp is smaller than 2^(flt.bias+1).
    extrabits = 63.uint64 - flt.mantbits + 1 + uint(denormalExp-f.exp)
  else:
    extrabits = 63.uint64 - flt.mantbits
  
  var halfway = uint64(1) shl (extrabits - 1)
  var mant_extra = (f.mant and (1.uint64 shl extrabits - 1))

  # Do a signed comparison here! If the error estimate could make
  # the mantissa round differently for the conversion to double,
  # then we can't give a definite answer.
  if int64(halfway) - int64(errors) < int64(mant_extra) and
     int64(mant_extra) < int64(halfway) + int64(errors):
    return false

  return true


proc frexp10*(f: var strconvTypes.extFloat): (int, int) =
  ## Frexp10 is an analogue of math.Frexp for decimal powers. It scales
  ## f by an approximate power of ten 10^-exp, and returns exp10, so
  ## that f*10^exp10 has the same value as the old f, up to an ulp,
  ## as well as the index of 10^-exp in the powersOfTen table.
  ##
  ## The constants expMin and expMax constrain the final value of the
  ## binary exponent of f. We want a small integral part in the result
  ## because finding digits of an integer requires divisions, whereas
  ## digits of the fractional part can be found by repeatedly multiplying
  ## by 10.
  
  const expMin = -60
  const expMax = -32
  # Find power of ten such that x * 10^n has a binary exponent
  # between expMin and expMax.
  var approxExp10 = ((expMin + expMax) div 2 - f.exp) * 28 div 93 # log(10)/log(2) is close to 93/28.
  var i = (approxExp10 - firstPowerOfTen) div stepPowerOfTen
  block Loop:
    while true:
      let exp = f.exp + powersOfTen[i].exp + 64
      if exp < expMin:
        inc(i)
      elif exp > expMax:
        dec(i)
      else:
        break Loop

  ## Apply the desired decimal shift on f. It will have exponent
  ## in the desired range. This is multiplication by 10^-exp10.
  f.Multiply(powersOfTen[i])

  return (-(firstPowerOfTen + i*stepPowerOfTen), i)


proc frexp10Many(a, b, c: var strconvTypes.extFloat): int =
  ## frexp10Many applies a common shift by a power of ten to a, b, c.
  let (exp10, i) = c.frexp10()
  a.Multiply(powersOfTen[i])
  b.Multiply(powersOfTen[i])
  return exp10


proc adjustLastDigitFixed*(d: var decimalSlice, num, den: uint64, shift: uint, ε: uint64): bool =
  ## adjustLastDigitFixed assumes d contains the representation of the integral part
  ## of some number, whose fractional part is num / (den << shift). The numerator
  ## num is only known up to an uncertainty of size ε, assumed to be less than
  ## (den << shift)/2.
  ##
  ## It will increase the last digit by one to account for correct rounding, typically
  ## when the fractional part is greater than 1/2, and will return false if ε is such
  ## that no correct answer can be given.
  
  if num > den shl shift:
    raise newException(ValueError, "strconv: num > den << shift in adjustLastDigitFixed")
  
  if 2.uint64 * ε > den shl shift:
    raise newException(ValueError, "strconv: ε > (den<<shift)/2")
  
  if 2.uint64 * (num + ε) < den shl shift:
    return true
  
  if 2.uint64 * (num - ε) > den shl shift:
    # increment d by 1.
    var i = d.nd - 1
    while i >= 0:
    # for ; i >= 0; i-- {
      if d.d[i] == '9':
        dec(d.nd)
      else:
        break
      dec(i)

    if i < 0:
      d.d[0] = '1'
      d.nd = 1
      d.dp.inc()
    else:
      d.d[i].inc()
    
    return true
  
  return false


proc adjustLastDigit*(d: var decimalSlice, currentDiff: uint64, 
                     targetDiff, maxDiff, ulpDecimal, ulpBinary: uint64): bool =
  ## adjustLastDigit modifies d = x-currentDiff*ε, to get closest to
  ## d = x-targetDiff*ε, without becoming smaller than x-maxDiff*ε.
  ## It assumes that a decimal digit is worth ulpDecimal*ε, and that
  ## all data is known with a error estimate of ulpBinary*ε.
  var currentDiff = currentDiff

  if ulpDecimal < 2.uint64 * ulpBinary:
    # Approximation is too wide.
    return false
  
  while (currentDiff + ulpDecimal div 2.uint64 + ulpBinary) < targetDiff:
    d.d[d.nd - 1].dec()
    currentDiff += ulpDecimal
  
  if (currentDiff + ulpDecimal) <= (targetDiff + ulpDecimal div 2.uint64 + ulpBinary):
    # we have two choices, and don't know what to do.
    return false
  
  if (currentDiff < ulpBinary) or (currentDiff > maxDiff - ulpBinary):
    # we went too far
    return false
  
  if d.nd == 1 and d.d[0] == '0':
    # the number has actually reached zero.
    d.nd = 0
    d.dp = 0
  
  return true


proc FixedDecimal*(f: var strconvTypes.extFloat, d: var decimalSlice, n: int): bool =
  ## FixedDecimal stores in d the first n significant digits
  ## of the decimal representation of f. It returns false
  ## if it cannot be sure of the answer.

  if f.mant == 0:
    d.nd = 0
    d.dp = 0
    d.neg = f.neg
    return true
  
  if n == 0:
    raise newException(ValueError, "strconv: internal error: extFloat.FixedDecimal called with n == 0")
  
  # Multiply by an appropriate power of ten to have a reasonable
  # number to process.
  discard f.Normalize()
  let (exp10, _) = f.frexp10()

  let shift = uint(-f.exp)
  var integer = uint32(f.mant shr shift)
  var fraction = f.mant - (uint64(integer) shl shift)
  var ε = uint64(1) # ε is the uncertainty we have on the mantissa of f.

  # Write exactly n digits to d.
  var needed = n        # how many digits are left to write.
  var integerDigits = 0 # the number of decimal digits of integer.
  var pow10 = uint64(1) # the power of ten by which f was scaled.
  var pow = uint64(1)
  for i in countUp(0, 19):
  # for i, pow := 0, uint64(1); i < 20; i++ {
    if pow > uint64(integer):
      integerDigits = i
      break
    pow *= 10
  
  var rest = integer
  if integerDigits > needed:
    # the integral part is already large, trim the last digits.
    pow10 = uint64pow10[integerDigits - needed]
    integer = integer div uint32(pow10)
    rest -= (integer * uint32(pow10))
  else:
    rest = 0
  
  # Write the digits of integer: the digits of rest are omitted.
  var buf = newSeq[char](32)
  var pos = len(buf)
  var v = integer
  while v > 0.uint32:
  # for v := integer; v > 0; {
    let v1 = v div 10
    v -= (10.uint32 * v1)
    dec(pos)
    buf[pos] = char(v.int8 + '0'.int8)
    v = v1
  
  for i in countUp(pos, len(buf) - 1):
  # for i := pos; i < len(buf); i++ {
    d.d[i - pos] = buf[i]
  
  var nd = len(buf) - pos
  d.nd = nd
  d.dp = integerDigits + exp10
  needed -= nd

  if needed > 0:
    if rest != 0 or pow10 != 1:
      raise newException(ValueError, "strconv: internal error, rest != 0 but needed > 0")
    
    # Emit digits for the fractional part. Each time, 10*fraction
    # fits in a uint64 without overflow.
    while needed > 0:
      fraction *= 10.uint64
      ε *= 10 # the uncertainty scales as we multiply by ten.
      if (2.uint64 * ε) > (1.uint64 shl shift):
        # the error is so large it could modify which digit to write, abort.
        return false
      
      let digit = fraction shr shift
      d.d[nd] = char(digit.int8 + '0'.int8)
      fraction -= (digit shl shift)
      inc(nd)
      dec(needed)
    d.nd = nd

  # We have written a truncation of f (a numerator / 10^d.dp). The remaining part
  # can be interpreted as a small number (< 1) to be added to the last digit of the
  # numerator.
  #
  # If rest > 0, the amount is:
  #    (rest<<shift | fraction) / (pow10 << shift)
  #    fraction being known with a ±ε uncertainty.
  #    The fact that n > 0 guarantees that pow10 << shift does not overflow a uint64.
  #
  # If rest = 0, pow10 == 1 and the amount is
  #    fraction / (1 << shift)
  #    fraction being known with a ±ε uncertainty.
  #
  # We pass this information to the rounding routine for adjustment.

  let ok = adjustLastDigitFixed(d, (uint64(rest) shl shift) or fraction, pow10, shift, ε)
  if not ok:
    return false
  
  # Trim trailing zeros.
  for i in countDown(d.nd - 1, 0):
  # for i := d.nd - 1; i >= 0; i-- {
    if d.d[i] != '0':
      d.nd = i + 1
      break
    
  return true


proc ShortestDecimal*(f: var strconvTypes.extFloat, d: var decimalSlice, lower, upper: var strconvTypes.extFloat): bool =
  ## ShortestDecimal stores in d the shortest decimal representation of f
  ## which belongs to the open interval (lower, upper), where f is supposed
  ## to lie. It returns false whenever the result is unsure. The implementation
  ## uses the Grisu3 algorithm.

  if f.mant == 0:
    d.nd = 0
    d.dp = 0
    d.neg = f.neg
    return true
  
  if f.exp == 0 and lower == f and lower == upper:
    # an exact integer.
    var buf = newSeq[char](24)
    var n = len(buf) - 1
    var v = f.mant
    while v > 0.uint64:
    # for v := f.mant; v > 0; {
      let v1 = v div 10
      v -= (10.uint64 * v1)
      buf[n] = char(v.int8 + '0'.int8)
      n.dec()
      v = v1
    
    let nd = len(buf) - n - 1
    for i in countUp(0, nd - 1):
    # for i := 0; i < nd; i++ {
      d.d[i] = buf[n+1+i]
    
    (d.nd, d.dp) = (nd, nd)
    while d.nd > 0 and d.d[d.nd - 1] == '0':
      d.nd.dec()
    
    if d.nd == 0:
      d.dp = 0
    
    d.neg = f.neg
    return true

  discard upper.Normalize()
  # Uniformize exponents.
  if f.exp > upper.exp:
    f.mant = f.mant shl uint(f.exp - upper.exp)
    f.exp = upper.exp
  
  if lower.exp > upper.exp:
    lower.mant = lower.mant shl uint(lower.exp - upper.exp)
    lower.exp = upper.exp
  

  let exp10 = frexp10Many(lower, f, upper)
  # Take a safety margin due to rounding in frexp10Many, but we lose precision.
  upper.mant.inc()
  lower.mant.dec()

  # The shortest representation of f is either rounded up or down, but
  # in any case, it is a truncation of upper.
  let shift = uint(-upper.exp)
  var integer = uint32(upper.mant shr shift)
  var fraction = upper.mant - (uint64(integer) shl shift)

  # How far we can go down from upper until the result is wrong.
  let allowance = upper.mant - lower.mant
  # How far we should go to get a very precise result.
  let targetDiff = upper.mant - f.mant

  # Count integral digits: there are at most 10.
  var integerDigits: int
  var pow = uint64(1)
  for i in countUp(0, 19):
  # for i, pow := 0, uint64(1); i < 20; i++ {
    if pow > uint64(integer):
      integerDigits = i
      break
    
    pow *= 10
  
  for i in countUp(0, integerDigits - 1):
  # for i := 0; i < integerDigits; i++ {
    pow = uint64pow10[integerDigits - i - 1]
    let digit = integer div uint32(pow)
    d.d[i] = char(digit.int8 + '0'.int8)
    integer -= (digit * uint32(pow))
    # evaluate whether we should stop.
    var currentDiff = uint64(integer) shl shift + fraction
    if currentDiff < allowance:
      d.nd = i + 1
      d.dp = integerDigits + exp10
      d.neg = f.neg
      ## Sometimes allowance is so large the last digit might need to be
      ## decremented to get closer to f.
      return adjustLastDigit(d, currentDiff, targetDiff, allowance, pow shl shift, 2)
    
  d.nd = integerDigits
  d.dp = d.nd + exp10
  d.neg = f.neg

  # Compute digits of the fractional part. At each step fraction does not
  # overflow. The choice of minExp implies that fraction is less than 2^60.
  var digit: int
  var multiplier = uint64(1)
  while true:
    fraction *= 10.uint64
    multiplier *= 10.uint64
    digit = int(fraction shr shift)
    d.d[d.nd] = char(digit + '0'.int8)
    d.nd.inc()
    fraction -= (uint64(digit) shl shift)
    if fraction < allowance * multiplier:
      # We are in the admissible range. Note that if allowance is about to
      # overflow, that is, allowance > 2^64/10, the condition is automatically
      # true due to the limited range of fraction.
      return adjustLastDigit(d,
        fraction, targetDiff * multiplier, allowance * multiplier,
        1.uint64 shl shift, multiplier * 2)
    
  
