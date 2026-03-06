import SwiftUI

@main
struct MyMacToolsApp: App {
    @StateObject private var caffeinateManager = CaffeinateManager()

    var body: some Scene {
        WindowGroup {
            ContentView(caffeinateManager: caffeinateManager)
                .onDisappear {
                    caffeinateManager.stop()
                }
        }
        .windowResizability(.contentSize)
    }
}
