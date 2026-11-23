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

    /// 같은 키 조합인가. 표시 글자는 자판 배열에 따라 달라질 수 있어 보지 않는다.
    func hasSameKeys(as other: Shortcut?) -> Bool {
        guard let other else { return false }
        return keyCode == other.keyCode && modifiers == other.modifiers
    }

    /// 저장된 단축키. 없거나 못 읽으면 `nil`.
    static func load(key: String) -> Shortcut? {
        UserDefaults.standard.data(forKey: key)
            .flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) }
    }

    /// `nil` 이면 지운다.
    static func save(_ value: Shortcut?, key: String) {
        if let value, let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

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

/// 전역 단축키를 자리(`Slot`)별로 하나씩 등록해 쓴다.
///
/// Carbon 의 `RegisterEventHotKey` 를 쓴다. `NSEvent` 의 전역 모니터와 달리
/// **손쉬운 사용 권한이 필요 없고**(권한 없는 상태에서 `noErr` 로 등록되는 것을 확인했다),
/// 키를 삼켜서 뒤의 앱으로 새지 않는다.
///
/// 삼키는 것은 **이 앱 자신에게도** 마찬가지다. 단축키 기록기는 앱 안의 keyDown 을 보는데,
/// 등록된 조합은 거기까지 오지 않고 핫키로 발동한다. 그래서 기록하는 동안은 `pause()` 로
/// 모두 풀어 둔다 — 안 그러면 다른 자리의 조합을 누를 때 겹침 안내 대신 그 동작이 실행된다.
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    /// 단축키를 거는 자리. raw 값이 `EventHotKeyID.id` 다 — 눌린 키가 어느 자리인지 이것으로 가른다.
    enum Slot: UInt32 {
        case cover = 1
        case screenOff = 2
        case captureEdit = 3
    }

    /// `set` 의 결과.
    enum Outcome: Equatable {
        /// 걸었다. 지운 경우도 여기다.
        case done
        /// 다른 자리가 이미 쓰는 조합이다. 아무것도 바꾸지 않았다.
        case taken(by: Slot)
        /// macOS 가 거부했다. 그 자리는 원래 단축키 그대로다.
        case failed
    }

    private static let signature: OSType = 0x4D4D5448  // 'MMTH'

    private struct Entry {
        let shortcut: Shortcut
        let action: () -> Void
        /// 잠시 멈춘 동안에는 `nil` 이다.
        var ref: EventHotKeyRef?
    }

    private var entries: [Slot: Entry] = [:]
    private var handler: EventHandlerRef?
    /// 기록기가 여러 개 동시에 열려도 마지막 것이 닫힐 때 다시 건다.
    private var pauseCount = 0

    private init() {}

    /// 그 자리의 단축키를 바꾼다. `nil` 이면 지운다.
    ///
    /// **다른 자리와 같은 조합은 거절한다.** 같은 조합을 두 번 등록하면 Carbon 이 두 번째를
    /// 거부하는데(실측), 그 전에 이 자리의 옛 등록을 풀었으면 자리가 비어 버린다. 겹침 검사를
    /// 화면마다 두지 않고 모든 자리를 아는 여기서 한다.
    ///
    /// 같은 조합을 이미 **시스템이** 쓰고 있어도 `noErr` 가 돌아온다. 예컨대 `⌘Space` 를
    /// 등록해도 성공으로 보고되지만 실제로는 Spotlight 이 먼저 먹는다. 그래서 `.done` 이
    /// 곧 "이 키가 눌리면 우리가 받는다" 를 뜻하지는 않는다. 사용자에게 알려줄 방법이 없어
    /// 그대로 둔다.
    @discardableResult
    func set(_ shortcut: Shortcut?, for slot: Slot, action: @escaping () -> Void) -> Outcome {
        if let shortcut,
           let other = entries.first(where: { $0.key != slot && $0.value.shortcut.hasSameKeys(as: shortcut) }) {
            return .taken(by: other.key)
        }
        let previous = entries[slot]
        remove(slot)
        guard let shortcut else { return .done }

        var entry = Entry(shortcut: shortcut, action: action)
        if pauseCount == 0 {
            guard let ref = register(shortcut, slot) else {
                // 거부됐으면 원래 것을 되살린다. 자리를 비워 두면 쓰던 단축키까지 잃는다.
                if var previous {
                    previous.ref = register(previous.shortcut, slot)
                    entries[slot] = previous
                }
                return .failed
            }
            entry.ref = ref
        }
        entries[slot] = entry
        return .done
    }

    /// 단축키를 기록하는 동안 모두 푼다. `resume()` 과 짝을 맞춘다.
    func pause() {
        pauseCount += 1
        guard pauseCount == 1 else { return }
        for slot in entries.keys {
            if let ref = entries[slot]?.ref { UnregisterEventHotKey(ref) }
            entries[slot]?.ref = nil
        }
    }

    func resume() {
        guard pauseCount > 0 else { return }
        pauseCount -= 1
        guard pauseCount == 0 else { return }
        for (slot, entry) in entries {
            entries[slot]?.ref = register(entry.shortcut, slot)
        }
    }

    private func remove(_ slot: Slot) {
        if let ref = entries.removeValue(forKey: slot)?.ref {
            UnregisterEventHotKey(ref)
        }
    }

    private func register(_ shortcut: Shortcut, _ slot: Slot) -> EventHotKeyRef? {
        installHandlerIfNeeded()
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            shortcut.carbonModifiers,
            EventHotKeyID(signature: Self.signature, id: slot.rawValue),
            GetEventDispatcherTarget(),
            0,
            &ref)
        return status == noErr ? ref : nil
    }

    private func fire(_ id: UInt32) {
        guard let slot = Slot(rawValue: id) else { return }
        entries[slot]?.action()
    }

    private func installHandlerIfNeeded() {
        guard handler == nil else { return }
        var type = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                // 어느 자리의 키인지 이벤트에서 꺼낸다. 하나만 걸던 때는 볼 필요가 없었다.
                var pressed = EventHotKeyID()
                let status = GetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                    nil, MemoryLayout<EventHotKeyID>.size, nil, &pressed)
                guard status == noErr, pressed.signature == HotKeyCenter.signature else { return noErr }
                let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
                let id = pressed.id
                DispatchQueue.main.async { center.fire(id) }
                return noErr
            },
            1,
            &type,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler)
    }
}
