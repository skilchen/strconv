import tables

const 
  digits = "0123456789abcdefghijklmnopqrstuvwxyz"


var shifts = {
  1 shl 1: 1,
  1 shl 2: 2,
  1 shl 3: 3,
  1 shl 4: 4,
  1 shl 5: 5,
}.toTable()

proc formatBits*(dst: var string, u: uint64, base: int, neg, append: bool): tuple[d: string, s: string] =
  ## formatBits computes the string representation of u in the given base.
  ## If neg is set, u is treated as negative int64 value. If append_ is
  ## set, the string is appended to dst and the resulting byte slice is
  ## returned as the first result value; otherwise the string is returned
  ## as the second result value.
  ##
  var u = u

  if base < 2 or base > len(digits):
    raise newException(ValueError, "strconv: illegal AppendInt/FormatInt base")
  
  # 2 <= base && base <= len(digits)

  var a: array[0..64, char] # +1 for sign of 64bit value in base 2
  var i = len(a)

  if neg:
    let temp = u.int64 * -1
    u = uint64(temp)

  # convert bits
  if base == 10:
    # common case: use constants for / because
    # the compiler can optimize it into a multiply+shift
    var n:uint = 0
    var null: ptr uint = addr(n)
    if (not null[]) shr 32 == 0:
      while u > uint64(null[]):
        let q = u div 1e9.uint64
        var us = uint(u - q * 1e9.uint64) # us % 1e9 fits into a uintptr
        for j in countDown(9, 1):
          dec(i)
          let qs = us div 10
          a[i] = char((us - qs*10).int8 + '0'.int8)
          us = qs
        u = q
    # u guaranteed to fit into a uintptr
    var us = u
    while us >= 10.uint64:
      dec(i)
      let q = us div 10
      a[i] = char((us - q*10).int8 + '0'.int8)
      us = q
    
    # u < 10
    dec(i)
    a[i] = char(us.int8 + '0'.int8)
  elif shifts[base] > 0:
    var s = shifts[base]

    # base is power of 2: use shifts and masks instead of / and %
    var b = uint64(base)
    var m = b - 1 # == 1<<s - 1
    while u >= b:
      dec(i)
      a[i] = digits[(u and m).int]
      u = u shr s
    
    # u < base
    dec(i)
    a[i] = digits[u.int]
  else:
    # general case
    var b = uint64(base)
    while u >= b:
      dec(i)
      var q = u div b
      a[i] = digits[(u - q * b).int]
      u = q
    
    # u < base
    dec(i)
    a[i] = digits[u.int]
  
  # add sign, if any
  if neg:
    dec(i)
    a[i] = '-'
  
  if append:
    add(dst, cast[string](a[i..^1]))
    result.d = dst
#    return

  result.s = cast[string](a[i..^1])
  return
