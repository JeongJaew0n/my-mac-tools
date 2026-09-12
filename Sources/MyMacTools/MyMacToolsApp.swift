import SwiftUI
import AppKit

/// 종료를 가로채기 위한 델리게이트.
///
/// `BlackWorkManager` 는 자식 프로세스라 앱이 죽으면 같이 죽지만,
/// `LidWorkManager` 가 건드리는 `disablesleep` 은 시스템 설정이라 재부팅해도 남는다.
/// 켜진 채로 종료하면 맥이 영영 잠들지 않게 되므로 반드시 한 번 묻는다.
///
/// sudoers 규칙이 깔려 있으면 암호 없이 끌 수 있으므로 묻지 않고 조용히 되돌린다.
/// 규칙이 없으면 끄는 것도 인증 창이 필요한데, 종료 중에는 그 창이 뜨지 않거나 사용자가
/// 취소할 수 있어 "될 때도 있고 안 될 때도 있는" 동작이 된다. 그때만 명시적으로 묻는다.
final class AppDelegate: NSObject, NSApplicationDelegate {
    var lid: LidWorkManager?
    var l10n: L10n?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let lid, let l10n, lid.isRunning else { return .terminateNow }

        // 조용히 되돌릴 수 있으면 먼저 시도한다.
        // `canRevertSilently` 는 sudo 자격 캐시 때문에 거짓 양성일 수 있으므로
        // 실제로 꺼졌는지 확인하고, 실패했으면 아래 경고로 넘어간다.
        if lid.canRevertSilently, case .changed(false) = lid.stop() {
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
    @StateObject private var manager = BlackWorkManager()
    @StateObject private var lid = LidWorkManager()
    @StateObject private var l10n = L10n()

    var body: some Scene {
        WindowGroup {
            ContentView(manager: manager, lid: lid, l10n: l10n)
                .onAppear {
                    appDelegate.lid = lid
                    appDelegate.l10n = l10n
                }
                .onDisappear {
                    // 창을 닫으면 화면 끄기 세션만 정리한다. 덮개 기능은 시스템 설정이라
                    // 창 개폐와 수명을 같이하지 않는다 — 종료 시 경고로 처리한다.
                    manager.stop()
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
