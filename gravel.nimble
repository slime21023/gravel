version       = "1.0.0"
author        = "Project contributors"
description   = "A minimal, strict Go fmt-inspired output library for Nim"
license       = "MIT"
srcDir        = "src"
requires "nim >= 2.2.0"

const
  testFiles = ["tests/test_gravel.nim", "tests/test_logger.nim"]
  checkedFiles = ["src/gravel.nim", "src/gravel/logger.nim",
                  "tests/test_gravel.nim", "tests/test_logger.nim",
                  "examples/demo.nim", "examples/logger_demo.nim"]

task test, "Run library tests":
  for file in testFiles:
    exec "nim c -r --path:src " & file

task verify, "Run strict static checks and all tests":
  for file in checkedFiles:
    exec "nim check --hints:off --path:src --styleCheck:error --warningAsError:UnusedImport " & file
  for file in testFiles:
    exec "nim c -r --hints:off --path:src " & file
