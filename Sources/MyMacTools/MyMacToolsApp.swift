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
    /// API 소켓 서버. 같은 이유로 여기에 둔다.
    var api: APIServer?

    /// 종료할 때 소켓 파일을 치운다. 남겨두면 다음 실행이 낡은 파일 위에 bind 하려 한다.
    func applicationWillTerminate(_ notification: Notification) {
        api?.stop()
    }

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
    @StateObject private var caffeine = CaffeinateScanner()
    @StateObject private var localhost = LocalhostManager()
    @StateObject private var l10n = L10n()

    /// `창 열기` 가 닫힌 창을 다시 띄우려면 id 가 필요하다.
    static let mainWindowID = "main"

    /// 툴팁이 뜨기까지의 지연(밀리초).
    ///
    /// AppKit 기본값은 공개돼 있지 않아 코드로 읽을 수 없다. 문서에 적힌 1초의 절반으로
    /// 잡았다. 카페인 목록의 옵션 칩처럼 **여러 개를 훑어보는** 자리에서는 기본 지연이
    /// 길어, 칩 하나하나 확인하려면 매번 기다려야 한다.
    private static let toolTipDelayMilliseconds = 500

    init() {
        // 등록 도메인은 우선순위가 가장 낮다. 사용자가
        // `defaults write com.jjw.mymactools NSInitialToolTipDelay <값>` 으로 덮어쓰면
        // 그 값이 이긴다.
        UserDefaults.standard.register(defaults: [
            "NSInitialToolTipDelay": Self.toolTipDelayMilliseconds
        ])
    }

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

    /// API 서버를 한 번만 띄운다.
    ///
    /// 창이 닫혀도 살아 있어야 하므로 델리게이트가 들고 있는다. 에이전트가 부르는 시점에
    /// 창이 열려 있을 이유가 없다.
    @MainActor
    private func installAPIServer() {
        guard appDelegate.api == nil else { return }
        let handler = APIHandler(sleep: manager, lid: lid, cover: cover,
                                 caffeine: caffeine, localhost: localhost)
        let server = APIServer(handler: handler)
        server.start()
        appDelegate.api = server
    }

    var body: some Scene {
        WindowGroup(id: Self.mainWindowID) {
            ContentView(manager: manager, lid: lid, cover: cover, caffeine: caffeine,
                        localhost: localhost, l10n: l10n)
                .onAppear {
                    appDelegate.lid = lid
                    appDelegate.l10n = l10n
                    // 커버 화면의 문구도 선택한 언어를 따라야 한다.
                    cover.use(l10n)
                    installStatusItem()
                    installAPIServer()
                }
        }
        // `.contentSize` 는 내용의 ideal 크기로 창을 **못 박는다.** 사용자가 끌어도 안 움직인다.
        // `.contentMinSize` 는 최소만 지키고 그 위로는 자유롭게 놔둔다.
        .windowResizability(.contentMinSize)
        // `.contentMinSize` 로 바꾸면 뷰의 `idealWidth/Height` 가 무시되고 SwiftUI 기본
        // 900x450 으로 열린다. 처음 크기는 이쪽으로 지정해야 한다.
        // (창 위치·크기는 그 뒤 macOS 가 알아서 기억한다.)
        .defaultSize(width: Design.Size.windowWidth,
                     height: Design.Size.windowContentHeight + Design.Size.titleBarHeight)
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
