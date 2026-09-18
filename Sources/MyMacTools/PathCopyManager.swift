import AppKit
import Combine

/// Finder 에서 고른 항목의 절대경로를 클립보드에 복사한다.
///
/// macOS 에도 같은 기능이 있지만(`⌥⌘C`) 그 키는 바꿀 수 없다. 메뉴 제목에 파일명과 개수가
/// 들어가서 시스템 설정의 "앱 단축키" 로 재지정되지 않기 때문이다. 자세한 근거는
/// `docs/plans/finder-path-copy/spec.md`.
final class PathCopyManager: ObservableObject {

    /// 마지막 실행 결과. 단축키는 앱이 안 보일 때 눌리므로, 창을 열었을 때 무슨 일이
    /// 있었는지 알 수 있게 남겨둔다.
    enum Outcome: Equatable, Error {
        /// n 개를 복사했다.
        case copied(Int)
        /// Finder 에서 아무것도 고르지 않았다.
        case nothingSelected
        /// 자동화 권한이 없다. 사용자가 직접 켜야 한다.
        case notAuthorized
        /// 그 밖의 실패.
        case failed(String)
    }

    private static let shortcutKey = "pathCopyShortcut"

    /// Finder 는 선택 항목을 줄바꿈으로 이어 돌려준다. 폴더의 뒤따르는 `/` 는 떼어낸다 —
    /// 터미널에 붙여넣을 때 거슬리고 Finder 기본 동작과도 다르다.
    private static let script = """
    tell application "Finder"
        set out to ""
        repeat with item_ in (get selection)
            set out to out & POSIX path of (item_ as alias) & linefeed
        end repeat
        return out
    end tell
    """

    @Published private(set) var shortcut: Shortcut?
    @Published private(set) var shortcutRegistered = true
    @Published private(set) var lastOutcome: Outcome?

    init() {
        shortcut = UserDefaults.standard.data(forKey: Self.shortcutKey)
            .flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) }
        applyShortcut()
    }

    // MARK: - 단축키

    func setShortcut(_ value: Shortcut?) {
        shortcut = value
        let defaults = UserDefaults.standard
        if let value, let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: Self.shortcutKey)
        } else {
            defaults.removeObject(forKey: Self.shortcutKey)
        }
        applyShortcut()
    }

    private func applyShortcut() {
        guard let shortcut else {
            HotKeyCenter.shared.unregister(.pathCopy)
            shortcutRegistered = true
            return
        }
        shortcutRegistered = HotKeyCenter.shared.register(shortcut, slot: .pathCopy) { [weak self] in
            self?.copyNow()
        }
    }

    // MARK: - 복사

    /// 선택 항목이 없으면 **클립보드를 건드리지 않는다.** 비워버리면 직전에 복사해둔 것을
    /// 잃는다. 실수로 눌렀을 때 잃는 것이 없어야 한다.
    func copyNow() {
        switch readSelection() {
        case .success(let paths) where paths.isEmpty:
            lastOutcome = .nothingSelected
        case .success(let paths):
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(paths.joined(separator: "\n"), forType: .string)
            lastOutcome = .copied(paths.count)
        case .failure(let outcome):
            lastOutcome = outcome
        }
    }

    private func readSelection() -> Result<[String], Outcome> {
        guard let script = NSAppleScript(source: Self.script) else {
            return .failure(.failed("NSAppleScript"))
        }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)

        if let error {
            let code = (error[NSAppleScript.errorNumber] as? Int) ?? 0
            // -1743: 사용자가 자동화를 허용하지 않았다.
            // -600 / -10814: Finder 가 떠 있지 않다. 재시도해도 소용없으니 같이 안내한다.
            if code == -1743 {
                return .failure(.notAuthorized)
            }
            let message = (error[NSAppleScript.errorMessage] as? String) ?? "\(code)"
            return .failure(.failed(message))
        }

        let paths = (result.stringValue ?? "")
            .components(separatedBy: .newlines)
            .map { $0.hasSuffix("/") ? String($0.dropLast()) : $0 }
            .filter { !$0.isEmpty }
        return .success(paths)
    }
}
