# Copyright 2009 The Go Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# package strconv

# import "errors"

import strutils

converter toInt(x: char): int = result = ord(x)
converter toChar(x: int): char = result = chr(x)

# // ErrRange indicates that a value is out of range for the target type.
# var ErrRange = errors.New("value out of range")

# // ErrSyntax indicates that a value does not have the right syntax for the target type.
# var ErrSyntax = errors.New("invalid syntax")

# // A NumError records a failed conversion.
# type NumError struct {
#   Func string // the failing function (ParseBool, ParseInt, ParseUint, ParseFloat)
#   Num  string // the input
#   Err  error  // the reason the conversion failed (ErrRange, ErrSyntax)
# }

# func (e *NumError) Error() string {
#   return "strconv." + e.Func + ": " + "parsing " + Quote(e.Num) + ": " + e.Err.Error()
# }

# func syntaxError(fn, str string) *NumError {
#   return &NumError{fn, str, ErrSyntax}
# }

# func rangeError(fn, str string) *NumError {
#   return &NumError{fn, str, ErrRange}
# }

type SyntaxError* = object of Exception

const intSize = 32 shl ((not uint(0)) shr 63)

const IntSize* = intSize
## IntSize is the size in bits of an int or uint value.

const maxUint64* = uint64(-1)

## ParseUint is like ParseInt but for unsigned numbers.
proc ParseUint*(s: string, base: int, bitSize: int): uint64 =
  var n: uint64
  var cutoff, maxVal: uint64

  var base = base
  var bitSize = bitSize
  if bitSize == 0:
    bitSize = int(IntSize)

  var i = 0

  if len(s) < 1:
    raise newException(SyntaxError, "can't parse $# as uint" % [s])
  elif 2 <= base and base <= 36:
    # valid base; nothing to do
    discard
  elif base == 0:
    # Look for octal, hex prefix.
    if s[0] == '0' and len(s) > 1 and (s[1] == 'x' or s[1] == 'X'):
      if len(s) < 3:
        raise newException(SyntaxError, "can't parse $# as uint" % [s])
      base = 16
      i = 2
    elif s[0] == '0':
      base = 8
      i = 1
    else:
      base = 10

  else:
    raise newException(ValueError, "Invalid base " & $base)

  # Cutoff is the smallest number such that cutoff*base > maxUint64.
  # Use compile-time constants for common cases.
  if base == 10:
    cutoff = maxUint64 div 10 + 1
  elif base == 16:
    cutoff = maxUint64 div 16 + 1
  else:
    cutoff = maxUint64 div uint64(base) + 1.uint64

#  echo "bitsize: ", bitSize

  maxVal = if bitSize == 64: uint64(-1) else: 1.uint64 shl (bitSize) - 1

  while i < len(s):
  # for ; i < len(s); i++ {
    var v: char
    var d = s[i]

    if '0' <= d and d <= '9':
      v = d - '0'
    elif 'a' <= d and d <= 'z':
      v = d - 'a' + 10
    elif 'A' <= d and d <= 'Z':
      v = d - 'A' + 10
    else:
      raise newException(SyntaxError, "can't parse $# as uint" % [s])

    if v >= char(base):
      raise newException(SyntaxError, "can' parse $# as uint in base $#" % [s, $base])

    if n >= cutoff:
      # n * base overflows
      raise newException(RangeError, "can't parse $# as uint: overflow" % [s])

    n *= uint64(base)
    var n1 = n + uint64(v)
    # echo "n: ", n
    # echo "n1: ", n1
    # echo "maxVal: ", maxVal

    if n1 < n or n1 > maxVal:
      # n+v overflows
      raise newException(RangeError, "can't parse $# as uint: overflow")
    n = n1
    inc(i)

  return n


proc ParseInt*(s: string, base: int, bitSize: int): int64 =
  ## ParseInt interprets a string s in the given base (2 to 36) and
  ## returns the corresponding value i. If base == 0, the base is
  ## implied by the string's prefix: base 16 for "0x", base 8 for
  ## "0", and base 10 otherwise.
  ##
  ## The bitSize argument specifies the integer type
  ## that the result must fit into. Bit sizes 0, 8, 16, 32, and 64
  ## correspond to int, int8, int16, int32, and int64.
  ##
  ## The errors that ParseInt returns have concrete type ptr NumError
  ## and include err.Num = s. If s is empty or contains invalid
  ## digits, err.Err = ErrSyntax and the returned value is 0;
  ## if the value corresponding to s cannot be represented by a
  ## signed integer of the given size, err.Err = ErrRange and the
  ## returned value is the maximum magnitude integer of the
  ## appropriate bitSize and sign.

  var s = s
  var base = base
  var bitsize = bitSize

  if bitSize == 0:
    bitSize = int(IntSize)


  ## Empty string bad.
  if len(s) == 0:
    raise newException(SyntaxError, "can't parse empty string as int")

  # Pick off leading sign.
  var neg = false
  if s[0] == '+':
    s = s[1..^1]
  elif s[0] == '-':
    neg = true
    s = s[1..^1]


  # Convert unsigned and check range.
  var un: uint64
  try:
    un = ParseUint(s, base, bitSize)
  except:
    raise

  var cutoff = uint64(1 shl uint(bitSize - 1))
  if not neg and un >= cutoff:
    raise newException(RangeError, "can't parse $# as int" % [s])

  if neg and un > cutoff:
    raise newException(RangeError, "can't parse $# as int" % [s])

  var n = int64(un)
  if neg:
    if n > 0:
      n = -n

  return n


## Atoi returns the result of ParseInt(s, 10, 0) converted to type int.
proc Atoi*(s: string): int =
  var i64 = ParseInt(s, 10, 0)
  return int(i64)

