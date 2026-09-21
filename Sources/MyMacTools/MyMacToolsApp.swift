import SwiftUI
import AppKit

/// 종료를 가로채기 위한 델리게이트.
///
/// `BlackWorkManager` 는 자식 프로세스라 앱이 죽으면 같이 죽지만,
/// `LidWorkManager` 가 건드리는 `disablesleep` 은 시스템 설정이라 재부팅해도 남는다.
/// 켜진 채로 종료하면 맥이 영영 잠들지 않게 되므로 반드시 한 번 묻는다.
///
/// 이 앱이 켠 것이고 암호 없이 끌 수 있으면 묻지 않고 되돌린다. 그 외에는 묻는다.
/// 규칙이 없으면 끄는 것도 인증 창이 필요한데, 종료 중에는 그 창이 뜨지 않거나 사용자가
/// 취소할 수 있어 "될 때도 있고 안 될 때도 있는" 동작이 된다.
final class AppDelegate: NSObject, NSApplicationDelegate {
    var lid: LidWorkManager?
    var l10n: L10n?
    /// 상태 막대 항목. 창이 닫혀도 살아 있어야 하므로 델리게이트가 들고 있는다.
    var statusItem: StatusItemController?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let lid, let l10n else { return .terminateNow }

        // 기억해둔 값이 아니라 커널의 지금 값으로 판단한다. 마지막 활성화 이후에 밖에서
        // 켜졌다면 기억만 보고 그냥 종료해버려, 끌 수 없는 상태로 맥을 남기게 된다.
        lid.refreshFromSystem()
        guard lid.isRunning else { return .terminateNow }

        // 이 앱이 켠 것일 때만 말없이 되돌린다. 다른 도구가 켜둔 것을 앱 종료가
        // 조용히 꺼버리면 남의 상태를 망가뜨리는 것이다.
        if lid.turnedOnByThisProcess, lid.revertWithoutPrompting() {
            return .terminateNow
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = l10n(.quitTitle)
        alert.informativeText = l10n(.quitBody)
        alert.addButton(withTitle: l10n(.quitStopAndQuit))
        alert.addButton(withTitle: l10n(.quitAnyway))
        alert.addButton(withTitle: l10n(.quitCancel))

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            // 인증을 취소하거나 실패하면 켜진 채로 종료돼 버리므로 종료를 멈춘다.
            if case .changed(false) = lid.stop() { return .terminateNow }
            return .terminateCancel
        case .alertSecondButtonReturn:
            return .terminateNow
        default:
            return .terminateCancel
        }
    }
}

@main
struct MyMacToolsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    /// 창이 닫힌 뒤에도 다시 열 수 있게 하는 SwiftUI 동작.
    @Environment(\.openWindow) private var openWindowAction
    @StateObject private var manager = BlackWorkManager()
    @StateObject private var lid = LidWorkManager()
    @StateObject private var cover = ScreenCoverManager()
    @StateObject private var l10n = L10n()

    /// `창 열기` 가 닫힌 창을 다시 띄우려면 id 가 필요하다.
    static let mainWindowID = "main"

    /// 상태 막대 항목을 한 번만 만든다.
    ///
    /// `openWindow` 는 SwiftUI 환경 값이라 뷰 안에서만 꺼낼 수 있다. 여기서 클로저로
    /// 잡아두면 **창이 닫힌 뒤에도** 메뉴의 `창 열기` 가 동작한다.
    @MainActor
    private func installStatusItem() {
        guard appDelegate.statusItem == nil else { return }
        appDelegate.statusItem = StatusItemController(
            manager: manager, lid: lid, cover: cover, l10n: l10n,
            openWindow: { openWindowAction(id: Self.mainWindowID) })
    }

    var body: some Scene {
        WindowGroup(id: Self.mainWindowID) {
            ContentView(manager: manager, lid: lid, cover: cover, l10n: l10n)
                .onAppear {
                    appDelegate.lid = lid
                    appDelegate.l10n = l10n
                    // 커버 화면의 문구도 선택한 언어를 따라야 한다.
                    cover.use(l10n)
                    installStatusItem()
                }
        }
        .windowResizability(.contentSize)
        .commands {
            // 언어 선택은 메인 창이 아니라 상단 메뉴바에 둔다.
            CommandMenu(l10n(.labelLanguage)) {
                Picker(l10n(.labelLanguage), selection: $l10n.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName(l10n)).tag(language)
                    }
                }
                .pickerStyle(.inline)
            }
        }
    }
}
