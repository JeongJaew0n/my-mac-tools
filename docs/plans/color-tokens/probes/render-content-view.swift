import AppKit
import SwiftUI

// 실제 ContentView 를 화면 밖에서 그린다. appearance 를 강제하면 토큰의 라이트/다크가
// 그리는 순간 판정되는지까지 함께 확인된다.
MainActor.assumeIsolated {
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

let manager = BlackWorkManager(), lid = LidWorkManager(), cover = ScreenCoverManager()
let caffeine = CaffeinateScanner(), localhost = LocalhostManager()
let l10n = L10n(), preferences = Preferences()

@MainActor func render(tab: String, appearance: NSAppearance.Name, out: String) {
    UserDefaults.standard.set(tab, forKey: "selectedTab")
    let view = ContentView(manager: manager, lid: lid, cover: cover, caffeine: caffeine,
                           localhost: localhost, preferences: preferences, l10n: l10n)
        .frame(width: 380, height: 520)
    let host = NSHostingView(rootView: view)
    host.frame = NSRect(x: 0, y: 0, width: 380, height: 520)
    let window = NSWindow(contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: appearance)
    window.contentView = host
    host.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(1.2))   // 목록 채움·레이아웃
    host.layoutSubtreeIfNeeded()
    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
    host.cacheDisplay(in: host.bounds, to: rep)
    // 창 바탕까지 넣어 실제와 같게 합성한다
    let final = NSImage(size: host.bounds.size)
    final.lockFocus()
    NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
        NSColor.windowBackgroundColor.setFill()
        host.bounds.fill()
    }
    NSImage(size: host.bounds.size, flipped: false) { _ in rep.draw(); return true }.draw(in: host.bounds)
    final.unlockFocus()
    if let t = final.tiffRepresentation, let r = NSBitmapImageRep(data: t),
       let png = r.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: out)); print("  \(tab) \(appearance.rawValue) → \(out.split(separator: "/").last!)")
    }
    window.close()
}

let dir = CommandLine.arguments[1]
for tab in ["screenOff", "localhost"] {
    render(tab: tab, appearance: .aqua, out: "\(dir)/r-\(tab)-light.png")
    render(tab: tab, appearance: .darkAqua, out: "\(dir)/r-\(tab)-dark.png")
}
UserDefaults.standard.set("screenOff", forKey: "selectedTab")
}
