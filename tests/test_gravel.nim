import std/[os, streams, tempfiles]
import gravel

template expectFormatError(body: untyped): ref FormatError =
  var caught: ref FormatError = nil
  try:
    discard body
  except FormatError as e:
    caught = e
  doAssert caught != nil
  caught

block defaultFormatting:
  doAssert sprint("A", "B", 123) == "AB123"
  doAssert sprint(1, 2, 3) == "1 2 3"
  doAssert sprint("x", 2, "y") == "x2y"
  doAssert sprintln("A", "B", 123) == "A B 123\n"
  doAssert sprintln() == "\n"
  doAssert sprint() == ""

block formattedOutput:
  doAssert sprintf("%s=%d", "answer", 42) == "answer=42"
  doAssert sprintf("%.2f%%", 82.456) == "82.46%"
  doAssert sprintf("%t %v", true, @[1, 2]) == "true @[1, 2]"
  doAssert sprintf("%%") == "%"
  doAssert sprintf("%.0f", 3.14) == "3"

block extendedFormatting:
  doAssert sprintf("%.0e", 3.14) == "3e+00"
  doAssert sprintf("%x %X %x %x", 255, 255, -255, 0) == "ff FF -ff 0"
  doAssert sprintf("%x", low(int64)) == "-8000000000000000"
  doAssert sprintf("%x", high(uint64)) == "ffffffffffffffff"
  doAssert sprintf("%q", "a\"b\\c\n\té\x01") == "\"a\\\"b\\\\c\\n\\té\\x01\""
  doAssert sprintf("%e", 255.0) == "2.550000e+02"
  doAssert sprintf("%.2e", 1234.5678) == "1.23e+03"
  doAssert sprintf("%g %g %g", 100000.0, 0.00001234, 1.0) ==
    "100000 1.234e-05 1"
  doAssert sprintf("%.3g %.3g", 2.5, 100000.0) == "2.5 1e+05"
  doAssert sprintf("%f", Inf) == "inf"

block contractEdges:
  doAssert sprintf("") == ""
  doAssert sprintf("%.32f", 1.0) == "1.00000000000000000000000000000000"
  doAssert sprintf("%x", low(int8)) == "-80"
  doAssert sprintf("%d", high(uint64)) == "18446744073709551615"
  doAssert sprintf("%q", "") == "\"\""
  doAssert sprintf("%q", "\x7f") == "\"\\x7f\""
  doAssert sprintf("%g", 0.0) == "0"
  doAssert sprintf("%.0g", 0.0001234) == "0.0001"
  doAssert sprintf("%v", (a: 1)) == "(a: 1)"
  let invalid = expectFormatError(sprintf("%.", 1))
  doAssert invalid.kind == fekInvalidPrecision
  doAssert invalid.position == 0
  let incomplete = expectFormatError(sprintf("%.2", 1))
  doAssert incomplete.kind == fekIncompleteDirective
  doAssert incomplete.position == 0
  let width = expectFormatError(sprintf("%5d", 1))
  doAssert width.kind == fekUnsupportedVerb
  doAssert width.verb == '5'

block structuredErrors:
  let incomplete = expectFormatError(sprintf("ab%", 1))
  doAssert incomplete.kind == fekIncompleteDirective
  doAssert incomplete.position == 2
  let precision = expectFormatError(sprintf("%.33f", 1.0))
  doAssert precision.kind == fekInvalidPrecision
  doAssert precision.position == 0
  let forbidden = expectFormatError(sprintf("x%.2d", 1))
  doAssert forbidden.kind == fekPrecisionNotAllowed
  doAssert forbidden.position == 1
  doAssert forbidden.verb == 'd'
  let unsupported = expectFormatError(sprintf("%z", 1))
  doAssert unsupported.kind == fekUnsupportedVerb
  doAssert unsupported.verb == 'z'
  let missing = expectFormatError(sprintf("%s %d", "a"))
  doAssert missing.kind == fekMissingArgument
  doAssert missing.position == 3
  doAssert missing.argIndex == 1
  let hexType = expectFormatError(sprintf("%x", "a"))
  doAssert hexType.kind == fekTypeMismatch
  doAssert hexType.argIndex == 0
  let quoteType = expectFormatError(sprintf("%q", 1))
  doAssert quoteType.kind == fekTypeMismatch
  doAssert quoteType.argIndex == 0
  let extra = expectFormatError(sprintf("%d", 1, 2))
  doAssert extra.kind == fekExtraArguments
  doAssert extra.position == -1
  doAssert extra.argIndex == 1

block validation:
  var failed = false
  try:
    discard sprintf("%d", "bad")
  except ValueError:
    failed = true
  doAssert failed

  failed = false
  try:
    discard sprintf("%d")
  except ValueError:
    failed = true
  doAssert failed

  failed = false
  try:
    discard sprintf("%d", 1, 2)
  except ValueError:
    failed = true
  doAssert failed

block fileOutput:
  let (file, path) = createTempFile("gravel-output-", ".txt")
  try:
    try:
      let count = fprintln(file, "Hello", 123)
      doAssert count == "Hello 123\n".len
      flush(file)
    finally:
      file.close()
    doAssert readFile(path) == "Hello 123\n"
  finally:
    removeFile(path)

block fileWriteFailure:
  let (created, path) = createTempFile("gravel-readonly-", ".txt")
  try:
    try:
      created.write("x")
    finally:
      created.close()
    var file: File
    doAssert open(file, path, fmRead)
    try:
      var failed = false
      try:
        discard fprintln(file, "hello")
      except IOError:
        failed = true
      doAssert failed
    finally:
      file.close()
  finally:
    removeFile(path)

when defined(linux):
  block flushFailure:
    var file: File
    doAssert open(file, "/dev/full", fmWrite)
    var failed = false
    try:
      discard fprint(file, "x")
      flush(file)
    except IOError:
      failed = true
    file.close()
    doAssert failed

block streamOutput:
  let s = newStringStream("")
  doAssert fprintf(s, "%s=%d\n", "a", 1) == 4
  doAssert fprint(s, "x", 1, 2) == 4
  doAssert fprintln(s, "é") == 3
  doAssert s.data == "a=1\nx1 2é\n"
  s.close()
