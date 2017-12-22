# Copyright 2009 The Go Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

#package strconv_test

import strutils
import unicode

import ../strconv
import quote
import utf8


#  Verify that our IsPrint agrees with unicode.IsPrint.
proc TestIsPrint() =
  var n = 0
  var r = rune(0)
  while r <= utf8.MaxRune:
    let x = IsPrint(r)
    if x:
      #echo("n: ", n, " x: ", $x, " r: ", $Rune(r))
      echo n
    inc(n)
    inc(r)

#TestIsPrint()

# Verify that our IsGraphic agrees with unicode.IsGraphic.
proc TestIsGraphic() =
  var n = 0
  var r = rune(0)
  while r <= MaxRune:
    if IsGraphic(r): # != unicode.IsGraphic(r) {
      #t.Errorf("IsGraphic(%U)=%t incorrect", r, IsGraphic(r))
      echo n
    inc(n)
    inc(r)

# TestIsGraphic()


type quoteTest = tuple
  instr:      string
  outstr:     string
  ascii:   string
  graphic: string


var quotetests: seq[quoteTest] = @[
  ("\a\b\f\r\n\t\v", r""""\a\b\f\r\n\t\v"""", r""""\a\b\f\r\n\t\v"""", r""""\a\b\f\r\n\t\v""""),
  ("\\", r""""\\"""", r""""\\"""", r""""\\""""),
  ("abc\xffdef", r""""abc\xffdef"""", r""""abc\xffdef"""", r""""abc\xffdef""""),
  ("\u263a", r""""☺"""", r""""\u263a"""", r""""☺""""),
#  ("\U0010ffff", r"\U0010ffff", r"\U0010ffff", r"\U0010ffff"), # Nim doesn't allow to enter this unicode code-point
  ("\xf4\x8f\xbf\xbf", r""""\U0010ffff"""", r""""\U0010ffff"""", r""""\U0010ffff""""),
  ("\x04", r""""\x04"""", r""""\x04"""", r""""\x04""""),
  # Some non-printable but graphic runes. Final column is double-quoted.
  ("!\u00a0!\u2000!\u3000!", r""""!\u00a0!\u2000!\u3000!"""", r""""!\u00a0!\u2000!\u3000!"""", "\"!\u00a0!\u2000!\u3000!\""),
]

proc TestQuote() =
  for tt in quotetests:
    var outstr = Quote(tt.instr)
    #echo outstr
    if outstr != tt.outstr:
      echo("Quote($#) = $#, want $#" % [repr(tt.instr), outstr, tt.outstr])

    var tmp = "abc"
    outstr = AppendQuote(tmp, tt.instr)
    if outstr != "abc" & tt.outstr:
      echo("AppendQuote($#, $#) = $#, want $#" % ["abc", tt.instr, outstr, "abc" & tt.outstr])

TestQuote()


proc TestQuoteToASCII() =
  for tt in quotetests:
    var outstr = QuoteToASCII(tt.instr)
    if outstr != tt.ascii:
      echo("QuoteToASCII($#) = $#, want $#" % [tt.instr, outstr, tt.ascii])

    var tmp = "abc"
    outstr = AppendQuoteToASCII(tmp, tt.instr)
    if outstr != "abc" & tt.ascii:
      echo("AppendQuoteToASCII($#, $#) = $#, want $#" % ["abc", tt.instr, outstr, "abc" & tt.ascii])

TestQuoteToASCII()


proc TestQuoteToGraphic() =
  for tt in quotetests:
    var outstr = QuoteToGraphic(tt.instr)
    if outstr != tt.graphic:
      echo("QuoteToGraphic($#) = $#, want $#" % [tt.instr, outstr, tt.graphic])

    var tmp = "abc"
    outstr = AppendQuoteToGraphic(tmp, tt.instr)
    if outstr != "abc" & tt.graphic:
      echo("AppendQuoteToGraphic($#, $#) = $#, want $#" % ["abc", tt.instr, outstr, "abc" & tt.graphic])

TestQuoteToGraphic()


# func BenchmarkQuote(b *testing.B) {
#   for i := 0; i < b.N; i++ {
#     Quote("\a\b\f\r\n\t\v\a\b\f\r\n\t\v\a\b\f\r\n\t\v")
#   }
# }

# func BenchmarkQuoteRune(b *testing.B) {
#   for i := 0; i < b.N; i++ {
#     QuoteRune('\a')
#   }
# }

# var benchQuoteBuf []byte

# func BenchmarkAppendQuote(b *testing.B) {
#   for i := 0; i < b.N; i++ {
#     benchQuoteBuf = AppendQuote(benchQuoteBuf[:0], "\a\b\f\r\n\t\v\a\b\f\r\n\t\v\a\b\f\r\n\t\v")
#   }
# }

# var benchQuoteRuneBuf []byte

# func BenchmarkAppendQuoteRune(b *testing.B) {
#   for i := 0; i < b.N; i++ {
#     benchQuoteRuneBuf = AppendQuoteRune(benchQuoteRuneBuf[:0], '\a')
#   }
# }

type quoteRuneTest = tuple
  inr:     rune
  outstr:  string
  ascii:   string
  graphic: string

var quoterunetests: seq[quoteRuneTest] = @[
  (rune('a'), r"'a'", r"'a'", r"'a'"),
  (rune('\a'), r"'\a'", r"'\a'", r"'\a'"),
  (rune('\\'), r"'\\'", r"'\\'", r"'\\'"),
  (rune(0xFF), r"'ÿ'", r"'\u00ff'", r"'ÿ'"),
  (rune(0x263a), r"'☺'", r"'\u263a'", r"'☺'"),
  (rune(0xfffd), r"'�'", r"'\ufffd'", r"'�'"),
  (rune(0x0010ffff), r"'\U0010ffff'", r"'\U0010ffff'", r"'\U0010ffff'"),
  (rune(0x0010ffff + 1), r"'�'", r"'\ufffd'", r"'�'"),
  (rune(0x04), r"'\x04'", r"'\x04'", r"'\x04'"),

  # there are no unicode/rune literals in Nim
  #
  # Some differences between graphic and printable. Note the last column is double-quoted.
  # (rune(Rune('\u00a0')), r"'\u00a0'", r"'\u00a0'", "'\u00a0'"),
  # (rune('\u2000'), r"'\u2000'", r"'\u2000'", "'\u2000'"),
  # (rune('\u3000'), r"'\u3000'", r"'\u3000'", "'\u3000'"),
]

proc TestQuoteRune() =
  for tt in quoterunetests:
    var outstr = QuoteRune(tt.inr)
    if outstr != tt.outstr:
      echo("QuoteRune($#) = $#, want $#" % [toHex(tt.inr), outstr, tt.outstr])

    var tmp = "abc"
    outstr = AppendQuoteRune(tmp, tt.inr)
    if outstr != "abc" & tt.outstr:
      echo("AppendQuoteRune($#, $#) = $#, want $#" % ["abc", toHex(tt.inr), outstr, "abc" & tt.outstr])

TestQuoteRune()


proc TestQuoteRuneToASCII() =
  for tt in quoterunetests:
    var outstr = QuoteRuneToASCII(tt.inr)
    if outstr != tt.ascii:
      echo("QuoteRuneToASCII($#) = $#, want $#" % [toHex(tt.inr), outstr, tt.ascii])

    var tmp = "abc"
    outstr = AppendQuoteRuneToASCII(tmp, tt.inr)
    if outstr != "abc" & tt.ascii:
      echo("AppendQuoteRuneToASCII($#, $#) = $#, want $#", "abc" % [toHex(tt.inr), outstr, "abc" & tt.ascii])

TestQuoteRuneToASCII()


proc TestQuoteRuneToGraphic() =
  for tt in quoterunetests:
    var outstr = QuoteRuneToGraphic(tt.inr)
    if outstr != tt.graphic:
      echo("QuoteRuneToGraphic($#) = $#, want $#" % [toHex(tt.inr), outstr, tt.graphic])

    var tmp = "abc"
    outstr = AppendQuoteRuneToGraphic(tmp, tt.inr)
    if outstr != "abc" & tt.graphic:
      echo("AppendQuoteRuneToGraphic($#, $#) = $#, want $#" % ["abc", toHex(tt.inr), outstr, "abc" & tt.graphic])

TestQuoteRuneToGraphic()


type canBackquoteTest = tuple
  instr: string
  outb:  bool

var canbackquotetests: seq[canBackquoteTest] = @[
  ("`", false),
  ($char(0), false),
  ($char(1), false),
  ($char(2), false),
  ($char(3), false),
  ($char(4), false),
  ($char(5), false),
  ($char(6), false),
  ($char(7), false),
  ($char(8), false),
  ($char(9), true), # \t
  ($char(10), false),
  ($char(11), false),
  ($char(12), false),
  ($char(13), false),
  ($char(14), false),
  ($char(15), false),
  ($char(16), false),
  ($char(17), false),
  ($char(18), false),
  ($char(19), false),
  ($char(20), false),
  ($char(21), false),
  ($char(22), false),
  ($char(23), false),
  ($char(24), false),
  ($char(25), false),
  ($char(26), false),
  ($char(27), false),
  ($char(28), false),
  ($char(29), false),
  ($char(30), false),
  ($char(31), false),
  ($char(0x7F), false),
  (r"' !""#$%&'()*+,-./:;<=>?@[\]^_(|)~", true),
  (r"0123456789", true),
  (r"ABCDEFGHIJKLMNOPQRSTUVWXYZ", true),
  (r"abcdefghijklmnopqrstuvwxyz", true),
  (r"☺", true),
  ("\x80", false),
  ("a\xe0\xa0z", false),
  ("\ufeffabc", false),
  ("a\ufeffz", false),
]

proc TestCanBackquote() =
  for tt in canbackquotetests:
    var outb = CanBackquote(tt.instr)
    if outb != tt.outb:
      echo("CanBackquote($#) = $#, want $#" % [tt.instr, $outb, $tt.outb])

TestCanBackquote()

type unQuoteTest = tuple
  instr:  string
  outstr: string

var unquotetests: seq[unQuoteTest] = @[
  ("\"\"", ""),
  (r""""a"""", "a"),
  (r""""abc"""", "abc"),
  (r""""☺"""", "☺"),
  (r""""hello world"""", "hello world"),
  (r""""\xFF"""", "\xFF"),
  # Nim has no octal or unicode/rune literals
  # (r""""\377"""", "\o377"),
  # (r""""\u1234"""", "\u1234"),
  # (r""""\U00010111"""", "\U00010111"),
  # (r""""\U0001011111"""", "\U0001011111"),
  (r""""\a\b\f\n\r\t\v\\\""""", "\a\b\f\n\r\t\v\\\""),
  (r""""'"""", "'"),

  (r"'a'", "a"),
  (r"'☹'", "☹"),
  (r"'\a'", "\a"),
  (r"'\x10'", "\x10"),
  # (`'\377'`, "\377"),
  # (`'\u1234'`, "\u1234"),
  # (`'\U00010111'`, "\U00010111"),
  (r"'\t'", "\t"),
  (r"' '", " "),
  (r"'\''", "'"),
  (r"'""'", "\""),

  # Nim doesn't have this "`x`" syntax for raw literals inside string literals
  # so these tests are somewhat pointless
  ("``", r""),
  ("`a`", r"a"),
  ("`abc`", r"abc"),
  ("`☺`", r"☺"),
  ("`hello world`", r"hello world"),
  ("`\\xFF`", r"\xFF"),
  # ("`\\377`", `\377`), # Nim has no octal literals
  ("`\\`", r"\"),
  ("`\n`", "\n"),
  ("` `", r" "),
  ("` `", r" "),
  ("`a\rb`", r"ab"),
]

var misquoted: seq[string] = @[
  r"",
  "\"",
  "\"a",
  "\"'",
  "b\"",
  "\"",
#  r"\9", # Nim does allow his
#  r"\19",
  r"\129",
#  "'\'",
#  "'\9'",
#  "'\19'",
#  "'\129'", # Nim does allow this
  "'ab'",
  "\"\"\x1!\"",
#  `"\U12345678"`, # Nim has no unicode/rune literals
#  "\"\z\"", # the Nim compiler doesn't allow this
  "`",
  "`xxx",
  "`\"",
  "\"'1'",
  "'\\\"'",
  "\"\n\"",
  "\"\\n\n\"",
  "'\n'",
]

proc TestUnquote() =
  for tt in unquotetests:
    var (outstr, err) = Unquote(tt.instr)
    if err != nil: # or outstr != tt.outstr:
      echo("a Unquote($#) = $#, $# want $#, nil" % [tt.instr, outstr, $err, tt.outstr])
    if outstr != tt.outstr:
      if err == nil:
        err = "nil"
      echo("b Unquote($#) = $#, $# want $#, nil" % [tt.instr, repr(outstr), $err, repr(tt.outstr)])

  # run the quote tests too, backward
  for tt in quotetests:
    var (instr, err) = Unquote(tt.outstr)
    if instr != tt.instr:
      if err == nil:
        err = "nil"
      echo("Unquote($#) = $#, $#, want $#, nil" % [tt.outstr, instr, err, tt.instr])


  for s in misquoted:
    var (outstr, err) = Unquote(s)
    if outstr != "" or err != ErrSyntax:
      if err == nil:
        err = "nil"
      echo("Unquote($#) = $#, $# want $#, $#" % [repr(s), outstr, err, "", ErrSyntax])



TestUnquote()


# func BenchmarkUnquoteEasy(b *testing.B) {
#   for i := 0; i < b.N; i++ {
#     Unquote(`"Give me a rock, paper and scissors and I will move the world."`)
#   }
# }

# func BenchmarkUnquoteHard(b *testing.B) {
#   for i := 0; i < b.N; i++ {
#     Unquote(`"\x47ive me a \x72ock, \x70aper and \x73cissors and \x49 will move the world."`)
#   }
# }
