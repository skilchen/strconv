# Copyright 2009 The Go Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

import strutils
import atoi

type atoui64Test = tuple 
  instr:  string
  outv: uint64
  errstr: string


var atoui64tests: seq[atoui64Test]
atoui64tests = @[
  ("", 0.uint64, "ErrSyntax"),
  ("0", 0.uint64, "nil"),
  ("1", 1.uint64, "nil"),
  ("12345", 12345.uint64, "nil"),
  ("012345", 12345.uint64, "nil"),
  ("12345x", 0.uint64, "ErrSyntax"),
  ("98765432100", 98765432100.uint64, "nil"),
  ("18446744073709551615", uint64(-1), "nil"),
  ("18446744073709551616", uint64(-1), "ErrRange"),
  ("18446744073709551620", uint64(-1), "ErrRange"),
]

var btoui64tests: seq[atoui64Test]
btoui64tests = @[
  ("", 0.uint64, "ErrSyntax"),
  ("0", 0.uint64, "nil"),
  ("0x", 0.uint64, "ErrSyntax"),
  ("0X", 0.uint64, "ErrSyntax"),
  ("1", 1.uint64, "nil"),
  ("12345", 12345.uint64, "nil"),
  ("012345", 5349.uint64, "nil"),
  ("0x12345", 0x12345.uint64, "nil"),
  ("0X12345", 0x12345.uint64, "nil"),
  ("12345x", 0.uint64, "ErrSyntax"),
  ("0xabcdefg123", 0.uint64, "ErrSyntax"),
  ("123456789abc", 0.uint64, "ErrSyntax"),
  ("98765432100", 98765432100.uint64, "nil"),
  ("18446744073709551615", uint64(-1), "nil"),
  ("18446744073709551616", uint64(-1), "ErrRange"),
  ("18446744073709551620", uint64(-1), "ErrRange"),
  ("0xFFFFFFFFFFFFFFFF", uint64(-1), "nil"),
  ("0x10000000000000000", uint64(-1), "ErrRange"),
  ("01777777777777777777777", uint64(-1), "nil"),
  ("01777777777777777777778", 0.uint64, "ErrSyntax"),
  ("02000000000000000000000", uint64(-1), "ErrRange"),
  ("0200000000000000000000", 1.uint64 shl  61, "nil"),
]

type atoi64Test = tuple
  instr: string
  outv: int64
  errstr: string


var atoi64tests: seq[atoi64Test]
atoi64tests = @[
  ("", 0.int64, "ErrSyntax"),
  ("0", 0.int64, "nil"),
  ("-0", 0.int64, "nil"),
  ("1", 1.int64, "nil"),
  ("-1", -1.int64, "nil"),
  ("12345", 12345.int64, "nil"),
  ("-12345", -12345.int64, "nil"),
  ("012345", 12345.int64, "nil"),
  ("-012345", -12345.int64, "nil"),
  ("98765432100", 98765432100.int64, "nil"),
  ("-98765432100", -98765432100.int64, "nil"),
  ("9223372036854775807", int64(1.uint64 shl 63 - 1), "nil"),
  ("-9223372036854775807", -int64(1.uint64 shl 63 - 1), "nil"),
  ("9223372036854775808", int64(1.uint64 shl 63 - 1), "ErrRange"),
  ("-9223372036854775808", -(1.int64 shl 63), "nil"),
  ("9223372036854775809", int64(1.uint64 shl 63 - 1), "ErrRange"),
  ("-9223372036854775809", -(1.int64 shl 63), "ErrRange"),
]

type btoi64Test = tuple
  instr: string
  base: int
  outv:  int64
  errstr: string


var btoi64tests: seq[btoi64Test]
btoi64tests = @[
  ("", 0, 0.int64, "ErrSyntax"),
  ("0", 0, 0.int64, "nil"),
  ("-0", 0, 0.int64, "nil"),
  ("1", 0, 1.int64, "nil"),
  ("-1", 0, -1.int64, "nil"),
  ("12345", 0, 12345.int64, "nil"),
  ("-12345", 0, -12345.int64, "nil"),
  ("012345", 0, 5349.int64, "nil"),
  ("-012345", 0, -5349.int64, "nil"),
  ("0x12345", 0, 0x12345.int64, "nil"),
  ("-0X12345", 0, -0x12345.int64, "nil"),
  ("12345x", 0, 0.int64, "ErrSyntax"),
  ("-12345x", 0, 0.int64, "ErrSyntax"),
  ("98765432100", 0, 98765432100.int64, "nil"),
  ("-98765432100", 0, -98765432100.int64, "nil"),
  ("9223372036854775807", 0, int64(1.uint64 shl 63 - 1), "nil"),
  ("-9223372036854775807", 0, -int64(1.uint64 shl 63 - 1), "nil"),
  ("9223372036854775808", 0, int64(1.uint64 shl 63 - 1), "ErrRange"),
  ("-9223372036854775808", 0, -(1.int64 shl 63), "nil"),
  ("9223372036854775809", 0, int64(1.uint64 shl 63 - 1), "ErrRange"),
  ("-9223372036854775809", 0, -1.int64 shl 63, "ErrRange"),

  # other bases
  ("g", 17, 16.int64, "nil"),
  ("10", 25, 25.int64, "nil"),
  ("holycow", 35, (((((17*35+24)*35+21)*35+34)*35+12)*35+24).int64 * 35 + 32, "nil"),
  ("holycow", 36, (((((17*36+24)*36+21)*36+34)*36+12)*36+24).int64 * 36 + 32, "nil"),

  # base 2
  ("0", 2, 0.int64, "nil"),
  ("-1", 2, -1.int64, "nil"),
  ("1010", 2, 10.int64, "nil"),
  ("1000000000000000", 2, 1.int64 shl 15, "nil"),
  ("111111111111111111111111111111111111111111111111111111111111111", 2, int64(1.uint64 shl 63 - 1), "nil"),
  ("1000000000000000000000000000000000000000000000000000000000000000", 2, int64(1.int64 shl 63 - 1), "ErrRange"),
  ("-1000000000000000000000000000000000000000000000000000000000000000", 2, -1.int64 shl 63, "nil"),
  ("-1000000000000000000000000000000000000000000000000000000000000001", 2, -1.int64 shl 63, "ErrRange"),

  # base 8
  ("-10", 8, -8.int64, "nil"),
  ("57635436545", 8, 6416645477.int64, "nil"),
  ("100000000", 8, 1.int64 shl 24, "nil"),

  # base 16
  ("10", 16, 16.int64, "nil"),
  ("-123456789abcdef", 16, -0x123456789abcdef, "nil"),
  ("7fffffffffffffff", 16, int64(1.uint64 shl 63 - 1), "nil"),
]

type atoui32Test = tuple
  instr: string
  outv: uint32
  errstr: string

var atoui32tests: seq[atoui32Test]
atoui32tests = @[
  ("", 0.uint32, "ErrSyntax"),
  ("0", 0.uint32, "nil"),
  ("1", 1.uint32, "nil"),
  ("12345", 12345.uint32, "nil"),
  ("012345", 12345.uint32, "nil"),
  ("12345x", 0.uint32, "ErrSyntax"),
  ("987654321", 987654321.uint32, "nil"),
  ("4294967295", 1.uint32 shl 32 - 1, "nil"),
  ("4294967296", 1.uint32 shl 32 - 1, "ErrRange"),
]

type atoi32Test = tuple
  instr: string
  outv: int32
  errstr: string


var atoi32tests: seq[atoi32Test]
atoi32tests = @[
  ("", 0.int32, "ErrSyntax"),
  ("0", 0.int32, "nil"),
  ("-0", 0.int32, "nil"),
  ("1", 1.int32, "nil"),
  ("-1", -1.int32, "nil"),
  ("12345", 12345.int32, "nil"),
  ("-12345", -12345.int32, "nil"),
  ("012345", 12345.int32, "nil"),
  ("-012345", -12345.int32, "nil"),
  ("12345x", 0.int32, "ErrSyntax"),
  ("-12345x", 0.int32, "ErrSyntax"),
  ("987654321", 987654321.int32, "nil"),
  ("-987654321", -987654321.int32, "nil"),
  ("2147483647", int32((1.uint32 shl 31) - 1), "nil"),
  ("-2147483647", -int32((1.uint32 shl 31 - 1)), "nil"),
  ("2147483648", int32(1.uint32 shl 31 - 1), "ErrRange"),
  ("-2147483648", -int32(1.uint32 shl 31), "nil"),
  ("2147483649", int32(1.uint32 shl 31 - 1), "ErrRange"),
  ("-2147483649", -int32(1.uint32 shl 31), "ErrRange"),
]

type numErrorTest = tuple
  num, want: string


var numErrorTests: seq[numErrorTest]
numErrorTests = @[
  ("0", """strconv.ParseFloat: parsing "0": failed"""),
  ("`", "strconv.ParseFloat: parsing \"`\": failed"),
  ("1\x00.2", """strconv.ParseFloat: parsing "1\x00.2": failed"""),
]


proc TestParseUint64() =
  for i in 0..high(atoui64tests):
    let test = atoui64tests[i]
    var outv: uint64
    var errstr = ""
    try:
      outv = ParseUint(test.instr, 10, 64)
      errstr = "nil"
    except SyntaxError:
      errstr = "ErrSyntax"
    except RangeError:
      outv = maxUint64
      errstr = "ErrRange"
    except:
      errstr = "other"
    if test.outv != outv or test.errstr != errstr:
      echo("Atoui64($#) = $#, $# want $#, $#" %
        [test.instr, $outv, errstr, $test.outv, test.errstr])


proc TestParseUint64Base() =
  for i in 0..high(btoui64tests):
    let test = btoui64tests[i]
    var outv: uint64
    var errstr = ""
    try:
      outv = ParseUint(test.instr, 0, 64)
      errstr = "nil"
    except SyntaxError:
      errstr = "ErrSyntax"
    except RangeError:
      outv = maxUint64
      errstr = "ErrRange"
    except:
      errstr = "other"

    if test.outv != outv or test.errstr != errstr:
      echo("ParseUint($#) = $#, $# want $#, $#" %
        [test.instr, $outv, errstr, $test.outv, test.errstr])


proc TestParseInt64()  =
  for i in 0..high(atoi64tests):
    let test = atoi64tests[i]
    var outv: int64
    var errstr = ""
    try:
      outv = ParseInt(test.instr, 10, 64)
      errstr = "nil"
    except SyntaxError:
      errstr = "ErrSyntax"
    except RangeError:
      if test.instr[0] == '-':
        outv = low(int64)
      else:
        outv = high(int64)
      errstr = "ErrRange"
    except:
      errstr = "other"
      raise
    if test.outv != outv or test.errstr != errstr:
      echo("Atoi64($#) = $#, $# want $#, $#" %
        [test.instr, $outv, errstr, $test.outv, test.errstr])
    

proc TestParseInt64Base() =
  for i in 0..high(btoi64tests):
    let test = btoi64tests[i]
    var outv: int64
    var errstr = ""
    try:
      outv = ParseInt(test.instr, test.base, 64)
      errstr = "nil"
    except SyntaxError:
      errstr = "ErrSyntax"
    except RangeError:
      if test.instr[0] == '-'  or 
         (test.base == 2 and len(test.instr) == 64 and test.instr[0] == '1'):
        outv = low(int64)
      else:
        outv = high(int64)
      errstr = "ErrRange"
    except:
      errstr = "other"
      raise

    if test.outv != outv or test.errstr != errstr:
      echo("ParseInt($#) = $#, $# want $#, $#" %
        [test.instr, $outv, errstr, $test.outv, test.errstr])


proc TestParseUint() =
  case IntSize
  of 32:
    for i in 0..high(atoui32tests):
      let test = atoui32tests[i]
      var outv: uint64
      var errstr = ""
      try:
        outv = ParseUint(test.instr, 10, 0)
        errstr = "nil"
      except SyntaxError:
        errstr = "ErrSyntax"
      except RangeError:
        if test.instr[0] == '-':
          outv = low(uint32)
        else:
          outv = high(uint32)
        errstr = "ErrRange"
      except:
        errstr = "other"

      if test.outv != uint32(outv) or test.errstr != errstr:
        echo("Atoui($#) = $#, $# want $#, $#" %
          [test.instr, $outv, errstr, $test.outv, $test.errstr])
  of 64:
    for i in 0..high(atoui32tests):
      let test = atoui64tests[i]
      var outv: uint64
      var errstr = ""
      try:
        outv = ParseUint(test.instr, 10, 0)
        errstr = "nil"
      except SyntaxError:
        errstr = "ErrSyntax"
      except RangeError:
        if test.instr[0] == '-':
          outv = uint64(-1)
        else:
          outv = uint64(-1)

        errstr = "ErrRange"
      except:
        errstr = "other"

      if test.outv != uint64(outv) or test.errstr != errstr:
        echo("Atoui($#) = $#, $# want $#, $#" %
          [test.instr, $outv, errstr, $test.outv, test.errstr])
  else:
    discard

proc TestParseInt() =
  case IntSize 
  of 32:
    for i in 0..high(atoi32tests):
      let test = atoi32tests[i]
      var outv: int64
      var errstr = ""
      try:
        outv = ParseInt(test.instr, 10, 0)
        errstr = "nil"
      except SyntaxError:
        errstr = "ErrSyntax"
      except RangeError:
        if test.instr[0] == '-':
          outv = low(int32)
        else:
          outv = high(int32)
        errstr = "ErrRange"
      except:
        errstr = "other"

      if test.outv != int32(outv) or test.errstr != errstr:
        echo("Atoi($#) = $#, $# want $#, $#" %
          [test.instr, $outv, errstr, $test.outv, test.errstr])
  of 64:
    for i in 0..high(atoi64tests):
      let test = atoi64tests[i]
      var outv: int64
      var errstr = ""
      try:
        outv = ParseInt(test.instr, 10, 0)
        errstr = "nil"
      except SyntaxError:
        errstr = "ErrSyntax"
      except RangeError:
        if test.instr[0] == '-':
          outv = low(int64)
        else:
          outv = high(int64)
        errstr = "ErrRange"
      except:
        errstr = "other"

      if test.outv != int64(outv) or test.errstr != errstr:
        echo("Atoi($#) = $#, $# want $#, $#" %
          [test.instr, $outv, errstr, $test.outv, test.errstr])
  else:
    discard    


TestParseUint64()
TestParseUint64Base()
TestParseInt64()
TestParseInt64Base()
TestParseUint()
TestParseInt()

# func TestNumError(t *testing.T) {
#   for _, test := range numErrorTests {
#     err := &NumError{
#       Func: "ParseFloat",
#       Num:  test.num,
#       Err:  errors.New("failed"),
#     }
#     if got := err.Error(); got != test.want {
#       t.Errorf(`(&NumError{"ParseFloat", %q, "failed"}).Error() = %v, want %v`, test.num, got, test.want)
#     }
#   }
# }

# func BenchmarkAtoi(b *testing.B) {
#   for i := 0; i < b.N; i++ {
#     ParseInt("12345678", 10, 0)
#   }
# }

# func BenchmarkAtoiNeg(b *testing.B) {
#   for i := 0; i < b.N; i++ {
#     ParseInt("-12345678", 10, 0)
#   }
# }

# func BenchmarkAtoi64(b *testing.B) {
#   for i := 0; i < b.N; i++ {
#     ParseInt("12345678901234", 10, 64)
#   }
# }

# func BenchmarkAtoi64Neg(b *testing.B) {
#   for i := 0; i < b.N; i++ {
#     ParseInt("-12345678901234", 10, 64)
#   }
# }
