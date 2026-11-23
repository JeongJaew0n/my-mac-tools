import AppKit
import Carbon
import SwiftUI

/// Tool: 캡처 편집. 클립보드의 그림을 작은 창에서 고쳐 다시 클립보드에 넣는다.
///
/// 클립보드는 **누를 때만** 읽는다. 감시하지 않는다. 화면 기록·손쉬운 사용·알림 권한을 쓰지 않는다 —
/// 클립보드 읽기·쓰기와 Carbon 단축키뿐이다. 근거는 `docs/plans/capture-edit/spec.md`.
final class CaptureEditManager: ObservableObject {

    /// 마지막으로 연 결과. Tool 탭이 보여준다.
    enum LastResult: Equatable {
        case copied(Date)
        case noImage
        case copyFailed
    }

    /// `open()` 의 결과. API 가 돌려준다.
    enum OpenResult: String {
        case opened
        /// 이미 열려 있어 앞으로 냈다. 그리던 것을 말없이 버리지 않으려고 새 그림으로 바꾸지 않는다.
        case alreadyOpen
        case noImage
    }

    static let shortcutKey = "captureEditShortcut"
    /// 사용자가 단축키를 지웠는가. 지운 것과 저장한 적 없는 것을 가르지 않으면 지운 기본 단축키가 다음 실행에 되살아난다.
    static let shortcutClearedKey = "captureEditShortcutCleared"
    /// 저장한 적이 없을 때 쓰는 단축키. macOS 기본 단축키와 겹치지 않는다(시스템 단축키 목록 확인).
    static let defaultShortcut = Shortcut(
        keyCode: UInt16(kVK_ANSI_E),
        modifiers: NSEvent.ModifierFlags([.control, .command, .shift]).rawValue,
        displayKey: "E")

    @Published private(set) var shortcut: Shortcut?
    @Published private(set) var isEditing = false
    @Published private(set) var lastResult: LastResult?

    private var l10n: L10n?
    private var editor: CaptureEditorWindow?
    private var notice: NSPanel?

    init() {
        let saved = Self.savedShortcut()
        let outcome = HotKeyCenter.shared.set(saved, for: .captureEdit) { [weak self] in self?.open() }
        // 기본 단축키를 다른 자리가 이미 쓰면 걸지 않는다. 화면에 걸린 것처럼 보이면 안 된다.
        shortcut = outcome == .done ? saved : nil
    }

    /// 창과 안내 창의 문구를 위해 현재 언어를 넘겨받는다.
    func use(_ l10n: L10n) {
        self.l10n = l10n
    }

    static func savedShortcut(_ defaults: UserDefaults = .standard) -> Shortcut? {
        if defaults.bool(forKey: shortcutClearedKey) { return nil }
        let stored = defaults.data(forKey: shortcutKey).flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) }
        return stored ?? defaultShortcut
    }

    /// `nil` 이면 지운다. 걸리지 않았으면 저장도 표시도 바꾸지 않는다.
    @discardableResult
    func setShortcut(_ value: Shortcut?) -> HotKeyCenter.Outcome {
        let outcome = HotKeyCenter.shared.set(value, for: .captureEdit) { [weak self] in self?.open() }
        guard outcome == .done else { return outcome }
        shortcut = value
        Shortcut.save(value, key: Self.shortcutKey)
        UserDefaults.standard.set(value == nil, forKey: Self.shortcutClearedKey)
        return outcome
    }

    /// 클립보드의 그림을 편집 창으로 연다. 그림이 없으면 잠깐 안내하고 끝낸다.
    @discardableResult
    func open() -> OpenResult {
        if let editor {
            editor.bringToFront()
            return .alreadyOpen
        }
        guard let image = CaptureImage.read(from: .general) else {
            lastResult = .noImage
            showNotice(text(.captureNoImage))
            return .noImage
        }
        let document = CaptureDocument(image: image)
        let window = CaptureEditorWindow(document: document, l10n: l10n ?? L10n()) { [weak self] outcome in
            self?.finish(outcome)
        }
        editor = window
        isEditing = true
        window.show()
        return .opened
    }

    private func finish(_ outcome: CaptureEditorWindow.Outcome) {
        editor = nil
        isEditing = false
        switch outcome {
        case .copied: lastResult = .copied(Date())
        case .copyFailed:
            lastResult = .copyFailed
            showNotice(text(.captureCopyFailed))
        case .cancelled: break
        }
    }

    private func text(_ key: L10n.Key) -> String {
        (l10n ?? L10n())(key)
    }

    // MARK: - 안내 창

    /// 화면 가운데에 잠깐 떴다 사라지는 작은 창. 알림 센터는 알림 권한을 물어서 쓰지 않는다.
    /// 누르는 것을 막지 않고(마우스를 통과시킨다) 앱을 앞으로 가져오지도 않는다.
    private func showNotice(_ message: String) {
        notice?.orderOut(nil)
        let hosting = NSHostingView(rootView: CaptureNoticeView(message: message))
        hosting.frame.size = hosting.fittingSize
        let panel = NSPanel(contentRect: hosting.frame, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = hosting
        if let screen = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: screen.midX - hosting.frame.width / 2,
                                         y: screen.midY - hosting.frame.height / 2))
        }
        panel.orderFrontRegardless()
        notice = panel
        DispatchQueue.main.asyncAfter(deadline: .now() + Design.Capture.noticeSeconds) { [weak self, weak panel] in
            panel?.orderOut(nil)
            if self?.notice === panel { self?.notice = nil }
        }
    }
}

/// 안내 창의 내용. 음량 표시처럼 반투명 판에 한 줄.
struct CaptureNoticeView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.headline)
            .padding(Design.Inset.panel)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Design.Radius.panel))
            .fixedSize()
    }
}
