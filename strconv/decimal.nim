# Copyright 2009 The Go Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.
#
## Multiprecision decimal numbers.
## For floating-point formatting only; not general purpose.
## Only operations are assign and (binary) left/right shift.
## Can do binary floating point in multiprecision decimal precisely
## because 2 divides 10; cannot do decimal floating point
## in multiprecision binary precisely.


type decimal* = tuple
  d: array[0..2500, char] ## digits, big-endian representation
  nd: int                ## number of digits used
  dp: int                ## decimal point
  neg: bool
  trunc: bool ## discarded nonzero digits beyond d[:nd]


proc trim*(a: var decimal) =
  ## trim trailing zeros from number.
  ## (They are meaningless; the decimal point is tracked
  ## independent of the number of digits.)

  while a.nd > 0 and a.d[a.nd - 1] == '0':
      dec(a.nd)

  if a.nd == 0:
    a.dp = 0


proc Assign*(a: var decimal, v: uint64) =
  ## Assign v to a.
  var buf: array[24, char]
  var v = v
  # Write reversed decimal in buf.
  var n = 0
  while v > 0.uint64:
    var v1 = v div 10
    v -= 10.uint64 * v1
    buf[n] = char(v.int8 + '0'.int8)
    inc(n)
    v = v1

  # Reverse again to produce forward decimal in a.d.
  a.nd = 0
  n -= 1
  while n >= 0:
    a.d[a.nd] = buf[n]
    inc(a.nd)
    dec(n)

  a.dp = a.nd
  trim(a)


proc NewDecimal*(i: uint64): decimal =
  var d: decimal
  d.Assign(i)
  return d

proc digitZero(dst: var seq[char], from_idx, to_idx: int): int =
  for i in from_idx..to_idx:
    dst[i] = '0'
  return to_idx - from_idx


proc copy*(dst: var seq[char], src: seq[char], start_idx: int): int =
  let len_to_copy = min(high(dst) - start_idx, high(src))
  var j = 0
  for i in start_idx..start_idx+len_to_copy:
    dst[i] = src[j]
    inc(j)
  return j


proc `$`*(a: decimal): string =
  var n = 10 + a.nd
  if a.dp > 0:
    n += a.dp

  if a.dp < 0:
    n += (-a.dp)

  var buf = newSeq[char](n)
  var w = 0
  if a.nd == 0:
    return "0"
  elif a.dp <= 0:
    # zeros fill space between decimal point and digits
    buf[w] = '0'
    inc(w)
    buf[w] = '.'
    inc(w)
    w += digitZero(buf, w, w + -a.dp)
    w += copy(buf, a.d[0 .. a.nd - 1], w)

  elif a.dp < a.nd:
    # decimal point in middle of digits
    w += copy(buf, a.d[0..a.dp-1], w)
    buf[w] = '.'
    inc(w)
    w += copy(buf, a.d[a.dp..a.nd-1], w)

  else:
    # zeros fill space between digits and decimal point
    w += copy(buf, a.d[0..a.nd-1], w)
    w += digitZero(buf, w, w + a.dp - a.nd)

  
  result = cast[string](buf[0..w])
  result.setLen(w)


const uintSize = 32 shl ((not uint(0)) shr 63)
const maxShift = uintSize - 4
# Maximum shift that we can do in one pass without overflow.
# A uint has 32 or 64 bits, and we have to be able to accommodate 9<<k.


proc rightShift*(a: var decimal, k: uint) =
  ## Binary shift right (/ 2) by k bits.  k <= maxShift to avoid overflow.
  var r = 0 # read pointer
  var w = 0 # write pointer

  # Pick up enough leading digits to cover first shift.
  var n: uint = 0
  while (n shr k) == 0:
#  for ; n>>k == 0; r++ {
    if r >= a.nd:
      if n == 0:
        # a == 0; shouldn't get here, but handle anyway.
        a.nd = 0
        return

      while (n shr k) == 0:
        n = n * 10
        inc(r)
      break
    let c = uint(a.d[r])
    n = n * 10 + c - '0'.uint8
    inc(r)
  
  a.dp = a.dp - (r - 1)

  var mask: uint = ((1 shl k) - 1).uint

  # Pick up a digit, put down a digit.
  while r < a.nd:
  # for ; r < a.nd; r++ {
    let c = uint(a.d[r])
    let dig = n shr k
    n = n and mask
    a.d[w] = char(dig + '0'.uint8)
    inc(w)
    n = n * 10 + c - '0'.uint8
    inc(r)


  # Put down extra digits.
  while n > 0.uint:
    let dig = n shr k
    n  = n and mask
    if w < len(a.d):
      a.d[w] = char(dig + '0'.uint8)
      inc(w)
    elif dig > 0.uint:
      a.trunc = true
    n = n * 10
    
  a.nd = w
  trim(a)


type leftCheat* = tuple
  ## Cheat sheet for left shift: table indexed by shift count giving
  ## number of new digits that will be introduced by that shift.
  ##
  ## For example, leftcheats[4] = {2, "625"}.  That means that
  ## if we are shifting by 4 (multiplying by 16), it will add 2 digits
  ## when the string prefix is "625" through "999", and one fewer digit
  ## if the string prefix is "000" through "624".
  ##
  ## Credit for this trick goes to Ken.  
  delta:  int    ## number of new digits
  cutoff: string ## minus one digit if original < a.


  # Leading digits of 1/2^i = 5^i.
  # 5^23 is not an exact 64-bit floating point number,
  # so have to use bc for the math.
  # Go up to 60 to be large enough for 32bit and 64bit platforms.
  #[ 
    seq 60 | sed 's/^/5^/' | bc |
    awk 'BEGIN{ print "\t{ 0, \"\" }," }
    {
      log2 = log(2)/log(10)
      printf("\t{ %d, \"%s\" },\t// * %d\n",
              int(log2*NR+1), $0, 2**NR)
    }'
  ]#

const leftcheats*: seq[leftCheat] = @[
  (0, ""),
  (1, "5"),                                           # * 2
  (1, "25"),                                          # * 4
  (1, "125"),                                         # * 8
  (2, "625"),                                         # * 16
  (2, "3125"),                                        # * 32
  (2, "15625"),                                       # * 64
  (3, "78125"),                                       # * 128
  (3, "390625"),                                      # * 256
  (3, "1953125"),                                     # * 512
  (4, "9765625"),                                     # * 1024
  (4, "48828125"),                                    # * 2048
  (4, "244140625"),                                   # * 4096
  (4, "1220703125"),                                  # * 8192
  (5, "6103515625"),                                  # * 16384
  (5, "30517578125"),                                 # * 32768
  (5, "152587890625"),                                # * 65536
  (6, "762939453125"),                                # * 131072
  (6, "3814697265625"),                               # * 262144
  (6, "19073486328125"),                              # * 524288
  (7, "95367431640625"),                              # * 1048576
  (7, "476837158203125"),                             # * 2097152
  (7, "2384185791015625"),                            # * 4194304
  (7, "11920928955078125"),                           # * 8388608
  (8, "59604644775390625"),                           # * 16777216
  (8, "298023223876953125"),                          # * 33554432
  (8, "1490116119384765625"),                         # * 67108864
  (9, "7450580596923828125"),                         # * 134217728
  (9, "37252902984619140625"),                        # * 268435456
  (9, "186264514923095703125"),                       # * 536870912
  (10, "931322574615478515625"),                      # * 1073741824
  (10, "4656612873077392578125"),                     # * 2147483648
  (10, "23283064365386962890625"),                    # * 4294967296
  (10, "116415321826934814453125"),                   # * 8589934592
  (11, "582076609134674072265625"),                   # * 17179869184
  (11, "2910383045673370361328125"),                  # * 34359738368
  (11, "14551915228366851806640625"),                 # * 68719476736
  (12, "72759576141834259033203125"),                 # * 137438953472
  (12, "363797880709171295166015625"),                # * 274877906944
  (12, "1818989403545856475830078125"),               # * 549755813888
  (13, "9094947017729282379150390625"),               # * 1099511627776
  (13, "45474735088646411895751953125"),              # * 2199023255552
  (13, "227373675443232059478759765625"),             # * 4398046511104
  (13, "1136868377216160297393798828125"),            # * 8796093022208
  (14, "5684341886080801486968994140625"),            # * 17592186044416
  (14, "28421709430404007434844970703125"),           # * 35184372088832
  (14, "142108547152020037174224853515625"),          # * 70368744177664
  (15, "710542735760100185871124267578125"),          # * 140737488355328
  (15, "3552713678800500929355621337890625"),         # * 281474976710656
  (15, "17763568394002504646778106689453125"),        # * 562949953421312
  (16, "88817841970012523233890533447265625"),        # * 1125899906842624
  (16, "444089209850062616169452667236328125"),       # * 2251799813685248
  (16, "2220446049250313080847263336181640625"),      # * 4503599627370496
  (16, "11102230246251565404236316680908203125"),     # * 9007199254740992
  (17, "55511151231257827021181583404541015625"),     # * 18014398509481984
  (17, "277555756156289135105907917022705078125"),    # * 36028797018963968
  (17, "1387778780781445675529539585113525390625"),   # * 72057594037927936
  (18, "6938893903907228377647697925567626953125"),   # * 144115188075855872
  (18, "34694469519536141888238489627838134765625"),  # * 288230376151711744
  (18, "173472347597680709441192448139190673828125"), # * 576460752303423488
  (19, "867361737988403547205962240695953369140625"), # * 1152921504606846976
]


proc prefixIsLessThan*(b: seq[char], s: string): bool =
  ## Is the leading prefix of b lexicographically less than s?
  for i in countUp(0, high(s)):
  #for i := 0; i < len(s); i++ {
    if i >= len(b):
      return true
    
    if b[i] != s[i]:
      return b[i] < s[i]
  return false


proc leftShift*(a: var decimal, k: int) =
  ## Binary shift left (* 2) by k bits.  k <= maxShift to avoid overflow.

  var delta = leftcheats[k].delta
  if prefixIsLessThan(a.d[0..a.nd-1], leftcheats[k].cutoff):
    dec(delta)

  var r = a.nd         # read index
  var w = a.nd + delta # write index

  # Pick up a digit, put down a digit.
  var n: uint = 0.uint
  dec(r)
  while r >= 0:
  # for r--; r >= 0; r-- {
    n += ((uint(a.d[r]) - '0'.uint8) shl k)
    let quo = n div 10
    let rem = n - 10.uint * quo
    dec(w)
    # echo "w: ", w
    if w < len(a.d):
      a.d[w] = char(rem + '0'.uint8)
    elif rem != 0:
      a.trunc = true
    n = quo
    dec(r)

  # Put down extra digits.
  while n > 0.uint:
    let quo = n div 10
    let rem = n - 10.uint * quo
    dec(w)
    if w < len(a.d):
      a.d[w] = char(rem + '0'.uint8)
    elif rem != 0.uint:
      a.trunc = true
    n = quo

  a.nd += delta
  if a.nd >= len(a.d):
    a.nd = len(a.d)

  a.dp += delta
  trim(a)


proc Shift*(a: var decimal, k: int) =
  ## Binary shift left (k > 0) or right (k < 0).
  var k = k
  if a.nd == 0:
    # nothing to do: a == 0
    discard
  elif k > 0:
    while k > maxShift:
      leftShift(a, maxShift)
      k -= maxShift
    leftShift(a, k)
  elif k < 0:
    while k < (-maxShift):
      rightShift(a, maxShift)
      k += maxShift
    rightShift(a, uint(-k))


proc shouldRoundUp*(a: var decimal, nd: int): bool =
  ## If we chop a at nd digits, should we round up?
  if nd < 0 or nd >= a.nd:
    return false
  
  if a.d[nd] == '5' and nd+1 == a.nd: # exactly halfway - round to even
    # if we truncated, a little higher than what's recorded - always round up
    if a.trunc:
      return true
    
    return nd > 0 and (a.d[nd-1].int8 - '0'.int8) mod 2 != 0

  # not halfway - digit tells all
  return a.d[nd] >= '5'


## Round a up to nd digits (or fewer).
proc RoundUp*(a: var decimal, nd: int) =
  if nd < 0 or nd >= a.nd:
    return

  # round up
  for i in countDown(nd - 1, 0):
  # for i := nd - 1; i >= 0; i-- {
    let c = a.d[i]
    if c < '9':  # can stop after this digit
      inc(a.d[i])
      a.nd = i + 1
      return

  # Number is all 9s.
  # Change to single 1 with adjusted decimal point.
  a.d[0] = '1'
  a.nd = 1
  inc(a.dp)


proc RoundDown*(a: var decimal, nd: int) =
  ## Round a down to nd digits (or fewer).
  if nd < 0 or nd >= a.nd:
    return

  a.nd = nd
  trim(a)


proc Round*(a: var decimal, nd: int) =
  ## Round a to nd digits (or fewer).
  ## If nd is zero, it means we're rounding
  ## just to the left of the digits, as in
  ## 0.09 -> 0.1.

  if nd < 0 or nd >= a.nd:
    return
  
  if shouldRoundUp(a, nd):
    a.RoundUp(nd)
  else:
    a.RoundDown(nd)


proc RoundedInteger*(a: var decimal): uint64 =
  ## Extract integer part, rounded appropriately.
  ## No guarantees about overflow.

  if a.dp > 20:
    return uint64(0xFFFFFFFFFFFFFFFF)
  
  var i: int
  var n = uint64(0)
  while i < a.dp and i < a.nd:
  #for i = 0; i < a.dp && i < a.nd; i++ {
    n = n * 10 + uint64(a.d[i].int8 - '0'.int8)
    inc(i)

  while i < a.dp:
  #for ; i < a.dp; i++ {
    n *= 10
    inc(i)

  if shouldRoundUp(a, a.dp):
    inc(n)

  return n

