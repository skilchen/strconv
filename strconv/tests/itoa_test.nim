# Copyright 2009 The Go Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# package strconv_test

import strutils
import itoa

type itob64Test = tuple
  inval: int64
  base: int
  outstr: string


var itob64tests: seq[itob64Test]
itob64tests = @[
  (int64(0), 10, "0"),
  (int64(1), 10, "1"),
  (int64(-1), 10, "-1"),
  (int64(12345678), 10, "12345678"),
  (int64(-987654321), 10, "-987654321"),
  (int64(1 shl 31 - 1), 10, "2147483647"),
  (int64(-1 shl 31 + 1), 10, "-2147483647"),
  (int64(1  shl  31), 10, "2147483648"),
  (int64(-1  shl  31), 10, "-2147483648"),
  (int64(1 shl 31 + 1), 10, "2147483649"),
  (int64(-1 shl 31 - 1), 10, "-2147483649"),
  (int64(1 shl 32 - 1), 10, "4294967295"),
  (int64(-1 shl 32 + 1), 10, "-4294967295"),
  (int64(1  shl  32), 10, "4294967296"),
  (int64(-1  shl  32), 10, "-4294967296"),
  (int64(1 shl 32 + 1), 10, "4294967297"),
  (int64(-1 shl 32 - 1), 10, "-4294967297"),
  (int64(1  shl  50), 10, "1125899906842624"),
  (int64(1.uint64 shl 63 - 1), 10, "9223372036854775807"),
  (int64(-1 shl 63 + 1), 10, "-9223372036854775807"),
  (int64(-1  shl  63), 10, "-9223372036854775808"),

  (int64(0), 2, "0"),
  (int64(10), 2, "1010"),
  (int64(-1), 2, "-1"),
  (int64(1 shl 15), 2, "1000000000000000"),

  (int64(-8), 8, "-10"),
  (int64(6416645477), 8, "57635436545"),
  (int64(1 shl 24), 8, "100000000"),

  (int64(16), 16, "10"),
  (-0x123456789abcdef, 16, "-123456789abcdef"),
  (int64(1.uint64 shl 63 - 1), 16, "7fffffffffffffff"),
  (int64(1.uint64 shl 63 - 1), 2, "111111111111111111111111111111111111111111111111111111111111111"),
  (int64(-1 shl 63), 2, "-1000000000000000000000000000000000000000000000000000000000000000"),

  (int64(16), 17, "g"),
  (int64(25), 25, "10"),
  (int64((((((17*35+24)*35+21)*35+34)*35+12)*35+24))*35 + 32, 35, "holycow"),
  (int64((((((17*36+24)*36+21)*36+34)*36+12)*36+24))*36 + 32, 36, "holycow"),
]

proc TestItoa() =
  for test in itob64tests:
    var s = FormatInt(test.inval, test.base)
    if s != test.outstr:
      echo("FormatInt($#, $#) = $# want $#" %
        [$test.inval, $test.base, s, test.outstr])
    
    var dst = "abc"
    var x = AppendInt(dst, test.inval, test.base)
    if x != "abc" & test.outstr:
      echo("AppendInt($#, $#, $#) = $# want $#" % 
        ["abc", $test.inval, $test.base, x, test.outstr])

    if test.inval >= 0:
      s = FormatUint(uint64(test.inval), test.base)
      if s != test.outstr:
        echo("FormatUint($#, $#) = $# want $#" %
          [$test.inval, $test.base, s, test.outstr])
      
      dst = ""
      x = AppendUint(dst, uint64(test.inval), test.base)
      if x != test.outstr:
        echo("AppendUint($#, $#, $#) = $# want $#" %
          ["abc", $uint64(test.inval), $test.base, x, test.outstr])

    if test.base == 10 and int64(int(test.inval)) == test.inval:
      s = Itoa(int(test.inval))
      if s != test.outstr:
        echo("Itoa($#) = $# want $#" %
          [$test.inval, s, test.outstr])
      

type uitob64Test = tuple
  inval: uint64
  base: int
  outstr: string


var uitob64tests: seq[uitob64Test]
uitob64tests = @[
  (uint64(1.uint64 shl 63 - 1), 10, "9223372036854775807"),
  (uint64(1.uint64 shl 63), 10, "9223372036854775808"),
  (uint64(1.uint64 shl 63 + 1), 10, "9223372036854775809"),
  (uint64(1.uint64 shl 64 - 3), 10, "18446744073709551614"),
  (uint64(-1), 10, "18446744073709551615"),
  (uint64(-1), 2, "1111111111111111111111111111111111111111111111111111111111111111"),
]

proc TestUitoa() =
  for test in uitob64tests:
    let s = FormatUint(test.inval, test.base)
    if s != test.outstr:
      echo("FormatUint($#, $#) = $# want $#" %
        [$test.inval, $test.base, s, test.outstr])
    
    var dst = "abc"
    let x = AppendUint(dst, test.inval, test.base)
    if x != "abc" & test.outstr:
      echo("AppendUint($#, $#, $#) = $# want $#" %
        ["abc", $test.inval, $test.base, x, test.outstr])
    

TestItoa()
TestUitoa()

# func BenchmarkFormatInt(b *testing.B) {
#   for i := 0; i < b.N; i++ {
#     for _, test := range itob64tests {
#       FormatInt(test.in, test.base)
#     )
#   )
# )

# func BenchmarkAppendInt(b *testing.B) {
#   dst := make([]byte, 0, 30)
#   for i := 0; i < b.N; i++ {
#     for _, test := range itob64tests {
#       AppendInt(dst, test.in, test.base)
#     )
#   )
# )

# func BenchmarkFormatUint(b *testing.B) {
#   for i := 0; i < b.N; i++ {
#     for _, test := range uitob64tests {
#       FormatUint(test.in, test.base)
#     )
#   )
# )

# func BenchmarkAppendUint(b *testing.B) {
#   dst := make([]byte, 0, 30)
#   for i := 0; i < b.N; i++ {
#     for _, test := range uitob64tests {
#       AppendUint(dst, test.in, test.base)
#     )
#   )
# )
