# Copyright 2009 The Go Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# package strconv

import strutils

type SyntaxError = object of Exception

proc ParseBool*(str: string): bool =
  ## ParseBool returns the boolean value represented by the string.
  ## It accepts 1, t, T, TRUE, true, True, 0, f, F, FALSE, false, False.
  ## Any other value returns an error.
  
  case str
  of "1", "t", "T", "true", "TRUE", "True":
    return true
  of "0", "f", "F", "false", "FALSE", "False":
    return false
  else:
    raise newException(SyntaxError, "ParseBool can't parse $# as bool" % [str])


proc FormatBool*(b: bool): string =
  ## FormatBool returns "true" or "false" according to the value of b
  if b:
    return "true"
  return "false"


## AppendBool appends "true" or "false", according to the value of b,
## to dst and returns the extended buffer.
proc AppendBool*(dst: var string, b: bool): string =
  if b:
    add(dst, "true")
  else:
    add(dst, "false")
  return dst

