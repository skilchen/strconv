# TODO: move elsewhere?
type floatInfo* = object
  mantbits*: uint
  expbits*:  uint
  bias*:     int


const float32info* = floatInfo(mantbits: 23, expbits: 8, bias: -127)
const float64info* = floatInfo(mantbits: 52, expbits: 11, bias: -1023)

type decimalSlice* = object
  d*: array[0..2500, char]    
  nd*, dp*: int
  neg*: bool

type extFloat* = tuple
  ## An extFloat represents an extended floating-point number, with more
  ## precision than a float64. It does not try to save bits: the
  ## number represented by the structure is mant*(2^exp), with a negative
  ## sign if neg is true.
  mant: uint64
  exp:  int
  neg:  bool

proc `==`*(a, b: extFloat): bool =
  return a.mant == b.mant and
         a.exp  == b.exp and
         a.neg == b.neg

proc `$`*(x: extFloat): string =
  result = "Mant: " & $int(x.mant) & " Exp: " & $x.exp & " Neg: " & $x.neg