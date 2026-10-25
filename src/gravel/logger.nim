## Lightweight logfmt logger using Gravel's formatting and output routines.
import std/[streams, times]
import ../gravel
export FormatArg, toFormatArg

type
  LogLevel* = enum
    logDebug = "debug", logInfo = "info", logWarn = "warn", logError = "error"

  GravelLogger* = ref object
    file: File
    stream: Stream
    minLevel: LogLevel
    timestamps: bool
    fields: seq[tuple[key, value: string]]

const timeFormat = "yyyy-MM-dd'T'HH:mm:ss'.'fffzzz"

proc newLogger*(target: File = stderr; minLevel = logInfo;
                timestamps = true): GravelLogger =
  GravelLogger(file: target, minLevel: minLevel, timestamps: timestamps)

proc newLogger*(target: Stream; minLevel = logInfo;
                timestamps = true): GravelLogger =
  if target.isNil:
    raise newException(ValueError, "log target stream is nil")
  GravelLogger(stream: target, minLevel: minLevel, timestamps: timestamps)

func logfmtValue(s: string): string =
  if s.len == 0:
    return sprintf("%q", s)
  for ch in s:
    if ch <= ' ' or ch == '\x7f' or ch in {'=', '"', '\\'}:
      return sprintf("%q", s)
  s

proc withField*[T](logger: GravelLogger; key: string; value: T): GravelLogger =
  if key.len == 0:
    raise newException(ValueError, "invalid log field key: " & sprintf("%q", key))
  for ch in key:
    if ch notin {'a'..'z', 'A'..'Z', '0'..'9', '_', '.', '-'}:
      raise newException(ValueError, "invalid log field key: " & sprintf("%q", key))
  if key in ["time", "level", "msg"]:
    raise newException(ValueError, "reserved log field key: " & key)

  result = GravelLogger(file: logger.file, stream: logger.stream,
                        minLevel: logger.minLevel,
                        timestamps: logger.timestamps)
  result.fields = newSeqOfCap[tuple[key, value: string]](logger.fields.len + 1)
  for field in logger.fields:
    result.fields.add field
  let formatted = logfmtValue(sprint(value))
  for field in result.fields.mitems:
    if field.key == key:
      field.value = formatted
      return
  result.fields.add (key, formatted)

proc logf*(logger: GravelLogger; level: LogLevel; pattern: string;
           args: varargs[FormatArg, toFormatArg]): int {.discardable.} =
  let message = sprintf(pattern, args)
  if level < logger.minLevel:
    return 0
  var line: string
  if logger.timestamps:
    line.add "time="
    line.add now().format(timeFormat)
    line.add ' '
  line.add "level="
  line.add $level
  line.add " msg="
  line.add logfmtValue(message)
  for field in logger.fields:
    line.add ' '
    line.add field.key
    line.add '='
    line.add field.value
  line.add '\n'
  if logger.stream.isNil:
    result = fprint(logger.file, line)
  else:
    result = fprint(logger.stream, line)

proc debugf*(logger: GravelLogger; pattern: string;
             args: varargs[FormatArg, toFormatArg]): int {.discardable.} =
  logf(logger, logDebug, pattern, args)

proc infof*(logger: GravelLogger; pattern: string;
            args: varargs[FormatArg, toFormatArg]): int {.discardable.} =
  logf(logger, logInfo, pattern, args)

proc warnf*(logger: GravelLogger; pattern: string;
            args: varargs[FormatArg, toFormatArg]): int {.discardable.} =
  logf(logger, logWarn, pattern, args)

proc errorf*(logger: GravelLogger; pattern: string;
             args: varargs[FormatArg, toFormatArg]): int {.discardable.} =
  logf(logger, logError, pattern, args)

proc flush*(logger: GravelLogger) =
  if logger.stream.isNil:
    flush(logger.file)
  else:
    logger.stream.flush()
