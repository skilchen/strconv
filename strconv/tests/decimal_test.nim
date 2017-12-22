## Copyright 2009 The Go Authors. All rights reserved.
## Use of this source code is governed by a BSD-style
## license that can be found in the LICENSE file.


import decimal
import strutils


echo "testing decimal"


type shiftTest* = tuple
  i:     uint64
  shift: int
  output:   string


var shifttests*: seq[shiftTest]
shifttests = @[
  (0.uint64, -100, "0"),
  (0.uint64, 100, "0"),
  (1.uint64, 100, "1267650600228229401496703205376"),
  (1.uint64, -100,
    "0.00000000000000000000000000000078886090522101180541" &
      "17285652827862296732064351090230047702789306640625",
  ),
  (12345678.uint64, 8, "3160493568"),
  (12345678.uint64, -8, "48225.3046875"),
  (195312.uint64, 9, "99999744"),
  (1953125.uint64, 9, "1000000000")
]

#proc TestDecimalShift(t *testing.T) {
proc TestDecimalShift() =
  for i in (0..high(shifttests)):
    var test = shifttests[i]
    var d = NewDecimal(test.i)
    d.Shift(test.shift)
    var s = $d
    # echo repr(d)
    if $s != $test.output:
      echo $s
      echo $test.output
      echo "so: ", len(s)
      echo "to: ", len(test.output)
      stderr.write("Decimal $# << $# = $#, want $#\n" % 
        [$test.i, $test.shift, $s, $test.output])
    

type roundTest = tuple
  i:               uint64
  nd:              int
  down, round, up: string
  tint:             uint64


var roundtests: seq[roundTest]
roundtests = @[
  (0.uint64, 4, "0", "0", "0", 0.uint64),
  (12344999.uint64, 4, "12340000", "12340000", "12350000", 12340000.uint64),
  (12345000.uint64, 4, "12340000", "12340000", "12350000", 12340000.uint64),
  (12345001.uint64, 4, "12340000", "12350000", "12350000", 12350000.uint64),
  (23454999.uint64, 4, "23450000", "23450000", "23460000", 23450000.uint64),
  (23455000.uint64, 4, "23450000", "23460000", "23460000", 23460000.uint64),
  (23455001.uint64, 4, "23450000", "23460000", "23460000", 23460000.uint64),
  (99994999.uint64, 4, "99990000", "99990000", "100000000", 99990000.uint64),
  (99995000.uint64, 4, "99990000", "100000000", "100000000", 100000000.uint64),
  (99999999.uint64, 4, "99990000", "100000000", "100000000", 100000000.uint64),
  (12994999.uint64, 4, "12990000", "12990000", "13000000", 12990000.uint64),
  (12995000.uint64, 4, "12990000", "13000000", "13000000", 13000000.uint64),
  (12999999.uint64, 4, "12990000", "13000000", "13000000", 13000000.uint64),
]

proc TestDecimalRound() =
  for i in 0..high(roundtests):
    var test = roundtests[i]
    var d = NewDecimal(test.i)
    d.RoundDown(test.nd)
    var s = $d
    if s != test.down:
      stderr.write("Decimal $# RoundDown $# = $#, want $#\n" %
        [$test.i, $test.nd, $s, $test.down])
    
    d = NewDecimal(test.i)
    d.Round(test.nd)
    s = $d
    if s != test.round:
      stderr.write("Decimal $# Round $# = $#, want $#\n" %
        [$test.i, $test.nd, $s, $test.down])
    
    d = NewDecimal(test.i)
    d.RoundUp(test.nd)
    s = $d
    if s != test.up:
      stderr.write("Decimal $# RoundUp $# = $#, want $#\n" %
        [$test.i, $test.nd, $s, $test.up])
    
  
type roundIntTest = tuple
  i:     uint64
  shift: int
  tint:   uint64


var roundinttests: seq[roundIntTest]
roundinttests = @[
  (0.uint64, 100, 0.uint64),
  (512.uint64, -8, 2.uint64),
  (513.uint64, -8, 2.uint64),
  (640.uint64, -8, 2.uint64),
  (641.uint64, -8, 3.uint64),
  (384.uint64, -8, 2.uint64),
  (385.uint64, -8, 2.uint64),
  (383.uint64, -8, 1.uint64),
  (1.uint64, 100, cast[uint64](-1)),
  (1000.uint64, 0, 1000.uint64),
]

proc TestDecimalRoundedInteger() =
  for i in 0..high(roundinttests):
    var test = roundinttests[i]
    var d = NewDecimal(test.i)
    d.Shift(test.shift)
    var tint = d.RoundedInteger()
    if tint != test.tint:
      stderr.write("Decimal $# >> $# RoundedInteger = $#, want $#\n" %
        [$test.i, $test.shift, $tint, $test.tint])


echo "TestDecimalShift()"    
TestDecimalShift()

echo "TestDecimalRound()"
TestDecimalRound()

echo "TestDecimalRoundedInteger()"
TestDecimalRoundedInteger()
