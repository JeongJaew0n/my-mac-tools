import SwiftUI
import AppKit

/// 상태 막대 아이콘을 눌렀을 때 내려오는 메뉴.
///
/// 설정은 다루지 않는다. 유지 시간이나 사진 고르기는 창에서 한다. 여기서는 **지금 무엇이
/// 돌고 있는지 보이는 것**과 **켜고 끄는 것**만 맡는다.
struct MenuBarContent: View {
    @ObservedObject var manager: BlackWorkManager
    @ObservedObject var lid: LidWorkManager
    @ObservedObject var cover: ScreenCoverManager
    @ObservedObject var l10n: L10n

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // 색 점 대신 `Toggle` 을 쓴다. 메뉴는 이미지를 template 으로 렌더링해 녹색이
        // 회색으로 죽을 수 있고, 메뉴에서는 체크마크가 관례다.
        Toggle(l10n(.tabScreenOff), isOn: Binding(
            get: { manager.isRunning },
            set: { _ in manager.toggle() }))

        Toggle(l10n(.tabLid), isOn: Binding(
            get: { lid.isRunning },
            set: { _ in Actions.toggleLid(lid, manager) }))

        // 사진이 없으면 덮을 것이 없다. 창에서 고르게 한다.
        Toggle(l10n(.tabCover), isOn: Binding(
            get: { cover.isCovering },
            set: { _ in cover.toggle() }))
            .disabled(cover.imagePath == nil && !cover.isCovering)

        Divider()

        Button(l10n(.menuOpenWindow)) {
            openWindow(id: MyMacToolsApp.mainWindowID)
            // 창만 띄우면 다른 앱 뒤에 열릴 수 있다.
            NSApp.activate(ignoringOtherApps: true)
        }

        Button(l10n(.menuQuit)) {
            // terminate 로 보내야 덮개가 켜진 채 종료되는 것을 막는 경고를 거친다.
            NSApp.terminate(nil)
        }
    }
}
