import AppKit
// 창만 띄우고 창 번호를 파일에 쓴 뒤 20초 산다.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let w = NSWindow(contentRect: NSRect(x: 120, y: 120, width: 220, height: 80), styleMask: [.titled], backing: .buffered, defer: false)
w.title = "cross-process-probe"; w.orderFront(nil)
RunLoop.main.run(until: Date().addingTimeInterval(0.4))
try? "\(w.windowNumber)".write(toFile: CommandLine.arguments[1], atomically: true, encoding: .utf8)
RunLoop.main.run(until: Date().addingTimeInterval(20))
