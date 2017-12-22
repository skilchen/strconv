# Copyright 2009 The Go Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# package strconv

import tables

const 
  digits = "0123456789abcdefghijklmnopqrstuvwxyz"

var shifts: array[len(digits)+1,uint]
shifts[1 shl 1] = 1
shifts[1 shl 2] = 2
shifts[1 shl 3] = 3
shifts[1 shl 4] = 4
shifts[1 shl 5] = 5

when defined(js):
  proc formatBits*(dst: var string, u: uint64, base: int, neg, append: bool): tuple[d: string, s: string] =
    var u = u

    if base < 2 or base > len(digits):
      raise newException(ValueError, "strconv: illegal AppendInt/FormatInt base")
    
    # 2 <= base && base <= len(digits)

    var a: array[0..64, char] # +1 for sign of 64bit value in base 2
    var i = len(a)

    if neg:
      var temp = u.int64
      if temp != low(int64):
        temp = temp * -1
      u = uint64(temp)

    # convert bits
    if base == 10:
      var us = int64(u)
      while us >= 10:
        dec(i)
        let q = us div 10
        a[i] = char((us - q*10).int8 + '0'.int8)
        us = q
      
      # u < 10
      dec(i)
      a[i] = char(us.int8 + '0'.int8)
    elif shifts[base] > 0.uint:
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
      var b = int64(base)
      var us = int64(u)
      while us >= b:
        dec(i)
        var q = us div b
        a[i] = digits[(us - q * b).int8]
        us = q
      
      # u < base
      dec(i)
      a[i] = digits[us.int8]
    
    # add sign, if any
    if neg:
      dec(i)
      a[i] = '-'
    
    var rslt = cast[string](a[i..^1])
    setLen(rslt, len(a) - i)

    if append:
      add(dst, rslt)
      result.d = dst
  #    return

    result.s = rslt
    return
else:
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
      var temp = u.int64
      if temp != low(int64):
        temp = temp * -1
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
    elif shifts[base] > 0.uint:
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
    
    var rslt = cast[string](a[i..^1])
    setLen(rslt, len(a) - i)

    if append:
      add(dst, rslt)
      result.d = dst
  #    return

    result.s = rslt
    return


proc FormatUint*(i: uint64, base: int): string =
  ## FormatUint returns the string representation of i in the given base,
  ## for 2 <= base <= 36. The result uses the lower-case letters 'a' to 'z'
  ## for digit values >= 10.

  var dst:string = ""
  let rslt = formatBits(dst, i, base, false, false)
  return rslt.s


proc FormatInt*(i: int64, base: int): string =
  ## FormatInt returns the string representation of i in the given base,
  ## for 2 <= base <= 36. The result uses the lower-case letters 'a' to 'z'
  ## for digit values >= 10.
  var dst:string = ""
  let rslt = formatBits(dst, uint64(i), base, i < 0, false)
  return rslt.s


proc Itoa*(i: int): string =
  ## Itoa is shorthand for FormatInt(int64(i), 10).
  return FormatInt(int64(i), 10)


proc AppendInt*(dst: var string, i: int64, base: int): string =
  ## AppendInt appends the string form of the integer i,
  ## as generated by FormatInt, to dst and returns the extended buffer.
  discard formatBits(dst, uint64(i), base, i < 0, true)
  return dst


proc AppendUint*(dst: var string, i: uint64, base: int): string =
  ## AppendUint appends the string form of the unsigned integer i,
  ## as generated by FormatUint, to dst and returns the extended buffer.
  discard formatBits(dst, i, base, false, true)
  return dst




