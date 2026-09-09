import SwiftUI

@main
struct MyMacToolsApp: App {
    @StateObject private var manager = BlackWorkManager()
    @StateObject private var l10n = L10n()

    var body: some Scene {
        WindowGroup {
            ContentView(manager: manager, l10n: l10n)
                .onDisappear {
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
