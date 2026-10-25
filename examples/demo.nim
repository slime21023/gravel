import std/streams
import gravel

println("Hello", "Nim", 2026)
printf("Name: %s, Age: %d\n", "Alice", 25)
printf("CPU usage: %.2f%%\n", 82.456)
let message = sprintf("User ID: %d", 1001)
println(message)
eprintln("Connection failed")
flush(stdout)

let buffer = newStringStream("")
fprintf(buffer, "%q -> %x\n", "id", 255)
print(buffer.data)
buffer.close()
