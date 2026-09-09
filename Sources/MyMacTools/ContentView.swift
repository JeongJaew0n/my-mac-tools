import SwiftUI

struct ContentView: View {
    @ObservedObject var manager: BlackWorkManager

    var body: some View {
        VStack(spacing: 16) {
            Text("MyMacTools")
                .font(.title2)
                .fontWeight(.bold)

            statusRow

            settings

            Button(manager.isRunning ? "Stop" : "Start") {
                manager.toggle()
            }
            .keyboardShortcut(.defaultAction)

            progress
        }
        .padding(24)
        .frame(width: 300)
    }

    // MARK: - Sections

    private var statusRow: some View {
        HStack {
            Circle()
                .fill(manager.isRunning ? .green : .gray)
                .frame(width: 10, height: 10)
            Text(manager.isRunning ? "Working — screen off" : "Idle")
                .font(.body)
        }
    }

    private var settings: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text("Keep working")
                    .frame(width: 96, alignment: .leading)
                Picker("Hours", selection: $manager.hours) {
                    ForEach(BlackWorkManager.hourOptions, id: \.self) { hour in
                        Text("\(hour)").tag(hour)
                    }
                }
                .labelsHidden()
                Text("h")
                    .foregroundStyle(.secondary)
                Picker("Minutes", selection: $manager.minutes) {
                    ForEach(BlackWorkManager.minuteOptions, id: \.self) { minute in
                        Text(String(format: "%02d", minute)).tag(minute)
                    }
                }
                .labelsHidden()
                Text("m")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Text("Screen off in")
                    .frame(width: 96, alignment: .leading)
                Picker("Delay", selection: $manager.displayDelaySeconds) {
                    ForEach(BlackWorkManager.displayDelayOptions, id: \.self) { seconds in
                        Text("\(seconds)").tag(seconds)
                    }
                }
                .labelsHidden()
                Text("sec")
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Toggle("Sleep when time is up", isOn: $manager.sleepWhenDone)
                .disabled(manager.durationSeconds == nil)

            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .disabled(manager.isRunning)
    }

    private var caption: String {
        if manager.durationSeconds == nil {
            return "0h 00m = keep going until you press Stop"
        }
        return manager.sleepWhenDone
            ? "The Mac sleeps when the time is up"
            : "Sleep behaviour returns to normal when the time is up"
    }

    @ViewBuilder
    private var progress: some View {
        if let countdown = manager.displayCountdown {
            Text("Screen turns off in \(countdown)s")
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.orange)
        } else if let remaining = manager.remaining {
            Text("\(Self.format(remaining)) left")
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
        } else if manager.isRunning {
            Text("no time limit")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    /// 남은 시간을 H:MM:SS 로 표시한다.
    private static func format(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }
}
