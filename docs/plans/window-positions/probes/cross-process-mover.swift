import AppKit
let h = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW)
func sym<T>(_ n: String, _ t: T.Type) -> T? { dlsym(h, n).map { unsafeBitCast($0, to: t) } }
typealias MainConn = @convention(c) () -> Int32
typealias CopyDisplaySpaces = @convention(c) (Int32) -> Unmanaged<CFArray>?
typealias CopySpacesForWindows = @convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?
typealias MoveToSpace = @convention(c) (Int32, CFArray, Int) -> Void
typealias AddRemove = @convention(c) (Int32, CFArray, CFArray) -> Void
typealias MoveWindow = @convention(c) (Int32, Int32, UnsafePointer<CGPoint>) -> Int32

let cid = sym("CGSMainConnectionID", MainConn.self)!()
let spacesOf = sym("CGSCopySpacesForWindows", CopySpacesForWindows.self)!
let wid = Int(CommandLine.arguments[1])!
func where_() -> [Int] { spacesOf(cid, 7, [wid] as CFArray)?.takeRetainedValue() as? [Int] ?? [] }
func bounds() -> String {
    let l = CGWindowListCopyWindowInfo([.optionIncludingWindow], CGWindowID(wid)) as? [[String: Any]] ?? []
    let b = l.first?[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
    return "\(Int(b["X"] ?? -1)),\(Int(b["Y"] ?? -1))"
}
let disp = (sym("CGSCopyManagedDisplaySpaces", CopyDisplaySpaces.self)!(cid)?.takeRetainedValue() as? [[String: Any]]) ?? []
let start = where_()
let target = disp.flatMap { ($0["Spaces"] as? [[String: Any]]) ?? [] }
    .filter { ($0["type"] as? Int) == 0 }
    .compactMap { $0["ManagedSpaceID"] as? Int }
    .first { !start.contains($0) }!
print("남의 창 #\(wid)  시작 space=\(start)  위치=\(bounds())")

print("\n[A] CGSMoveWindowsToManagedSpace → \(target)")
sym("CGSMoveWindowsToManagedSpace", MoveToSpace.self)?(cid, [wid] as CFArray, target)
RunLoop.main.run(until: Date().addingTimeInterval(0.6))
let a = where_(); print("    결과 space=\(a) → \(a == [target] ? "성공" : "실패(무시됨)")")

print("\n[B] CGSAddWindowsToSpaces + CGSRemoveWindowsFromSpaces → \(target)")
sym("CGSAddWindowsToSpaces", AddRemove.self)?(cid, [wid] as CFArray, [target] as CFArray)
sym("CGSRemoveWindowsFromSpaces", AddRemove.self)?(cid, [wid] as CFArray, start as CFArray)
RunLoop.main.run(until: Date().addingTimeInterval(0.6))
let b = where_(); print("    결과 space=\(b) → \(b == [target] ? "성공" : "실패(무시됨)")")

print("\n[C] CGSMoveWindow (위치 이동, AX 없이)")
var p = CGPoint(x: 400, y: 300)
let rc = sym("CGSMoveWindow", MoveWindow.self)?(cid, Int32(wid), &p) ?? -999
RunLoop.main.run(until: Date().addingTimeInterval(0.6))
print("    반환=\(rc)  위치=\(bounds())  → \(bounds() == "400,300" ? "성공" : "실패")")
