import gravel/logger

let appLog = newLogger(minLevel = logDebug)
appLog.infof("service started on port %d", 8080)
let reqLog = appLog.withField("request_id", 42).withField("user",
    "Ada Lovelace")
reqLog.warnf("slow response: %.1fms", 812.4)
reqLog.errorf("upstream failed: %s", "timeout")
appLog.debugf("cache entries=%d", 128)
