import SwiftUI

struct ContentView: View {
    @ObservedObject var caffeinateManager: CaffeinateManager

    var body: some View {
        VStack(spacing: 16) {
            Text("DeskMate")
                .font(.title2)
                .fontWeight(.bold)

            HStack {
                Circle()
                    .fill(caffeinateManager.isRunning ? .green : .gray)
                    .frame(width: 10, height: 10)
                Text(caffeinateManager.isRunning ? "Caffeinate ON" : "Caffeinate OFF")
                    .font(.body)
            }

            Toggle("Caffeinate", isOn: Binding(
                get: { caffeinateManager.isRunning },
                set: { _ in caffeinateManager.toggle() }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .padding(24)
        .frame(width: 200)
    }
}
