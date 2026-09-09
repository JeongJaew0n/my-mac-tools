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
    }
}
