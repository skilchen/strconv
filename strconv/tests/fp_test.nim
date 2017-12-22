# Copyright 2009 The Go Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# package strconv_test


import strutils
import os

import ../strconv

proc pow2(i: int): float64 =
  if i < 0:
    return 1.0 / pow2(-i)
  elif i == 0:
    return 1.0
  elif i == 1:
    return 2.0
  else:
   return pow2(i div 2) * pow2(i - i div 2)

proc handleFormatStr(fmtstr: string): tuple[fmtc: char, prec: int] =
  if fmtstr == "%b":
    return ('b', 0)
  elif fmtstr[0] == '%':
    let fmtc = fmtstr[high(fmtstr)]
    let precstr = fmtstr[2..(high(fmtstr)-1)]
    let prec = parseInt(precstr)
    return (fmtc, prec)
  else:
    raise newException(ValueError, "unknown format string: " & fmtstr)

proc myatof64(s: string): tuple[f: float64, ok: bool] =
  ## Wrapper around strconv.ParseFloat(x, 64).  Handles dddddp+ddd (binary exponent)
  ## itself, passes the rest on to strconv.ParseFloat.

  var a = split(s, 'p', 2)
  if len(a) == 2:
    var n: int64
    try:
      n = strconv.ParseInt(a[0], 10, 64)
    except:
      return (0.0, false)

    var e: int
    try:
      e = strconv.Atoi(a[1])
    except:
      echo("bad e ", a[1])
      return (0.0, false)

    var v = float64(n)
    # We expect that v*pow2(e) fits in a float64,
    # but pow2(e) by itself may not. Be careful.
    if e <= -1000:
      v *= pow2(-1000)
      e += 1000
      while e < 0:
        v /= 2
        e.inc()

      return (v, true)

    if e >= 1000:
      v *= pow2(1000)
      e -= 1000
      while e > 0:
        v *= 2
        e.dec()

      return (v, true)

    return (v * pow2(e), true)

  var fl: float64
  try:
    fl = strconv.ParseFloat(s, 64)
  except:
    return (0.0, false)

  return (fl, true)


proc myatof32(s: string): tuple[f: float32, ok: bool] =
  ## Wrapper around strconv.ParseFloat(x, 32).  Handles dddddp+ddd (binary exponent)
  ## itself, passes the rest on to strconv.ParseFloat.

  var a = split(s, 'p', 2)
  if len(a) == 2:
    var n: int64
    try:
      n = strconv.Atoi(a[0])
    except:
      echo("bad n ", $a[0])
      return (0.float32, false)

    var e: int
    try:
      e = strconv.Atoi(a[1])
    except:
      echo("bad p ", $a[1])
      return (0.float32, false)

    return (float32(float64(n) * pow2(e)), true)

  var f64: float64
  var fl: float32
  try:
    f64 = strconv.ParseFloat(s, 32)
    fl = float32(f64)
  except:
    return (0.float32, false)

  return (fl, true)


proc TestFp() =
  var f = open("testdata/testfp.txt")
  if f.isNil:
    raise newException(OSError, "testfp: open testdata/testfp.txt failed: " & getCurrentException().msg)

  defer: f.close()
  var lineno = 0

  for line in lines(f):
    inc(lineno)

    if len($line) == 0 or line[0] == '#':
      continue

    let a = split(line, " ")
    if len(a) != 4:
      stderr.write("testdata/testfp.txt: " & $lineno & ": wrong field count\n")
      continue

    var s: string
    var v: float64
    var v1: float32
    var ok: bool

    let (fmtc, prec) = handleFormatStr(a[1])
    # echo "fmtc: $#, prec: $#" % [$fmtc, $prec]

    case a[0]
    of "float64":
      (v, ok) = myatof64(a[2])
      if not ok:
        stderr.write("testdata/testfp.txt: " & $lineno & ": cannot atof64 " & a[2] & "\n")
        continue

      # s = fmt.Sprintf(a[1], v)
      s = FormatFloat(v, fmtc, prec, 64)

    of "float32":
      (v1, ok) = myatof32(a[2])
      if not ok:
        stderr.write("testdata/testfp.txt: " & $lineno & ": cannot atof32 " & a[2] & "\n")
        continue

      # s = fmt.Sprintf(a[1], v1)
      v = float64(v1)
      s = FormatFloat(v, fmtc, prec, 32)

    echo "v: $# g: $# s: $#, a[3]: $#" % [formatFloat(v, ffScientific, precision=16), FormatFloat(v, 'e', 16, 64), s, a[3]]
    if s != a[3]:
      stderr.write("testdata/testfp.txt: " & $lineno & ": " & a[0] & " " & a[1] & " " & a[2] & " (" & $v & ") " &
        "want " & a[3] & " got " & s & "\n")

  # if s.Err() != nil {
  #   t.Fatal("testfp: read testdata/testfp.txt: ", s.Err())
  # }

TestFp()
