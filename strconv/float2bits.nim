proc float32bits*(f: float32): uint32 =
  ## Float32bits returns the IEEE 754 binary representation of f.
  var fp = f
  result = cast[ptr uint32](addr fp)[]

proc float32frombits*(b: uint32): float32 =
  ## Float32frombits returns the floating point number corresponding
  ## to the IEEE 754 binary representation b.
  var fb = b
  result = cast[ptr float32](addr fb)[]

proc float64bits*(f: float64): uint64 =
  ## Float64bits returns the IEEE 754 binary representation of f.
  var fp = f
  result = cast[ptr uint64](addr fp)[]

proc float64frombits*(b: uint64): float64 =
  ## Float64frombits returns the floating point number corresponding
  ## the IEEE 754 binary representation b.
  var fb = b
  when nimvm:
    discard
  else:
    result = cast[ptr float64](addr fb)[]


when isMainModule:
  import strfmt
  import strutils

  echo "float32:"
  var a32:float32 = 0.1
  var b32 = float32bits(a32)
  var c32 = float32frombits(b32)
  echo $a32
  echo $b32.int64
  echo $b32.format("032b")
  echo "-".repeat(32)
  echo $c32

  echo ""
  echo "float64:"
  var a64:float64 = 0.01
  var b64 = float64bits(a64)
  var c64 = float64frombits(b64)
  echo $a64
  echo $b64.int64
  echo b64.format("064b")
  echo "-".repeat(64)
  echo $c64
