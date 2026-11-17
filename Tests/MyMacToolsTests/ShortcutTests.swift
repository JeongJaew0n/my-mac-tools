import AppKit
import Carbon
import Testing
@testable import MyMacTools

struct ShortcutTests {
    private func shortcut(_ flags: NSEvent.ModifierFlags, key: UInt16 = 8, display: String = "C") -> Shortcut {
        Shortcut(keyCode: key, modifiers: flags.rawValue, displayKey: display)
    }

    /// macOS 관례 순서: ⌃ ⌥ ⇧ ⌘.
    @Test func displayFollowsMacOrder() {
        #expect(shortcut([.command, .shift, .option, .control]).display == "⌃⌥⇧⌘C")
        #expect(shortcut([.command]).display == "⌘C")
    }

    @Test func carbonModifiers() {
        let value = shortcut([.command, .option]).carbonModifiers
        #expect(value == UInt32(cmdKey) | UInt32(optionKey))
        #expect(shortcut([.control, .shift]).carbonModifiers == UInt32(controlKey) | UInt32(shiftKey))
    }

    /// 표시 글자는 자판에 따라 달라질 수 있어 보지 않는다.
    @Test func sameKeysIgnoresDisplayText() {
        let a = shortcut([.control, .option], display: "C")
        #expect(a.hasSameKeys(as: shortcut([.control, .option], display: "ㅊ")))
        #expect(!a.hasSameKeys(as: shortcut([.control])))
        #expect(!a.hasSameKeys(as: shortcut([.control, .option], key: 9)))
        #expect(!a.hasSameKeys(as: nil))
    }

    private func keyDown(_ flags: NSEvent.ModifierFlags, characters: String = "m", key: UInt16 = 46) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                         windowNumber: 0, context: nil, characters: characters,
                         charactersIgnoringModifiers: characters, isARepeat: false, keyCode: key)!
    }

    /// 수정자 없는 키나 ⇧ 만 있는 키를 받으면 어디서 타이핑하든 단축키가 발동한다.
    @Test func recordingNeedsARealModifier() {
        #expect(Shortcut.from(keyDown([])) == nil)
        #expect(Shortcut.from(keyDown([.shift])) == nil)
        let recorded = Shortcut.from(keyDown([.control, .option, .capsLock]))
        #expect(recorded?.keyCode == 46)
        #expect(recorded?.display == "⌃⌥M", "Caps Lock 같은 기기 상태는 조합에 넣지 않는다")
    }
}
