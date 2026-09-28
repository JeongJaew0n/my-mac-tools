import AppKit
import ApplicationServices

// ── 비공개 SkyLight 심볼 (CoreGraphics 가 재수출) ──
let h = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW)
func sym<T>(_ n: String, _ t: T.Type) -> T? { dlsym(h, n).map { unsafeBitCast($0, to: t) } }
typealias MainConn = @convention(c) () -> Int32
typealias CopyDisplaySpaces = @convention(c) (Int32) -> Unmanaged<CFArray>?
typealias CopySpacesForWindows = @convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?

print("── 권한 ──")
print("  손쉬운 사용(AXIsProcessTrusted) = \(AXIsProcessTrusted())   ※ 이 값은 프로브를 띄운 터미널 기준")
print("  화면 기록(CGPreflightScreenCaptureAccess) = \(CGPreflightScreenCaptureAccess())")

print("\n── 디스플레이 ──")
var ids = [CGDirectDisplayID](repeating: 0, count: 16); var n: UInt32 = 0
CGGetActiveDisplayList(16, &ids, &n)
for id in ids.prefix(Int(n)) {
    let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue()
    let s = uuid.map { CFUUIDCreateString(nil, $0) as String } ?? "?"
    let b = CGDisplayBounds(id)
    let name = NSScreen.screens.first { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == id }?.localizedName ?? "?"
    print("  id=\(id)  \(name)  bounds=\(Int(b.origin.x)),\(Int(b.origin.y)) \(Int(b.width))x\(Int(b.height))  UUID=\(s)")
}

print("\n── Spaces (비공개 CGSCopyManagedDisplaySpaces) ──")
guard let mc = sym("CGSMainConnectionID", MainConn.self),
      let cds = sym("CGSCopyManagedDisplaySpaces", CopyDisplaySpaces.self),
      let csw = sym("CGSCopySpacesForWindows", CopySpacesForWindows.self) else { print("  심볼 없음"); exit(0) }
let cid = mc()
print("  connection=\(cid)")
var spaceToDisplay: [Int: String] = [:]
if let arr = cds(cid)?.takeRetainedValue() as? [[String: Any]] {
    for d in arr {
        let disp = d["Display Identifier"] as? String ?? "?"
        let cur = (d["Current Space"] as? [String: Any])?["ManagedSpaceID"] as? Int ?? -1
        let spaces = (d["Spaces"] as? [[String: Any]]) ?? []
        let desc = spaces.map { sp -> String in
            let id = sp["ManagedSpaceID"] as? Int ?? -1
            spaceToDisplay[id] = disp
            let type = sp["type"] as? Int ?? -1   // 0 = 일반, 4 = 전체화면
            return "\(id)\(type == 4 ? "(전체화면)" : "")\(id == cur ? "*" : "")"
        }
        print("  display \(disp)  spaces=[\(desc.joined(separator: ", "))]   (* = 현재)")
    }
}

print("\n── 창 목록 (CGWindowListCopyWindowInfo, layer 0 만) ──")
let all = (CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? [])
    .filter { ($0[kCGWindowLayer as String] as? Int) == 0 }
let onscreen = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? [])
    .filter { ($0[kCGWindowLayer as String] as? Int) == 0 }
let titled = all.filter { !(($0[kCGWindowName as String] as? String) ?? "").isEmpty }
print("  전체(.optionAll) \(all.count)개 / 지금 Space 에 보이는 것(.optionOnScreenOnly) \(onscreen.count)개")
print("  제목을 읽을 수 있는 창: \(titled.count)개  ※ 제목은 화면 기록 권한이 있어야 나온다")

print("\n── 창 → Space (비공개 CGSCopySpacesForWindows) 표본 ──")
var perSpace: [Int: Int] = [:]
var noSpace = 0
for w in all {
    guard let wid = w[kCGWindowNumber as String] as? Int else { continue }
    let r = csw(cid, 7, [wid] as CFArray)?.takeRetainedValue() as? [Int] ?? []
    if r.isEmpty { noSpace += 1 } else { for s in r { perSpace[s, default: 0] += 1 } }
}
for (s, c) in perSpace.sorted(by: { $0.key < $1.key }) {
    print("  space \(s) (\(spaceToDisplay[s].map { String($0.prefix(8)) } ?? "?")…): 창 \(c)개")
}
print("  Space 를 못 찾은 창: \(noSpace)개 (최소화·숨김 등)")

print("\n── 표본 5개 ──")
for w in all.prefix(5) {
    let owner = w[kCGWindowOwnerName as String] as? String ?? "?"
    let wid = w[kCGWindowNumber as String] as? Int ?? 0
    let b = w[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
    let sp = csw(cid, 7, [wid] as CFArray)?.takeRetainedValue() as? [Int] ?? []
    print("  #\(wid) \(owner)  \(Int(b["X"] ?? 0)),\(Int(b["Y"] ?? 0)) \(Int(b["Width"] ?? 0))x\(Int(b["Height"] ?? 0))  space=\(sp)")
}
