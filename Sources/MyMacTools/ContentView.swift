import SwiftUI

struct ContentView: View {
    @ObservedObject var caffeinateManager: CaffeinateManager

    var body: some View {
        VStack(spacing: 16) {
            Text("MyMacTools")
                .font(.title2)
                .fontWeight(.bold)

            HStack {
                Circle()
                    .fill(caffeinateManager.isRunning ? .green : .gray)
                    .frame(width: 10, height: 10)
                Text(caffeinateManager.isRunning ? "Caffeinate ON" : "Caffeinate OFF")
                    .font(.body)
            }

            HStack(spacing: 8) {
                Picker("Hours", selection: $caffeinateManager.hours) {
                    ForEach(CaffeinateManager.hourOptions, id: \.self) { hour in
                        Text("\(hour)").tag(hour)
                    }
                }
                .labelsHidden()
                Text("h")
                    .foregroundStyle(.secondary)

                Picker("Minutes", selection: $caffeinateManager.minutes) {
                    ForEach(CaffeinateManager.minuteOptions, id: \.self) { minute in
                        Text(String(format: "%02d", minute)).tag(minute)
                    }
                }
                .labelsHidden()
                Text("m")
                    .foregroundStyle(.secondary)
            }
            .disabled(caffeinateManager.isRunning)

            Text(caffeinateManager.durationSeconds == nil ? "0h 00m = Unlimited" : "Auto off after the selected time")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Caffeinate", isOn: Binding(
                get: { caffeinateManager.isRunning },
                set: { _ in caffeinateManager.toggle() }
            ))
            .toggleStyle(.switch)
            .labelsHidden()

            if let remaining = caffeinateManager.remaining {
                Text(Self.format(remaining))
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(width: 280)
    }

    /// 남은 시간을 H:MM:SS 로 표시한다.
    private static func format(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }
}
