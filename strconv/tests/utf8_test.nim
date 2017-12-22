# Copyright 2009 The Go Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# package utf8_test
import strutils
import unicode
import encodings

import utf8


type Utf8Map = tuple
  r:   rune
  str: string


var utf8map: seq[Utf8Map] = @[
  (rune(0x0000), "\x00"),
  (rune(0x0001), "\x01"),
  (rune(0x007e), "\x7e"),
  (rune(0x007f), "\x7f"),
  (rune(0x0080), "\xc2\x80"),
  (rune(0x0081), "\xc2\x81"),
  (rune(0x00bf), "\xc2\xbf"),
  (rune(0x00c0), "\xc3\x80"),
  (rune(0x00c1), "\xc3\x81"),
  (rune(0x00c8), "\xc3\x88"),
  (rune(0x00d0), "\xc3\x90"),
  (rune(0x00e0), "\xc3\xa0"),
  (rune(0x00f0), "\xc3\xb0"),
  (rune(0x00f8), "\xc3\xb8"),
  (rune(0x00ff), "\xc3\xbf"),
  (rune(0x0100), "\xc4\x80"),
  (rune(0x07ff), "\xdf\xbf"),
  (rune(0x0400), "\xd0\x80"),
  (rune(0x0800), "\xe0\xa0\x80"),
  (rune(0x0801), "\xe0\xa0\x81"),
  (rune(0x1000), "\xe1\x80\x80"),
  (rune(0xd000), "\xed\x80\x80"),
  (rune(0xd7ff), "\xed\x9f\xbf"), # last code point before surrogate half.
  (rune(0xe000), "\xee\x80\x80"), # first code point after surrogate half.
  (rune(0xfffe), "\xef\xbf\xbe"),
  (rune(0xffff), "\xef\xbf\xbf"),
  (rune(0x10000), "\xf0\x90\x80\x80"),
  (rune(0x10001), "\xf0\x90\x80\x81"),
  (rune(0x40000), "\xf1\x80\x80\x80"),
  (rune(0x10fffe), "\xf4\x8f\xbf\xbe"),
  (rune(0x10ffff), "\xf4\x8f\xbf\xbf"),
  (rune(0xFFFD), "\xef\xbf\xbd"),
]

var surrogateMap: seq[Utf8Map] = @[
  (rune(0xd800), "\xed\xa0\x80"), # surrogate min decodes to (rune(RuneError), 1)
  (rune(0xdfff), "\xed\xbf\xbf"), # surrogate max decodes to (rune(RuneError), 1)
]

var testStrings: seq[string] = @[
  "",
  "abcd",
  "☺☻☹",
  "日a本b語ç日ð本Ê語þ日¥本¼語i日©",
  "日a本b語ç日ð本Ê語þ日¥本¼語i日©日a本b語ç日ð本Ê語þ日¥本¼語i日©日a本b語ç日ð本Ê語þ日¥本¼語i日©",
#  "\x80\x81\x80\x80",
  "यूनिकोड",
]

proc TestFullRune() =
  for _, m in utf8map:
    let b = m.str
    if not FullRune(b):
      echo("a FullRune($#) ($#) = false), want true" % [$b, $m.r])
    
    let s = m.str
    if not FullRuneInString(s):
      echo("b FullRuneInString($#) ($#) = false), want true" % [$s, $m.r])
    
    let b1 = b[0 .. len(b)-2]
    if FullRune(b1):
      echo("c FullRune($#) = true, want false" % [$b1])
    
    let s1 = b1
    if FullRuneInString(s1):
      echo("d FullRune($#) = true, want false" % [s1])
    
  for _, s  in @["\xc0", "\xc1"]:
    let b = s
    if not FullRune(b):
      echo("e FullRune($#) = false, want true" % [s])
    
    if not FullRuneInString(s):
      echo("f FullRuneInString($#) = false, want true" % [s])
    

TestFullRune()

proc TestEncodeRune() =
  for _, m in utf8map:
    let b = m.str
    var buf = " ".repeat(10)
    let n = EncodeRune(buf, m.r)
    let b1 = buf[0..n-1]
    if b != b1:
      echo("EncodeRune($#) = $# want $#" % [$m.r, $b1, $b])
    
  
TestEncodeRune()

proc TestDecodeRune() =
  for _, m in utf8map:
    var b = m.str
    var r: rune
    var size: int
    (r, size) = DecodeRune(b)
    if r != m.r or size != len(b):
      # echo toBin(int32(r), 32)
      # echo toBin(int32(m.r), 32)
      echo("a DecodeRune($#) = $#, $# want $#, $#" % [b, toBin(int32(r), 32), $size, toBin(int32(m.r), 32), $len(b)])
    
    var s = m.str
    (r, size) = DecodeRuneInString(s)
    if r != m.r or size != len(b):
      echo("b DecodeRuneInString($#) = $#, $# want $#, $#" % [s, toHex(r), $size, toHex(m.r), $len(b)])
    

    # there's an extra byte that bytes left behind - make sure trailing byte works
    (r, size) = DecodeRune(b[0..len(b)])
    if r != m.r or size != len(b):
      echo("DecodeRune($#) = $#, $# want $#, $#" % [b, toHex(r), $size, toHex(m.r), $len(b)])
    
    s = m.str & "\x00"
    (r, size) = DecodeRuneInString(s)
    if r != m.r and size != len(b):
      echo("DecodeRuneInString($#) = $#, $# want $#, $#" % [s, toHex(r), $size, toHex(m.r), $len(b)])
    

    # make sure missing bytes fail
    var wantsize = 1
    if wantsize >= len(b):
      wantsize = 0
    
    (r, size) = DecodeRune(b[0 .. len(b) - 2])
    if r != RuneError or size != wantsize:
      echo("DecodeRune($#) = $#, $# want $#, $#" % [b[0..len(b)-1], toHex(r), $size, toHex(RuneError), $wantsize])
    
    s = m.str[0 .. len(m.str) - 2]
    (r, size) = DecodeRuneInString(s)
    if r != RuneError or size != wantsize:
      echo("DecodeRune($#) = $#, $# want $#, $#" % [b[0..len(b)-1], toHex(r), $size, toHex(RuneError), $wantsize])

    # make sure bad sequences fail
    if len(b) == 1:
      b[0] = char(0x80)
    else:
      b[len(b)-1] = char(0x7F)


    (r, size) = DecodeRune(b)
    if r != RuneError or size != 1:
      echo("a DecodeRune($#) = $#, $# want $#, $#" % [b, toHex(r), $size, toHex(RuneError), $1])
    
    s = b
    (r, size) = DecodeRuneInString(s)
    if r != RuneError or size != 1:
      echo("b DecodeRune($#) = $#, $# want $#, $#" % [b, toHex(r), $size, toHex(RuneError), $1])

TestDecodeRune()

proc TestDecodeSurrogateRune() =
  for _, m in surrogateMap:
    var b = m.str
    var r: rune
    var size: int

    (r, size) = DecodeRune(b)
    if r != RuneError or size != 1:
      echo("DecodeRune($#) = $#, $# want $#, $#" % [b, toHex(r), $size, toHex(RuneError), $1])
    
    let s = m.str
    (r, size) = DecodeRuneInString(s)
    if r != RuneError or size != 1:
      echo("DecodeRune($#) = $#, $# want $#, $#" % [b, toHex(r), $size, toHex(RuneError), $1])

TestDecodeSurrogateRune()


proc testSequence(s: string) =
  type info = tuple
    index: int
    r:     rune
  
  var index = newSeq[info](len(s))

  var b = s
  var si = 0
  var j = 0
  var i = 0
  for c in s.runes():
    # echo "i: ", $i, " c: ", $c, " ", toHex(rune(c))

    var r = rune(c)
    if si != i:
      echo("a Sequence($#) mismatched index $#, want $#" % [s, $si, $i])
      return

    index[j] = (i, r)
    j.inc()
    var r1: rune
    var size1: int
    (r1, size1) = DecodeRune(b[i..^1])
    if r != r1:
      echo("b DecodeRune($#) = $#, want $#" % [s[i..^1], toHex(r1), toHex(r)])
      return
    
    var r2: rune
    var size2: int
    (r2, size2) = DecodeRuneInString(s[i..^1])
    if r != r2:
      echo("c DecodeRuneInString($#) = $#, want $#" % [s[i..^1], toHex(r2), toHex(r)])
      return
    
    if size1 != size2:
      echo("d DecodeRune/DecodeRuneInString($#) size mismatch $#/$#" % [s[i..^1], $size1, $size2])
      return
    
    i += runeLenAt(s, i)    
    # echo "i1: ", i

    si += size1

  
  j.dec()

  si = len(s)
  var r1, r2: rune
  var size1, size2: int
  while si > 0:
    (r1, size1) = DecodeLastRune(b[0..si-1])
    (r2, size2) = DecodeLastRuneInString(s[0..si-1])
    if size1 != size2:
      echo("e DecodeLastRune/DecodeLastRuneInString($#, $#) size mismatch $#/$#" % [s, $si, $size1, $size2])
      return
    
    if r1 != index[j].r:
      echo("f DecodeLastRune($#, $#) = $#, want $#" % [s, $si, toHex(r1), toHex(index[j].r)])
      return
    
    if r2 != index[j].r:
      echo("g DecodeLastRuneInString($#, $#) = $#, want $#" % [s, $si, toHex(r2), toHex(index[j].r)])
      return
    
    si -= size1
    if si != index[j].index:
      echo("h DecodeLastRune($#) index mismatch at $#, want $#" % [s, $si, $index[j].index])
      return
    
    j.dec()
  
  if si != 0:
    echo("i DecodeLastRune($#) finished at $#, not 0" % [s, $si])
  


# Check that DecodeRune and DecodeLastRune correspond to
# the equivalent range loop.
proc TestSequencing() =
  for _, ts in testStrings:
    for _, m in utf8map:
      for s in @[ts & m.str, m.str & ts, ts & m.str & ts]:
        testSequence(s)

TestSequencing()

# Check that a range loop and a []int conversion visit the same runes.
# Not really a test of this package, but the assumption is used here and
# it's good to verify
proc TestIntConversion() =
  for ts in testStrings:
    var runes = ts.toRunes()
    if RuneCountInString(ts) != len(runes):
      echo("$#: expected $# runes; got $#" % [ts, $len(runes), $RuneCountInString(ts)])
      break
    
    var i = 0
    for r in ts.runes():
      if r != runes[i]:
        echo("$#[$#]: expected $# ($#); got $# ($#)" % [ts, $i, $runes[i], $runes[i], $r, $r])
      i.inc()

TestIntConversion()

var invalidSequenceTests: seq[string] = @[
  "\xed\xa0\x80\x80", # surrogate min
  "\xed\xbf\xbf\x80", # surrogate max

  # xx
  "\x91\x80\x80\x80",

  # s1
  "\xC2\x7F\x80\x80",
  "\xC2\xC0\x80\x80",
  "\xDF\x7F\x80\x80",
  "\xDF\xC0\x80\x80",

  # s2
  "\xE0\x9F\xBF\x80",
  "\xE0\xA0\x7F\x80",
  "\xE0\xBF\xC0\x80",
  "\xE0\xC0\x80\x80",

  # s3
  "\xE1\x7F\xBF\x80",
  "\xE1\x80\x7F\x80",
  "\xE1\xBF\xC0\x80",
  "\xE1\xC0\x80\x80",

  # s4
  "\xED\x7F\xBF\x80",
  "\xED\x80\x7F\x80",
  "\xED\x9F\xC0\x80",
  "\xED\xA0\x80\x80",

  # s5
  "\xF0\x8F\xBF\xBF", # Nim produces an invalid Rune for this
  "\xF0\x90\x7F\xBF",
  "\xF0\x90\x80\x7F",
  "\xF0\xBF\xBF\xC0",
  "\xF0\xBF\xC0\x80",
  "\xF0\xC0\x80\x80",

  # s6
  "\xF1\x7F\xBF\xBF",
  "\xF1\x80\x7F\xBF",
  "\xF1\x80\x80\x7F",
  "\xF1\xBF\xBF\xC0",
  "\xF1\xBF\xC0\x80",
  "\xF1\xC0\x80\x80",

  # s7
  "\xF4\x7F\xBF\xBF",
  "\xF4\x80\x7F\xBF",
  "\xF4\x80\x80\x7F",
  "\xF4\x8F\xBF\xC0",
  "\xF4\x8F\xC0\x80",
  "\xF4\x90\x80\x80", # Nim produces an invalid Rune for this
]

proc runtimeDecodeRune(s: string): rune =
  # for r in s.runes():
  #   return rune(r)
  # return -1
  if validateUtf8(s) == -1:
    return rune(runeAt(s, 0))
  else:
    return RuneError    


proc TestDecodeInvalidSequence() =
  for s in invalidSequenceTests:
    let (r1, _) = DecodeRune(s)
    let want = RuneError
    if r1 != want:
      echo("DecodeRune($#) = $#, want $#" % [s, toHex(r1), toHex(want)])
      return
    
    let (r2, _) = DecodeRuneInString(s)
    if r2 != want:
      echo("DecodeRuneInString($#) = $#, want $#" % [s, toHex(r2), toHex(want)])
      return
    
    if r1 != r2:
      echo("DecodeRune($#) = $# mismatch with DecodeRuneInString($#) = $#" % [s, toHex(r1), s, toHex(r2)])
      return
    
    let r3 = runtimeDecodeRune(s)
    if r2 != r3:
      echo("DecodeRuneInString($#) = $# mismatch with runtime.decoderune($#) = $#" % [repr(s), toHex(r2), repr(s), toHex(r3)])
      #return

TestDecodeInvalidSequence()

# Check that negative runes encode as U+FFFD.
proc TestNegativeRune() =
  var errorbuf = " ".repeat(UTFMax)
  errorbuf = errorbuf[0..EncodeRune(errorbuf, RuneError)-1]
  var buf = " ".repeat(UTFMax)
  buf = buf[0..EncodeRune(buf, -1)-1]
  # echo "buf: ", repr(buf), " errorbuf: ", repr(errorbuf)
  if buf != errorbuf:
    echo("incorrect encoding [$#] for -1; expected [$#]" % [buf, errorbuf])

TestNegativeRune()

type RuneCountTest = tuple 
  instr: string
  outv: int

var runecounttests: seq[RuneCountTest] = @[
  ("abcd", 4),
  ("☺☻☹", 3),
  ("1,2,3,4", 7),
  ("\xe2\x00", 2),
  ("\xe2\x80", 2),
  ("a\xe2\x80", 3),
]

proc TestRuneCount() =
  for tt in runecounttests:
    var outv = RuneCountInString(tt.instr) 
    if outv != tt.outv:
      echo("RuneCountInString($#) = $#, want $#" % [tt.instr, $outv, $tt.outv])
    
    outv = RuneCount(tt.instr)
    if outv != tt.outv:
      echo("RuneCount($#) = $#, want $#" % [tt.instr, $outv, $tt.outv])
    
TestRuneCount()


type RuneLenTest = tuple
  r:    rune
  size: int

var runelentests: seq[RuneLenTest] = @[
  (rune(0), 1),
  (rune('e'), 1),
  (rune(toRunes("é")[0]), 2),
  (rune(toRunes("☺")[0]), 3),
  (rune(RuneError), 3),
  (rune(MaxRune), 4),
  (rune(0xD800), -1),
  (rune(0xDFFF), -1),
  (rune(MaxRune + 1), -1),
  (rune(-1), -1),
]

proc TestRuneLen() =
  for tt in runelentests:
    let size = RuneLen(tt.r)
    if size != tt.size:
      echo("RuneLen($#) = $#, want $#" % [toHex(tt.r), $size, $tt.size])

TestRuneLen()


type ValidTest = tuple
  instr: string
  outb: bool

var validTests: seq[ValidTest] = @[
  ("", true),
  ("a", true),
  ("abc", true),
  ("Ж", true),
  ("ЖЖ", true),
  ("брэд-ЛГТМ", true),
  ("☺☻☹", true),
  ("aa\xe2", false),
  ("\66\250", false),
  ("\66\250\67", false),
  ("a\uFFFDb", true),
  ("\xF4\x8F\xBF\xBF", true),      # U+10FFFF
  ("\xF4\x90\x80\x80", false),     # U+10FFFF+1; out of range
  ("\xF7\xBF\xBF\xBF", false),     # 0x1FFFFF; out of range
  ("\xFB\xBF\xBF\xBF\xBF", false), # 0x3FFFFFF; out of range
  ("\xc0\x80", false),             # U+0000 encoded in two bytes: incorrect
  ("\xed\xa0\x80", false),         # U+D800 high surrogate (sic)
  ("\xed\xbf\xbf", false),         # U+DFFF low surrogate (sic)
]

proc TestValid() =
  for tt in validTests:
    if Valid(tt.instr) != tt.outb:
      echo("Valid($#) = $#; want $#" % [tt.instr, $`not`(tt.outb), $tt.outb])
    
    if ValidString(tt.instr) != tt.outb:
      echo("ValidString($#) = $#; want $#" % [tt.instr, $`not`(tt.outb), $tt.outb])

TestValid()


type ValidRuneTest = tuple
  r:  rune
  ok: bool

var validrunetests: seq[ValidRuneTest] = @[
  (rune(0), true),
  (rune('e'), true),
  (rune(toRunes("é")[0]), true),
  (rune(toRunes("☺")[0]), true),
  (rune(RuneError), true),
  (rune(MaxRune), true),
  (rune(0xD7FF), true),
  (rune(0xD800), false),
  (rune(0xDFFF), false),
  (rune(0xE000), true),
  (rune(MaxRune + 1), false),
  (rune(-1), false),
]

proc TestValidRune() =
  for tt in validrunetests:
    let ok = ValidRune(tt.r)
    if ok != tt.ok:
      echo("ValidRune($#) = $#, want $#" % [toHex(tt.r), $ok, $tt.ok])

TestValidRune()


# func BenchmarkRuneCountTenASCIIChars(b *testing.B) {
#   s := []byte("0123456789")
#   for i := 0; i < b.N; i++ {
#     RuneCount(s)
#   }
# }

# func BenchmarkRuneCountTenJapaneseChars(b *testing.B) {
#   s := []byte("日本語日本語日本語日")
#   for i := 0; i < b.N; i++ {
#     RuneCount(s)
#   }
# }

# func BenchmarkRuneCountInStringTenASCIIChars(b *testing.B) {
#   for i := 0; i < b.N; i++ {
#     RuneCountInString("0123456789")
#   }
# }

# func BenchmarkRuneCountInStringTenJapaneseChars(b *testing.B) {
#   for i := 0; i < b.N; i++ {
#     RuneCountInString("日本語日本語日本語日")
#   }
# }

# func BenchmarkValidTenASCIIChars(b *testing.B) {
#   s := []byte("0123456789")
#   for i := 0; i < b.N; i++ {
#     Valid(s)
#   }
# }

# func BenchmarkValidTenJapaneseChars(b *testing.B) {
#   s := []byte("日本語日本語日本語日")
#   for i := 0; i < b.N; i++ {
#     Valid(s)
#   }
# }

# func BenchmarkValidStringTenASCIIChars(b *testing.B) {
#   for i := 0; i < b.N; i++ {
#     ValidString("0123456789")
#   }
# }

# func BenchmarkValidStringTenJapaneseChars(b *testing.B) {
#   for i := 0; i < b.N; i++ {
#     ValidString("日本語日本語日本語日")
#   }
# }

# func BenchmarkEncodeASCIIRune(b *testing.B) {
#   buf := make([]byte, UTFMax)
#   for i := 0; i < b.N; i++ {
#     EncodeRune(buf, 'a')
#   }
# }

# func BenchmarkEncodeJapaneseRune(b *testing.B) {
#   buf := make([]byte, UTFMax)
#   for i := 0; i < b.N; i++ {
#     EncodeRune(buf, '本')
#   }
# }

# func BenchmarkDecodeASCIIRune(b *testing.B) {
#   a := []byte{'a'}
#   for i := 0; i < b.N; i++ {
#     DecodeRune(a)
#   }
# }

# func BenchmarkDecodeJapaneseRune(b *testing.B) {
#   nihon := []byte("本")
#   for i := 0; i < b.N; i++ {
#     DecodeRune(nihon)
#   }
# }

# func BenchmarkFullASCIIRune(b *testing.B) {
#   a := []byte{'a'}
#   for i := 0; i < b.N; i++ {
#     FullRune(a)
#   }
# }

# func BenchmarkFullJapaneseRune(b *testing.B) {
#   nihon := []byte("本")
#   for i := 0; i < b.N; i++ {
#     FullRune(nihon)
#   }
# }