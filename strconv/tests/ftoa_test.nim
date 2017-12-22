# Copyright 2009 The Go Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.


import
  math,
  random,
  ftoa,
  atof,
  strutils,
  float2bits,
  strfmt


type ftoaTest = tuple
  f:    float64
  fmt:  char
  prec: int
  s:    string


proc fdiv(a, b: float64): float64 = return a / b 

var below1e23:float64 = ParseFloat("99999999999999974834176", 64)
var above1e23:float64 = ParseFloat("100000000000000008388608", 64)


var ftoatests: seq[ftoaTest] = @[
  (1.0, 'e', 5, "1.00000e+00"),
  (1.0, 'f', 5, "1.00000"),
  (1.0, 'g', 5, "1"),
  (1.0, 'g', -1, "1"),
  (20.0, 'g', -1, "20"),
  (1234567.8, 'g', -1, "1.2345678e+06"),
  (200000.0, 'g', -1, "200000"),
  (2000000.0, 'g', -1, "2e+06"),

  # g conversion and zero suppression
  (400.0, 'g', 2, "4e+02"),
  (40.0, 'g', 2, "40"),
  (4.0, 'g', 2, "4"),
  (0.4, 'g', 2, "0.4"),
  (0.04, 'g', 2, "0.04"),
  (0.004, 'g', 2, "0.004"),
  (0.0004, 'g', 2, "0.0004"),
  (0.00004, 'g', 2, "4e-05"),
  (0.000004, 'g', 2, "4e-06"),

  (0.0, 'e', 5, "0.00000e+00"),
  (0.0, 'f', 5, "0.00000"),
  (0.0, 'g', 5, "0"),
  (0.0, 'g', -1, "0"),

  (-1.0, 'e', 5, "-1.00000e+00"),
  (-1.0, 'f', 5, "-1.00000"),
  (-1.0, 'g', 5, "-1"),
  (-1.0, 'g', -1, "-1"),

  (12.0, 'e', 5, "1.20000e+01"),
  (12.0, 'f', 5, "12.00000"),
  (12.0, 'g', 5, "12"),
  (12.0, 'g', -1, "12"),

  (123456700.0, 'e', 5, "1.23457e+08"),
  (123456700.0, 'f', 5, "123456700.00000"),
  (123456700.0, 'g', 5, "1.2346e+08"),
  (123456700.0, 'g', -1, "1.234567e+08"),

  (1.2345e6, 'e', 5, "1.23450e+06"),
  (1.2345e6, 'f', 5, "1234500.00000"),
  (1.2345e6, 'g', 5, "1.2345e+06"),

  (1e23, 'e', 17, "9.99999999999999916e+22"),
  (1e23, 'f', 17, "99999999999999991611392.00000000000000000"),
  (1e23, 'g', 17, "9.9999999999999992e+22"),

  (1e23, 'e', -1, "1e+23"),
  (1e23, 'f', -1, "100000000000000000000000"),
  (1e23, 'g', -1, "1e+23"),

  (below1e23, 'e', 17, "9.99999999999999748e+22"),
  (below1e23, 'f', 17, "99999999999999974834176.00000000000000000"),
  (below1e23, 'g', 17, "9.9999999999999975e+22"),

  (below1e23, 'e', -1, "9.999999999999997e+22"),
  (below1e23, 'f', -1, "99999999999999970000000"),
  (below1e23, 'g', -1, "9.999999999999997e+22"),

  (above1e23, 'e', 17, "1.00000000000000008e+23"),
  (above1e23, 'f', 17, "100000000000000008388608.00000000000000000"),
  (above1e23, 'g', 17, "1.0000000000000001e+23"),

  (above1e23, 'e', -1, "1.0000000000000001e+23"),
  (above1e23, 'f', -1, "100000000000000010000000"),
  (above1e23, 'g', -1, "1.0000000000000001e+23"),

  (fdiv(5e-304, 1e20), 'g', -1, "5e-324"),   # avoid constant arithmetic
  (fdiv(-5e-304, 1e20), 'g', -1, "-5e-324"), # avoid constant arithmetic

  (32.0, 'g', -1, "32"),
  (32.0, 'g', 0, "3e+01"),

  (100.0, 'x', -1, "%x"),

  (NaN, 'g', -1, "NaN"),
  (-NaN, 'g', -1, "NaN"),
  (Inf, 'g', -1, "+Inf"),
  (-Inf, 'g', -1, "-Inf"),

  (-1.0, 'b', -1, "-4503599627370496p-52"),

  # fixed bugs
  (0.9, 'f', 1, "0.9"),
  (0.09, 'f', 1, "0.1"),
  (0.0999, 'f', 1, "0.1"),
  (0.05, 'f', 1, "0.1"),
  (0.05, 'f', 0, "0"),
  (0.5, 'f', 1, "0.5"),
  (0.5, 'f', 0, "0"),
  (1.5, 'f', 0, "2"),

  # http://www.exploringbinary.com/java-hangs-when-converting-2-2250738585072012e-308/
  (2.2250738585072012e-308, 'g', -1, "2.2250738585072014e-308"),
  # http://www.exploringbinary.com/php-hangs-on-numeric-value-2-2250738585072011e-308/
  (2.2250738585072011e-308, 'g', -1, "2.225073858507201e-308"),

  # Issue 2625.
  (383260575764816448.0, 'f', 0, "383260575764816448"),
  (383260575764816448.0, 'g', -1, "3.8326057576481645e+17")
]


proc testFtoa() =
  for i in 0..high(ftoatests):
    var test = ftoatests[i]
    var s = FormatFloat(test.f, test.fmt, test.prec, 64)
    if s != test.s:
      echo("testN=64 $1 $2 $3 want $4 got $5" %
             [$test.f, $test.fmt, $test.prec, $test.s, $s])

    var txt = "abc"
    var x = AppendFloat(txt, test.f, test.fmt, test.prec, 64)
    if $x != "abc" & test.s:
      echo("AppendFloat testN=64 $1 $2 $3 want $4, got $5" % 
        [$test.f, $test.fmt, $test.prec, "abc" & test.s, $x])
    
    if float64(float32(test.f)) == test.f and test.fmt != 'b':
      s = FormatFloat(test.f, test.fmt, test.prec, 32)
      if s != test.s:
        echo("testN=32 $1 $2 $3 want $4, got $5" %
          [$test.f, $test.fmt, $test.prec, $test.s, s])
      
      txt = "abc"
      x = AppendFloat(txt, test.f, test.fmt, test.prec, 32)
      if $x != "abc" & test.s:
        debugEcho("AppendFloat testN=32 $1 $2 $3 want, $4 got $5" %
          [$test.f, $test.fmt, $test.prec, "abc" & $test.s, $x])


proc testFtoaRandom() =
  let N = int(1e4)
  randomize()
  echo("testing $1 random numbers with fast and slow FormatFloat" % [$N])
  for i in (0.. < N):
    let bits = uint64(random(high(int))) shl 32 or uint64(random(high(int)))
    var x = float64frombits(bits)
    
    discard SetOptimize(true)
    var shortFast = FormatFloat(x, 'g', 20, 64)
    
    discard SetOptimize(false)
    var shortSlow = FormatFloat(x, 'g', 20, 64)
    
    discard SetOptimize(true)
    if shortSlow != shortFast:
      echo("$# $# printed as $#, want $# \n(minimal precision)" % [$i, $x, $shortFast, $shortSlow])
    

    let prec = random(12) + 5
    shortFast = FormatFloat(x, 'e', prec, 64)
    
    discard SetOptimize(false)
    shortSlow = FormatFloat(x, 'e', prec, 64)
    
    discard SetOptimize(true)
    if shortSlow != shortFast:
      echo("$#: $# printed as $#, want $# \n(random precision)" % [$i, $x, $shortFast, $shortSlow])
    
  
type ftoaBench = tuple
  name:    string
  float:   float64
  fmt:     char
  prec:    int
  bitSize: int

const ftoaBenches: seq[ftoaBench] = @[
  ("Decimal", 33909.0, 'g', -1, 64),
  ("Float", 339.7784, 'g', -1, 64),
  ("Exp", -5.09e75, 'g', -1, 64),
  ("NegExp", -5.11e-95, 'g', -1, 64),

  ("Big", atof.ParseFloat("123456789123456789123456789", 64), 'g', -1, 64),
  ("BinaryExp", -1.0, 'b', -1, 64),

  ("32Integer", 33909.0, 'g', -1, 32),
  ("32ExactFraction", 3.375, 'g', -1, 32),
  ("32Point", 339.7784, 'g', -1, 32),
  ("32Exp", -5.09e25, 'g', -1, 32),
  ("32NegExp", -5.11e-25, 'g', -1, 32),

  ("64Fixed1", 123456.0, 'e', 3, 64),
  ("64Fixed2", 123.456, 'e', 3, 64),
  ("64Fixed3", 1.23456e+78, 'e', 3, 64),
  ("64Fixed4", 1.23456e-78, 'e', 3, 64),

  # Trigger slow path (see issue #15672).
  ("Slowpath64", 622666234635.3213e-320, 'e', -1, 64)
]

const repeatCount = 10

proc BenchmarkFormatFloat() =
  # var responses: seq[FlowVarBase] = @[]
  for c in ftoaBenches:
    echo align(c.name, 20), ": ", FormatFloat(c.float, c.fmt, c.prec, c.bitSize), " ", c.float.format("g")
  # echo len(responses)
  # echo "waiting... for the tasks to complete ..."
  # discard awaitAny(responses)

proc BenchmarkAppendFloat() {.gcsafe.} =

  for c in ftoaBenches:
      for i in 0..repeatCount:
        var dst = ""
        discard AppendFloat(dst, c.float, c.fmt, c.prec, c.bitSize)
        echo align(c.name, 20), " ", i, " ", dst, " x: ", c.float.format("g")

proc sillyTest() =
  # echo ftoaBenches[^1].name
  # var nmbr:float64 = ftoaBenches[high(ftoaBenches)][1]
  var nmbr = 0.0
  var incr = 1e-30 
  var i = 0
  discard SetOptimize(true)
  while true:
    inc(i)
    let a = FormatFloat(nmbr, 'f', 32, 64)
    let b = formatFloat(nmbr, ffDecimal, 32)
    if i mod 1e6.int == 0:
      echo i, " ", a, " ", b, " ", a == b
    nmbr += incr

testFtoa()

testFtoaRandom()

BenchmarkFormatFloat()
BenchmarkAppendFloat()

#sillyTest()
