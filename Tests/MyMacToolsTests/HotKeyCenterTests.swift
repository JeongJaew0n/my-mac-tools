import AppKit
import Carbon
import Testing
@testable import MyMacTools

/// 전역 단축키 자리. 실제로 Carbon 에 등록해 본다 — 같은 조합을 다른 서명으로 걸어 보면
/// 그 조합이 비어 있는지 알 수 있다(같은 프로세스 안의 중복 등록은 Carbon 이 거부한다).
///
/// `HotKeyCenter.shared` 는 하나뿐이라 시험끼리 섞이면 안 된다. 모두 `@MainActor` 이고
/// 중간에 기다리는 곳이 없어, 한 시험이 끝나기 전에 다른 시험이 끼어들지 않는다.
@MainActor
struct HotKeyCenterTests {
    let center = HotKeyCenter.shared
    let a = Self.shortcut(8)    // ⌃⌥C
    let b = Self.shortcut(46)   // ⌃⌥M
    let x = Self.shortcut(39)   // ⌃⌥'

    static func shortcut(_ key: UInt16) -> Shortcut {
        Shortcut(keyCode: key, modifiers: NSEvent.ModifierFlags([.control, .option]).rawValue, displayKey: "?")
    }

    /// 걸려 있지 않은 조합인가.
    func isFree(_ s: Shortcut) -> Bool {
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(s.keyCode), s.carbonModifiers,
                                         EventHotKeyID(signature: 0x54455354, id: 99),  // 'TEST'
                                         GetEventDispatcherTarget(), 0, &ref)
        guard status == noErr, let ref else { return false }
        UnregisterEventHotKey(ref)
        return true
    }

    func clear() {
        center.set(nil, for: .cover) {}
        center.set(nil, for: .screenOff) {}
    }

    @Test func refusesACombinationHeldByTheOtherSlot() {
        defer { clear() }
        #expect(center.set(a, for: .cover) {} == .done)
        #expect(center.set(b, for: .screenOff) {} == .done)
        #expect(center.set(a, for: .screenOff) {} == .taken(by: .cover))
        #expect(!isFree(b), "거절한 뒤에도 원래 조합은 걸려 있어야 한다")
        #expect(center.set(a, for: .cover) {} == .done, "자기 조합을 다시 거는 것은 된다")
    }

    /// 기록하는 동안 풀어 두지 않으면 등록된 조합이 기록기 대신 핫키로 발동한다.
    @Test func pauseReleasesEverySlotUntilTheLastResume() {
        defer { clear() }
        center.set(a, for: .cover) {}
        center.set(b, for: .screenOff) {}
        center.pause()
        #expect(isFree(a) && isFree(b))
        center.pause()
        center.resume()
        #expect(isFree(a) && isFree(b), "기록기가 하나 더 열려 있으면 아직 풀려 있어야 한다")
        center.resume()
        #expect(!isFree(a) && !isFree(b))
        center.resume()
        #expect(!isFree(a) && !isFree(b), "짝 없는 resume 은 무시한다")
    }

    /// macOS 가 거부하면 자리를 비우지 않고 원래 단축키를 되살린다.
    @Test func keepsThePreviousShortcutWhenRegistrationFails() {
        defer { clear() }
        center.set(b, for: .screenOff) {}
        var probe: EventHotKeyRef?
        RegisterEventHotKey(UInt32(x.keyCode), x.carbonModifiers, EventHotKeyID(signature: 0x54455354, id: 7),
                            GetEventDispatcherTarget(), 0, &probe)
        defer { if let probe { UnregisterEventHotKey(probe) } }
        #expect(center.set(x, for: .screenOff) {} == .failed)
        #expect(!isFree(b))
    }

    @Test func clearingReleasesTheCombination() {
        defer { clear() }
        center.set(b, for: .screenOff) {}
        #expect(center.set(nil, for: .screenOff) {} == .done)
        #expect(isFree(b))
    }

    /// 관리자는 걸리지 않은 조합을 저장하지도 보이지도 않는다.
    @Test func managerKeepsItsShortcutWhenRefused() {
        defer {
            clear()
            Shortcut.save(nil, key: "coverShortcut")
            Shortcut.save(nil, key: "screenOffShortcut")
        }
        let cover = ScreenCoverManager()
        let sleep = BlackWorkManager()
        #expect(cover.setShortcut(a) == .done)
        #expect(sleep.setShortcut(b) == .done)
        #expect(sleep.setShortcut(a) == .taken(by: .cover))
        #expect(sleep.shortcut == b)
        #expect(Shortcut.load(key: "screenOffShortcut") == b)
    }
}
