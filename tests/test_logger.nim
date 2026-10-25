import std/[streams, strutils, times]
import gravel
import gravel/logger

block message:
  let s = newStringStream("")
  let appLog = newLogger(s, minLevel = logDebug, timestamps = false)
  let expected = "level=info msg=\"started api\"\n"
  doAssert appLog.infof("started %s", "api") == expected.len
  doAssert s.data == expected
  s.close()

block filtering:
  let s = newStringStream("")
  let appLog = newLogger(s, minLevel = logWarn, timestamps = false)
  doAssert appLog.infof("x") == 0
  doAssert s.data == ""
  discard appLog.warnf("disk %d%%", 91)
  doAssert s.data == "level=warn msg=\"disk 91%\"\n"
  s.close()

block formatErrorWhenFiltered:
  let s = newStringStream("")
  let appLog = newLogger(s, minLevel = logError, timestamps = false)
  var caught = false
  try:
    discard appLog.debugf("%d", "x")
  except FormatError:
    caught = true
  doAssert caught
  doAssert s.data == ""
  s.close()

block fields:
  let s = newStringStream("")
  let appLog = newLogger(s, timestamps = false)
  let reqLog = appLog.withField("host", "db").withField("port", 5432).withField(
      "note", "a b\"c")
  discard reqLog.errorf("failed")
  doAssert s.data == "level=error msg=failed host=db port=5432 note=\"a b\\\"c\"\n"
  discard appLog.infof("plain")
  doAssert s.data.endsWith("level=info msg=plain\n")
  s.close()

block fieldReplace:
  let s = newStringStream("")
  let appLog = newLogger(s, timestamps = false)
  discard appLog.withField("k", 1).withField("k", 2).infof("v")
  doAssert s.data == "level=info msg=v k=2\n"
  s.close()

block emptyValue:
  let s = newStringStream("")
  let appLog = newLogger(s, timestamps = false)
  discard appLog.withField("user", "").infof("ok")
  doAssert s.data == "level=info msg=ok user=\"\"\n"
  s.close()

block invalidKeys:
  let s = newStringStream("")
  let appLog = newLogger(s, timestamps = false)
  for key in ["", "a b", "a=b", "msg"]:
    var caught = false
    try:
      discard appLog.withField(key, "value")
    except ValueError:
      caught = true
    doAssert caught
  s.close()

block timestamp:
  let s = newStringStream("")
  let appLog = newLogger(s)
  discard appLog.infof("ready")
  doAssert s.data.startsWith("time=")
  let firstSpace = s.data.find(' ')
  let stamp = s.data[5..<firstSpace]
  discard parse(stamp, "yyyy-MM-dd'T'HH:mm:ss'.'fffzzz")
  doAssert s.data[firstSpace..^1] == " level=info msg=ready\n"
  s.close()

block oneLinePerRecord:
  let s = newStringStream("")
  let appLog = newLogger(s, timestamps = false)
  discard appLog.infof("")
  discard appLog.infof("a\nb")
  discard appLog.withField("user", "é").withField("ctl", "x\ty").infof("ok")
  doAssert s.data ==
    "level=info msg=\"\"\nlevel=info msg=\"a\\nb\"\nlevel=info msg=ok user=é ctl=\"x\\ty\"\n"
  s.close()
