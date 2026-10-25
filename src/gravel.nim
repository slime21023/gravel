## Go-inspired formatted output for Nim 2.x.
##
## print/println/printf, sprint/sprintln/sprintf, fprint/fprintln/fprintf
## for File and Stream targets, and flush for File.
## Supported directives: %v, %s, %d, %t, %f, %x, %X, %q, %e, %g, %%.
## Format errors raise FormatError (a ValueError subtype).
## I/O errors propagate as exceptions.

import std/[streams, strutils]

type
  FormatKind = enum
    fkString, fkInteger, fkFloat, fkBoolean, fkOther

  FormatErrorKind* = enum
    fekIncompleteDirective, fekInvalidPrecision, fekPrecisionNotAllowed,
    fekUnsupportedVerb, fekMissingArgument, fekTypeMismatch, fekExtraArguments

  FormatError* = object of ValueError
    kind*: FormatErrorKind
    position*: int
    verb*: char
    argIndex*: int

  FormatArg* = object
    ## Internal formatted argument (public only for varargs conversion).
    kind: FormatKind
    text: string
    floatValue: float
    negative: bool
    magnitude: uint64

const supportedVerbs = {'v', 's', 'd', 't', 'f', 'x', 'X', 'q', 'e', 'g'}

func formatError(kind: FormatErrorKind; msg: string; position: int;
                 verb = '\0'; argIndex = -1): ref FormatError =
  result = newException(FormatError, msg)
  result.kind = kind
  result.position = position
  result.verb = verb
  result.argIndex = argIndex

func actualType(kind: FormatKind): string =
  case kind
  of fkString: "string"
  of fkInteger: "integer"
  of fkFloat: "float"
  of fkBoolean: "bool"
  of fkOther: "other value"

func typeError(arg: FormatArg; verb: char; expected: string;
               position, argIndex: int): ref FormatError =
  formatError(fekTypeMismatch,
              "%" & $verb & " at byte " & $position & " requires " & expected &
              ", got " & actualType(arg.kind) & " (argument " & $(argIndex +
                  1) & ")",
              position, verb, argIndex)

func toFormatArg*[T](value: T): FormatArg =
  ## Convert a Nim value into an argument while preserving its basic type.
  ## Custom `$` implementations must be pure to participate.
  when T is string:
    result = FormatArg(kind: fkString, text: value)
  elif T is cstring:
    result = FormatArg(kind: fkString, text: $value)
  elif T is bool:
    result = FormatArg(kind: fkBoolean, text: $value)
  elif T is SomeInteger:
    when T is SomeSignedInt:
      let negative = value < 0
      result = FormatArg(kind: fkInteger, text: $value, negative: negative,
                         magnitude: (if negative: uint64(-(int64(value) + 1)) + 1
        else: uint64(value)))
    else:
      result = FormatArg(kind: fkInteger, text: $value, magnitude: uint64(value))
  elif T is SomeFloat:
    result = FormatArg(kind: fkFloat, text: $value,
                       floatValue: float(value))
  else:
    result = FormatArg(kind: fkOther, text: $value)

func renderDefault(args: openArray[FormatArg]; alwaysSpace,
    newline: bool): string =
  ## Preserve Go's unusual Print spacing rule.
  for i, arg in args:
    if i > 0 and (alwaysSpace or
                  (args[i - 1].kind != fkString and arg.kind != fkString)):
      result.add ' '
    result.add arg.text
  if newline:
    result.add '\n'

func trimFraction(s: string; stripZeros: bool): string =
  let exponent = s.find('e')
  let stop = if exponent < 0: s.len else: exponent
  var finish = stop
  var hasDot = false
  for i in 0..<stop:
    if s[i] == '.':
      hasDot = true
      break
  if hasDot:
    if stripZeros:
      while finish > 0 and s[finish - 1] == '0':
        dec finish
    if finish > 0 and s[finish - 1] == '.':
      dec finish
  result = s[0..<finish]
  if exponent >= 0:
    result.add s[exponent..^1]

func hexDigits(n: uint64; upper: bool): string =
  let digits = if upper: "0123456789ABCDEF" else: "0123456789abcdef"
  if n == 0:
    return "0"
  var remaining = n
  while remaining != 0:
    result.add digits[int(remaining and 0xF'u64)]
    remaining = remaining shr 4
  for i in 0..<result.len div 2:
    swap(result[i], result[result.high - i])

func quoteString(s: string): string =
  const hex = "0123456789abcdef"
  result.add '"'
  for ch in s:
    case ch
    of '"': result.add "\\\""
    of '\\': result.add "\\\\"
    of '\n': result.add "\\n"
    of '\r': result.add "\\r"
    of '\t': result.add "\\t"
    else:
      let code = ord(ch)
      if code < 0x20 or code == 0x7F:
        result.add "\\x"
        result.add hex[code shr 4]
        result.add hex[code and 0xF]
      else:
        result.add ch
  result.add '"'

func renderVerb(arg: FormatArg; verb: char; precision, position,
    argIndex: int): string =
  case verb
  of 'v':
    result = arg.text
  of 's':
    if arg.kind != fkString:
      raise typeError(arg, verb, "a string", position, argIndex)
    result = arg.text
  of 'q':
    if arg.kind != fkString:
      raise typeError(arg, verb, "a string", position, argIndex)
    result = quoteString(arg.text)
  of 'd':
    if arg.kind != fkInteger:
      raise typeError(arg, verb, "an integer", position, argIndex)
    result = arg.text
  of 'x', 'X':
    if arg.kind != fkInteger:
      raise typeError(arg, verb, "an integer", position, argIndex)
    result = (if arg.negative: "-" else: "") &
             hexDigits(arg.magnitude, upper = verb == 'X')
  of 't':
    if arg.kind != fkBoolean:
      raise typeError(arg, verb, "a bool", position, argIndex)
    result = arg.text
  of 'f':
    if arg.kind != fkFloat:
      raise typeError(arg, verb, "a float", position, argIndex)
    let digits = if precision >= 0: precision else: 6
    result = trimFraction(formatFloat(arg.floatValue, ffDecimal,
                                      range[-1..32](digits)), false)
  of 'e':
    if arg.kind != fkFloat:
      raise typeError(arg, verb, "a float", position, argIndex)
    let digits = if precision >= 0: precision else: 6
    result = trimFraction(formatFloat(arg.floatValue, ffScientific,
                                      range[-1..32](digits)), false)
  of 'g':
    if arg.kind != fkFloat:
      raise typeError(arg, verb, "a float", position, argIndex)
    result = trimFraction(formatFloat(arg.floatValue, ffDefault,
                                      range[-1..32](precision)), true)
  else:
    raise formatError(fekUnsupportedVerb,
                      "unsupported format verb %" & $verb & " at byte " &
                      $position,
                      position, verb)

func renderFormat(pattern: string; args: openArray[FormatArg]): string =
  var pos = 0
  var argIndex = 0
  while pos < pattern.len:
    if pattern[pos] != '%':
      result.add pattern[pos]
      inc pos
      continue

    let start = pos
    inc pos
    if pos >= pattern.len:
      raise formatError(fekIncompleteDirective,
                        "incomplete format directive at byte " & $start, start)
    if pattern[pos] == '%':
      result.add '%'
      inc pos
      continue

    var precision = -1
    if pattern[pos] == '.':
      inc pos
      if pos >= pattern.len or pattern[pos] notin {'0'..'9'}:
        raise formatError(fekInvalidPrecision,
                          "expected decimal precision after '%.' at byte " &
                          $start,
                          start)
      precision = 0
      while pos < pattern.len and pattern[pos] in {'0'..'9'}:
        precision = precision * 10 + ord(pattern[pos]) - ord('0')
        if precision > 32:
          raise formatError(fekInvalidPrecision,
                            "precision must be 0..32 at byte " & $start, start)
        inc pos

    if pos >= pattern.len:
      raise formatError(fekIncompleteDirective,
                        "incomplete format directive at byte " & $start, start)
    let verb = pattern[pos]
    inc pos
    if verb notin supportedVerbs:
      raise formatError(fekUnsupportedVerb,
                        "unsupported format verb %" & $verb & " at byte " &
                        $start,
                        start, verb)
    if precision >= 0 and verb notin {'f', 'e', 'g'}:
      raise formatError(fekPrecisionNotAllowed,
                        "precision is not allowed for %" & $verb & " at byte " &
                        $start,
                        start, verb)
    if argIndex >= args.len:
      raise formatError(fekMissingArgument,
                        "missing argument " & $(argIndex + 1) & " for %" &
                            $verb &
                        " at byte " & $start, start, verb, argIndex)
    result.add renderVerb(args[argIndex], verb, precision, start, argIndex)
    inc argIndex

  if argIndex != args.len:
    raise formatError(fekExtraArguments,
                      "too many arguments: " & $args.len & " given, " &
                      $argIndex & " used",
                      -1, argIndex = argIndex)

func sprint*(args: varargs[FormatArg, toFormatArg]): string =
  ## Go fmt.Sprint: no newline, space only between adjacent non-strings.
  renderDefault(args, alwaysSpace = false, newline = false)

func sprintln*(args: varargs[FormatArg, toFormatArg]): string =
  ## Go fmt.Sprintln: spaces between all values, trailing newline.
  renderDefault(args, alwaysSpace = true, newline = true)

func sprintf*(pattern: string; args: varargs[FormatArg, toFormatArg]): string =
  ## Strict, small runtime format parser. Not a full Go fmt implementation.
  renderFormat(pattern, args)

proc c_ferror(f: File): cint {.importc: "ferror", header: "<stdio.h>".}
proc c_fflush(f: File): cint {.importc: "fflush", header: "<stdio.h>".}

proc writeText(target: File; text: string): int =
  ## Returns the byte count only after the C stream accepted the full write.
  target.write(text)
  if c_ferror(target) != 0:
    raise newException(IOError, "cannot write to file")
  result = text.len

proc writeText(target: Stream; text: string): int =
  target.write(text)
  result = text.len

proc fprint*(target: File; args: varargs[FormatArg,
    toFormatArg]): int {.discardable.} =
  writeText(target, renderDefault(args, alwaysSpace = false, newline = false))

proc fprint*(target: Stream; args: varargs[FormatArg,
    toFormatArg]): int {.discardable.} =
  writeText(target, renderDefault(args, alwaysSpace = false, newline = false))

proc fprintln*(target: File; args: varargs[FormatArg,
    toFormatArg]): int {.discardable.} =
  writeText(target, renderDefault(args, alwaysSpace = true, newline = true))

proc fprintln*(target: Stream; args: varargs[FormatArg,
    toFormatArg]): int {.discardable.} =
  writeText(target, renderDefault(args, alwaysSpace = true, newline = true))

proc fprintf*(target: File; pattern: string;
              args: varargs[FormatArg, toFormatArg]): int {.discardable.} =
  writeText(target, renderFormat(pattern, args))

proc fprintf*(target: Stream; pattern: string;
              args: varargs[FormatArg, toFormatArg]): int {.discardable.} =
  writeText(target, renderFormat(pattern, args))

proc print*(args: varargs[FormatArg, toFormatArg]): int {.discardable.} =
  writeText(stdout, renderDefault(args, alwaysSpace = false, newline = false))

proc println*(args: varargs[FormatArg, toFormatArg]): int {.discardable.} =
  writeText(stdout, renderDefault(args, alwaysSpace = true, newline = true))

proc printf*(pattern: string;
             args: varargs[FormatArg, toFormatArg]): int {.discardable.} =
  writeText(stdout, renderFormat(pattern, args))

proc eprint*(args: varargs[FormatArg, toFormatArg]): int {.discardable.} =
  writeText(stderr, renderDefault(args, alwaysSpace = false, newline = false))

proc eprintln*(args: varargs[FormatArg, toFormatArg]): int {.discardable.} =
  writeText(stderr, renderDefault(args, alwaysSpace = true, newline = true))

proc eprintf*(pattern: string;
              args: varargs[FormatArg, toFormatArg]): int {.discardable.} =
  writeText(stderr, renderFormat(pattern, args))

proc flush*(target: File) =
  ## Flush one output stream, for instance flush(stdout).
  if c_fflush(target) != 0:
    raise newException(IOError, "cannot flush file")
