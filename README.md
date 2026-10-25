# Gravel (Nim 2.x)

Gravel is a small, standard-library-only, Go `fmt`-inspired formatted I/O library for Nim.

## Usage

```nim
import gravel

println("Hello", "Nim", 2026)            # Hello Nim 2026\n
print("A", "B", 123)                       # AB123
printf("Name: %s, Age: %d\n", "Ava", 25)
printf("CPU: %.2f%%\n", 82.456)

let message = sprintf("ID=%d", 1001)
discard eprintf("%s: %d\n", "error", 2)  # stderr
flush(stdout)
```

For in-memory or custom stream output, import `std/streams` and use the same
`fprint` / `fprintln` / `fprintf` functions with a `Stream` target:

```nim
import std/streams
import gravel

let buffer = newStringStream("")
discard fprintf(buffer, "%q -> %x\n", "id", 255)
assert buffer.data == "\"id\" -> ff\n"
buffer.close()
```

Use `std/streams.flush` for a `Stream`; `gravel.flush` accepts a `File`.

## Lightweight logger

Import `gravel/logger` for one-line logfmt output to stderr (default), a
`File`, or a `std/streams.Stream`:

```nim
import gravel/logger

let appLog = newLogger(minLevel = logInfo)
let requestLog = appLog.withField("request_id", 42)
requestLog.errorf("upstream failed: %s", "timeout")
# time=... level=error msg="upstream failed: timeout" request_id=42
```

`debugf`, `infof`, `warnf`, and `errorf` accept Gravel's `%` directives.
`withField` returns a new logger, leaving the original unchanged; repeated keys
replace their values. Keys may contain ASCII letters, digits, `_`, `.`, or `-`,
but `time`, `level`, and `msg` are reserved. Values are quoted as needed with
Gravel's `%q` byte escaping. Set `timestamps = false` for deterministic output,
or `minLevel = logDebug` for debug messages. Formatting happens **before**
level filtering, so invalid format strings still raise `FormatError`.
Each call writes one line and returns its UTF-8 byte count, or zero if filtered.
The logger does not own or close its output target; call `flush(appLog)` when
explicit flushing is required. Loggers do not lock. Each record is written
with one call, but concurrent use of a logger or shared output target from
multiple threads requires caller-side synchronization.

## Output rules

- `print` / `sprint` / `fprint` / `eprint` do **not** append a newline. As in Go, they add a space between adjacent arguments only when **both** are non-string values.
- `println` / `sprintln` / `fprintln` / `eprintln` always separate arguments with one space and append `\n`.
- `printf` / `sprintf` / `fprintf` / `eprintf` use strict format specifiers. No automatic newline.
- Output functions return the written **UTF-8 byte** count on success, marked `{.discardable.}`.
- Formatting functions are Nim `func`; I/O functions are Nim `proc`.

`eprint`, `eprintln`, and `eprintf` write to `stderr` with the same formatting,
byte-count return value, and exception behavior as their stdout counterparts.
They do not add an error prefix or flush automatically; call `flush(stderr)`
when explicit flushing is needed.

`File` writes check the C stream error state: a failed write or `flush(File)`
raises `IOError`, and the `File` remains in that error state for later writes.
`Stream` writes propagate the stream's own exceptions.

## Supported verbs

| Verb | Meaning | Expected type |
|------|---------|---------------|
| `%v` | Default Nim `$` representation | Any (with pure `$`) |
| `%s` | String as-is | `string`, `cstring` |
| `%d` | Decimal integer | `SomeInteger` |
| `%t` | Boolean | `bool` |
| `%f` | Fixed decimal with 6 digits after decimal | `SomeFloat` |
| `%.Nf` | Fixed decimal with N digits after decimal (0..32) | `SomeFloat` |
| `%x`, `%X` | Lowercase / uppercase hexadecimal, signed magnitude without leading zeros | `SomeInteger` |
| `%q` | Double-quoted string; escapes quotes, backslashes and controls, preserves UTF-8 bytes | `string`, `cstring` |
| `%e`, `%.Ne` | Scientific notation, default 6 digits after decimal; N is 0..32 | `SomeFloat` |
| `%g`, `%.Ng` | Shortest form by default; N significant digits (0..32), trailing fractional zeros removed | `SomeFloat` |
| `%%` | Percent literal | No argument |

Unsupported flags/verbs, arity mismatches, or argument-type mismatches raise
`FormatError` (a `ValueError` subtype). Its `kind: FormatErrorKind`, `position`
(zero-based UTF-8 byte index of `%`), `verb`, and `argIndex` (zero-based where
applicable) identify the failure. `File` and `Stream` writes propagate I/O
exceptions rather than returning a Go-style `(n, err)` pair.

This is not complete Go `fmt` compatibility. Field widths, dynamic widths,
flags, pointers, and nested custom formatters are unsupported. `%x` accepts
integers only, `%q` uses byte-oriented escaping, and non-finite float values
retain Nim's `inf` / `-inf` / `nan` spelling.

## Build / test

Requires **Nim 2.2 or newer**. No third-party dependencies.

```sh
nim c -r --path:src examples/demo.nim
nim c -r --path:src tests/test_gravel.nim
# or, with Nimble installed:
nimble test
nimble verify   # strict checks + tests (used by CI)
```

