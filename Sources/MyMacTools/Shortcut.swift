import AppKit
import Carbon

/// 사용자가 지정한 전역 단축키 한 벌.
///
/// 표시용 글자를 따로 들고 다닌다. 키 코드만으로 글자를 되짚으려면 현재 자판 배열을
/// 해석해야 하는데, 기록하는 순간에는 `charactersIgnoringModifiers` 로 그냥 알 수 있다.
struct Shortcut: Equatable, Codable {
    let keyCode: UInt16
    /// `NSEvent.ModifierFlags` 의 raw 값. 저장은 이쪽으로 한다.
    let modifiers: UInt
    /// 화면에 보일 키 이름 (`C`, `F5` 등).
    let displayKey: String

    var flags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }

    /// `⌃⌥⌘C` 처럼. 순서는 macOS 관례를 따른다.
    var display: String {
        var text = ""
        if flags.contains(.control) { text += "⌃" }
        if flags.contains(.option)  { text += "⌥" }
        if flags.contains(.shift)   { text += "⇧" }
        if flags.contains(.command) { text += "⌘" }
        return text + displayKey
    }

    /// Carbon 이 쓰는 수정자 비트.
    var carbonModifiers: UInt32 {
        var value: UInt32 = 0
        if flags.contains(.command) { value |= UInt32(cmdKey) }
        if flags.contains(.option)  { value |= UInt32(optionKey) }
        if flags.contains(.control) { value |= UInt32(controlKey) }
        if flags.contains(.shift)   { value |= UInt32(shiftKey) }
        return value
    }

    /// 기록할 만한 조합인가.
    ///
    /// **수정자가 하나도 없으면 받지 않는다.** 맨 글자에 걸어두면 어디서 무엇을 타이핑하든
    /// 화면이 덮여버린다. `Shift` 만 있는 것도 같은 이유로 수정자로 치지 않는다.
    static func from(_ event: NSEvent) -> Shortcut? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.intersection([.command, .option, .control]).isEmpty else { return nil }
        guard let characters = event.charactersIgnoringModifiers, !characters.isEmpty else { return nil }
        return Shortcut(
            keyCode: event.keyCode,
            modifiers: flags.intersection([.command, .option, .control, .shift]).rawValue,
            displayKey: characters.uppercased())
    }
}

/// 전역 단축키를 하나만 등록해 쓴다.
///
/// Carbon 의 `RegisterEventHotKey` 를 쓴다. `NSEvent` 의 전역 모니터와 달리
/// **손쉬운 사용 권한이 필요 없고**(권한 없는 상태에서 `noErr` 로 등록되는 것을 확인했다),
/// 키를 삼켜서 뒤의 앱으로 새지 않는다.
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private static let signature: OSType = 0x4D4D5448  // 'MMTH'

    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var action: (() -> Void)?

    private init() {}

    /// 등록에 성공하면 `true`.
    ///
    /// 같은 조합을 이미 **시스템이** 쓰고 있어도 `noErr` 가 돌아온다. 예컨대 `⌘Space` 를
    /// 등록해도 성공으로 보고되지만 실제로는 Spotlight 이 먼저 먹는다. 그래서 등록 성공이
    /// 곧 "이 키가 눌리면 우리가 받는다" 를 뜻하지는 않는다. 사용자에게 알려줄 방법이 없어
    /// 그대로 둔다.
    @discardableResult
    func register(_ shortcut: Shortcut, action: @escaping () -> Void) -> Bool {
        unregister()
        installHandlerIfNeeded()
        self.action = action

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            shortcut.carbonModifiers,
            EventHotKeyID(signature: Self.signature, id: 1),
            GetEventDispatcherTarget(),
            0,
            &ref)

        guard status == noErr, let ref else {
            self.action = nil
            return false
        }
        hotKey = ref
        return true
    }

    func unregister() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
        }
        hotKey = nil
        action = nil
    }

    private func installHandlerIfNeeded() {
        guard handler == nil else { return }
        var type = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { center.action?() }
                return noErr
            },
            1,
            &type,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler)
    }
}
