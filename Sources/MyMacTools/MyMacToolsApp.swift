import SwiftUI

@main
struct MyMacToolsApp: App {
    @StateObject private var manager = BlackWorkManager()

    var body: some Scene {
        WindowGroup {
            ContentView(manager: manager)
                .onDisappear {
                    manager.stop()
                }
        }
        .windowResizability(.contentSize)
    }
}
