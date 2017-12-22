## Copyright 2009 The Go Authors. All rights reserved.
## Use of this source code is governed by a BSD-style
## license that can be found in the LICENSE file.

# package strconv_test

import
  math,
  random,
  strutils

import atof
import float2bits
import ftoa
import typetraits

type atofTest = tuple
  instr:  string
  outstr: string
  errstr: string

const ErrSyntax = "syntax error"
const ErrRange = "range error"

var atoftests: seq[atofTest]
atoftests = @[
  ("", "0", ErrSyntax),
  ("1", "1", "nil"),
  ("+1", "1", "nil"),
  ("1x", "0", ErrSyntax),
  ("1.1.", "0", ErrSyntax),
  ("1e23", "1e+23", "nil"),
  ("1E23", "1e+23", "nil"),
  ("100000000000000000000000", "1e+23", "nil"),
  ("1e-100", "1e-100", "nil"),
  ("123456700", "1.234567e+08", "nil"),
  ("99999999999999974834176", "9.999999999999997e+22", "nil"),
  ("100000000000000000000001", "1.0000000000000001e+23", "nil"),
  ("100000000000000008388608", "1.0000000000000001e+23", "nil"),
  ("100000000000000016777215", "1.0000000000000001e+23", "nil"),
  ("100000000000000016777216", "1.0000000000000003e+23", "nil"),
  ("-1", "-1", "nil"),
  ("-0.1", "-0.1", "nil"),
  ("-0", "-0", "nil"),
  ("1e-20", "1e-20", "nil"),
  ("625e-3", "0.625", "nil"),

  # zeros
  ("0", "0", "nil"),
  ("0e0", "0", "nil"),
  ("-0e0", "-0", "nil"),
  ("+0e0", "0", "nil"),
  ("0e-0", "0", "nil"),
  ("-0e-0", "-0", "nil"),
  ("+0e-0", "0", "nil"),
  ("0e+0", "0", "nil"),
  ("-0e+0", "-0", "nil"),
  ("+0e+0", "0", "nil"),
  ("0e+01234567890123456789", "0", "nil"),
  ("0.00e-01234567890123456789", "0", "nil"),
  ("-0e+01234567890123456789", "-0", "nil"),
  ("-0.00e-01234567890123456789", "-0", "nil"),
  ("0e291", "0", "nil"), # issue 15364
  ("0e292", "0", "nil"), # issue 15364
  ("0e347", "0", "nil"), # issue 15364
  ("0e348", "0", "nil"), # issue 15364
  ("-0e291", "-0", "nil"),
  ("-0e292", "-0", "nil"),
  ("-0e347", "-0", "nil"),
  ("-0e348", "-0", "nil"),

  # NaNs
  ("nan", "NaN", "nil"),
  ("NaN", "NaN", "nil"),
  ("NAN", "NaN", "nil"),

  # Infs
  ("inf", "+Inf", "nil"),
  ("-Inf", "-Inf", "nil"),
  ("+INF", "+Inf", "nil"),
  ("-Infinity", "-Inf", "nil"),
  ("+INFINITY", "+Inf", "nil"),
  ("Infinity", "+Inf", "nil"),

  # largest float64
  ("1.7976931348623157e308", "1.7976931348623157e+308", "nil"),
  ("-1.7976931348623157e308", "-1.7976931348623157e+308", "nil"),
  # next float64 - too large
  ("1.7976931348623159e308", "+Inf", ErrRange),
  ("-1.7976931348623159e308", "-Inf", ErrRange),
  # the border is ...158079
  # borderline - okay
  ("1.7976931348623158e308", "1.7976931348623157e+308", "nil"),
  ("-1.7976931348623158e308", "-1.7976931348623157e+308", "nil"),
  # borderline - too large
  ("1.797693134862315808e308", "+Inf", ErrRange),
  ("-1.797693134862315808e308", "-Inf", ErrRange),

  # a little too large
  ("1e308", "1e+308", "nil"),
  ("2e308", "+Inf", ErrRange),
  ("1e309", "+Inf", ErrRange),

  # way too large
  ("1e310", "+Inf", ErrRange),
  ("-1e310", "-Inf", ErrRange),
  ("1e400", "+Inf", ErrRange),
  ("-1e400", "-Inf", ErrRange),
  ("1e400000", "+Inf", ErrRange),
  ("-1e400000", "-Inf", ErrRange),

  # denormalized
  ("1e-305", "1e-305", "nil"),
  ("1e-306", "1e-306", "nil"),
  ("1e-307", "1e-307", "nil"),
  ("1e-308", "1e-308", "nil"),
  ("1e-309", "1e-309", "nil"),
  ("1e-310", "1e-310", "nil"),
  ("1e-322", "1e-322", "nil"),
  # smallest denormal
  ("5e-324", "5e-324", "nil"),
  ("4e-324", "5e-324", "nil"),
  ("3e-324", "5e-324", "nil"),
  # too small
  ("2e-324", "0", "nil"),
  # way too small
  ("1e-350", "0", "nil"),
  ("1e-400000", "0", "nil"),

  # try to overflow exponent
  ("1e-4294967296", "0", "nil"),
  ("1e+4294967296", "+Inf", ErrRange),
  ("1e-18446744073709551616", "0", "nil"),
  ("1e+18446744073709551616", "+Inf", ErrRange),

  # Parse errors
  ("1e", "0", ErrSyntax),
  ("1e-", "0", ErrSyntax),
  (".e-1", "0", ErrSyntax),
  ("1\x00.2", "0", ErrSyntax),

  # http:#www.exploringbinary.com/java-hangs-when-converting-2-2250738585072012e-308/
  ("2.2250738585072012e-308", "2.2250738585072014e-308", "nil"),
  # http:#www.exploringbinary.com/php-hangs-on-numeric-value-2-2250738585072011e-308/
  ("2.2250738585072011e-308", "2.225073858507201e-308", "nil"),

  # A very large number (initially wrongly parsed by the fast algorithm).
  ("4.630813248087435e+307", "4.630813248087435e+307", "nil"),

  # A different kind of very large number.
  ("22.222222222222222", "22.22222222222222", "nil"),
  ("2." & repeat("2", 4000) & "e+1", "22.22222222222222", "nil"),

  # Exactly halfway between 1 and math.Nextafter(1, 2).
  # Round to even (down).
  ("1.00000000000000011102230246251565404236316680908203125", "1", "nil"),
  # Slightly lower; still round down.
  ("1.00000000000000011102230246251565404236316680908203124", "1", "nil"),
  # Slightly higher; round up.
  ("1.00000000000000011102230246251565404236316680908203126", "1.0000000000000002", "nil"),
  # Slightly higher, but you have to read all the way to the end.
  ("1.00000000000000011102230246251565404236316680908203125" & repeat("0", 10000) & "1", "1.0000000000000002", "nil"),
]

var atof32tests: seq[atofTest]
atof32tests = @[
  # Exactly halfway between 1 and the next float32.
  # Round to even (down).
  ("1.000000059604644775390625", "1", "nil"),
  # Slightly lower.
  ("1.000000059604644775390624", "1", "nil"),
  # Slightly higher.
  ("1.000000059604644775390626", "1.0000001", "nil"),
  # Slightly higher, but you have to read all the way to the end.
  ("1.000000059604644775390625" & repeat("0", 10000) & "1", "1.0000001", "nil"),

  # largest float32: (1<<128) * (1 - 2^-24)
  ("340282346638528859811704183484516925440", "3.4028235e+38", "nil"),
  ("-340282346638528859811704183484516925440", "-3.4028235e+38", "nil"),
  # next float32 - too large
  ("3.4028236e38", "+Inf", ErrRange),
  ("-3.4028236e38", "-Inf", ErrRange),
  # the border is 3.40282356779...e+38
  # borderline - okay
  ("3.402823567e38", "3.4028235e+38", "nil"),
  ("-3.402823567e38", "-3.4028235e+38", "nil"),
  # borderline - too large
  ("3.4028235678e38", "+Inf", ErrRange),
  ("-3.4028235678e38", "-Inf", ErrRange),

  # Denormals: less than 2^-126
  ("1e-38", "1e-38", "nil"),
  ("1e-39", "1e-39", "nil"),
  ("1e-40", "1e-40", "nil"),
  ("1e-41", "1e-41", "nil"),
  ("1e-42", "1e-42", "nil"),
  ("1e-43", "1e-43", "nil"),
  ("1e-44", "1e-44", "nil"),
  ("6e-45", "6e-45", "nil"), # 4p-149 = 5.6e-45
  ("5e-45", "6e-45", "nil"),
  # Smallest denormal
  ("1e-45", "1e-45", "nil"), # 1p-149 = 1.4e-45
  ("2e-45", "1e-45", "nil"),

  # 2^92 = 8388608p+69 = 4951760157141521099596496896 (4.9517602e27)
  # is an exact power of two that needs 8 decimal digits to be correctly
  # parsed back.
  # The float32 before is 16777215p+68 = 4.95175986e+27
  # The halfway is 4.951760009. A bad algorithm that thinks the previous
  # float32 is 8388607p+69 will shorten incorrectly to 4.95176e+27.
  ("4951760157141521099596496896", "4.9517602e+27", "nil"),
]

type atofSimpleTest = tuple
  x: float64
  s: string


var
  atofRandomTests:       seq[atofSimpleTest]
  benchmarksRandomBits =   newSeq[string](1024)
  benchmarksRandomNormal =  newSeq[string](1024)

const Short = true

proc init() =
  # # The atof routines return NumErrors wrapping
  # # the error and the string. Convert the table above.
  # for i := range atoftests {
  #   test := &atoftests[i]
  #   if test.err != nil {
  #     test.err = &NumError{"ParseFloat", test.in, test.err}
  #   }
  # }
  # for i := range atof32tests {
  #   test := &atof32tests[i]
  #   if test.err != nil {
  #     test.err = &NumError{"ParseFloat", test.in, test.err}
  #   }
  # }

  # Generate random inputs for tests and benchmarks
  randomize()
  if Short:
    atofRandomTests = newSeq[atofSimpleTest](100)
  else:
    atofRandomTests = newSeq[atofSimpleTest](10000)

  for i in 0..high(atofRandomTests):
    let n = uint64(random(high(int))) shl 32 or uint64(random(high(int)))
    let x = float64frombits(n)
    let s = FormatFloat(x, 'g', -1, 64)
    atofRandomTests[i] = (x, s)

  for i in 0..high(benchmarksRandomBits):
    let bits = uint64(random(high(int))) shl 32 or uint64(random(high(int)))
    let x = float64frombits(bits)
    benchmarksRandomBits[i] = FormatFloat(x, 'g', -1, 64)

  for i in 0..high(benchmarksRandomNormal):
    let x = random(1e300)
    benchmarksRandomNormal[i] = FormatFloat(x, 'g', -1, 64)


proc testAtof(opt: bool = false) =
  var outstr: string
  var errstr: string
  var oldopt = SetOptimize(opt)
  for i in 0..high(atoftests):
    let test = atoftests[i]

    var parsedFloat: float
    try:
      parsedFloat = ParseFloat(test.instr, 64)
      errstr = test.errstr
    except OverFlowError:
      errstr = ErrRange
    except:
      errstr = ErrSyntax

    outstr = FormatFloat(parsedFloat, 'g', -1, 64)
    if outstr != test.outstr or errstr != test.errstr:
      echo("ParseFloat($#, 64) = $#, $# want $#, $#" %
        [test.instr, outstr, errstr, test.outstr, test.errstr])

    if float64(float32(parsedFloat)) == parsedFloat:
      try:
        parsedFloat = ParseFloat(test.instr, 32)
        errstr = test.errstr
      except OverFlowError:
        errstr = ErrRange
      except:
        errstr = ErrSyntax

      let out32 = float32(parsedFloat)
      if float64(out32) != parsedFloat:
        echo("ParseFloat($#, 32) = $#, not a float32 (closest is $#)" % 
          [test.instr, $parsedFloat, $float64(out32)])
        continue
      
      outstr = FormatFloat(float64(out32), 'g', -1, 32)
      if outstr != test.outstr or errstr != test.errstr:
        echo("ParseFloat($#, 32) = $#, $# want $#, $#  -- $#" %
          [test.instr, outstr, errstr, test.outstr, test.errstr, $parsedFloat])
      
    
  for test in atof32tests:
    var parsedFloat: float32 = 0.0
    errstr = "nil"
    try:
      parsedFloat = ParseFloat(test.instr, 32)
      errstr = test.errstr
    except OverFlowError:
      errstr = ErrRange
    except:
      parsedFloat = 0.0
      errstr = ErrSyntax

    let out32 = float32(parsedFloat)
    if float64(out32) != parsedFloat:
      echo("ParseFloat($#, 32) = $#, not a float32 (closest is $#)" %
         [test.instr, $parsedFloat, $float64(out32)])
      continue

    outstr = FormatFloat(out32, 'g', -1, 32)
    if $outstr != $test.outstr: # or errstr != test.errstr:
      echo("ParseFloat($#, 32) = $#, $# want $#, $#  -- $#" %
        [test.instr, outstr, errstr, test.outstr, test.errstr, $parsedFloat])
    
  discard SetOptimize(oldopt)


proc TestAtof() = testAtof(true)

proc TestAtofSlow() = testAtof(false)

TestAtof()
TestAtofSlow()

# func TestAtofRandom(t *testing.T) {
#   for _, test := range atofRandomTests {
#     x, _ := ParseFloat(test.s, 64)
#     switch {
#     default:
#       t.Errorf("number %s badly parsed as %b (expected %b)", test.s, x, test.x)
#     case x == test.x:
#     case math.IsNaN(test.x) && math.IsNaN(x):
#     }
#   }
#   t.Logf("tested %d random numbers", len(atofRandomTests))
# }

# var roundTripCases = []struct {
#   f float64
#   s string
# }{
#   # Issue 2917.
#   # This test will break the optimized conversion if the
#   # FPU is using 80-bit registers instead of 64-bit registers,
#   # usually because the operating system initialized the
#   # thread with 80-bit precision and the Go runtime didn't
#   # fix the FP control word.
#   {8865794286000691 << 39, "4.87402195346389e+27"},
#   {8865794286000692 << 39, "4.8740219534638903e+27"},
# }

# func TestRoundTrip(t *testing.T) {
#   for _, tt := range roundTripCases {
#     old := SetOptimize(false)
#     s := FormatFloat(tt.f, 'g', -1, 64)
#     if s != tt.s {
#       t.Errorf("no-opt FormatFloat(%b) = %s, want %s", tt.f, s, tt.s)
#     }
#     f, err := ParseFloat(tt.s, 64)
#     if f != tt.f || err != nil {
#       t.Errorf("no-opt ParseFloat(%s) = %b, %v want %b, nil", tt.s, f, err, tt.f)
#     }
#     SetOptimize(true)
#     s = FormatFloat(tt.f, 'g', -1, 64)
#     if s != tt.s {
#       t.Errorf("opt FormatFloat(%b) = %s, want %s", tt.f, s, tt.s)
#     }
#     f, err = ParseFloat(tt.s, 64)
#     if f != tt.f || err != nil {
#       t.Errorf("opt ParseFloat(%s) = %b, %v want %b, nil", tt.s, f, err, tt.f)
#     }
#     SetOptimize(old)
#   }
# }

# # TestRoundTrip32 tries a fraction of all finite positive float32 values.
# func TestRoundTrip32(t *testing.T) {
#   step := uint32(997)
#   if testing.Short() {
#     step = 99991
#   }
#   count := 0
#   for i := uint32(0); i < 0xff<<23; i += step {
#     f := math.Float32frombits(i)
#     if i&1 == 1 {
#       f = -f # negative
#     }
#     s := FormatFloat(float64(f), 'g', -1, 32)

#     parsed, err := ParseFloat(s, 32)
#     parsed32 := float32(parsed)
#     switch {
#     case err != nil:
#       t.Errorf("ParseFloat(%q, 32) gave error %s", s, err)
#     case float64(parsed32) != parsed:
#       t.Errorf("ParseFloat(%q, 32) = %v, not a float32 (nearest is %v)", s, parsed, parsed32)
#     case parsed32 != f:
#       t.Errorf("ParseFloat(%q, 32) = %b (expected %b)", s, parsed32, f)
#     }
#     count++
#   }
#   t.Logf("tested %d float32's", count)
# }

# func BenchmarkAtof64Decimal(b *testing.B) {
#   for i := 0; i < b.N; i++ {
#     ParseFloat("33909", 64)
#   }
# }

# func BenchmarkAtof64Float(b *testing.B) {
#   for i := 0; i < b.N; i++ {
#     ParseFloat("339.7784", 64)
#   }
# }

# func BenchmarkAtof64FloatExp(b *testing.B) {
#   for i := 0; i < b.N; i++ {
#     ParseFloat("-5.09e75", 64)
#   }
# }

# func BenchmarkAtof64Big(b *testing.B) {
#   for i := 0; i < b.N; i++ {
#     ParseFloat("123456789123456789123456789", 64)
#   }
# }

# func BenchmarkAtof64RandomBits(b *testing.B) {
#   for i := 0; i < b.N; i++ {
#     ParseFloat(benchmarksRandomBits[i%1024], 64)
#   }
# }

# func BenchmarkAtof64RandomFloats(b *testing.B) {
#   for i := 0; i < b.N; i++ {
#     ParseFloat(benchmarksRandomNormal[i%1024], 64)
#   }
# }

# func BenchmarkAtof32Decimal(b *testing.B) {
#   for i := 0; i < b.N; i++ {
#     ParseFloat("33909", 32)
#   }
# }

# func BenchmarkAtof32Float(b *testing.B) {
#   for i := 0; i < b.N; i++ {
#     ParseFloat("339.778", 32)
#   }
# }

# func BenchmarkAtof32FloatExp(b *testing.B) {
#   for i := 0; i < b.N; i++ {
#     ParseFloat("12.3456e32", 32)
#   }
# }

# var float32strings [4096]string

# func BenchmarkAtof32Random(b *testing.B) {
#   n := uint32(997)
#   for i := range float32strings {
#     n = (99991*n + 42) % (0xff << 23)
#     float32strings[i] = FormatFloat(float64(math.Float32frombits(n)), 'g', -1, 32)
#   }
#   b.ResetTimer()
#   for i := 0; i < b.N; i++ {
#     ParseFloat(float32strings[i%4096], 32)
#   }
# }
