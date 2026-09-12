import SwiftUI

struct ContentView: View {
    @ObservedObject var manager: BlackWorkManager
    @ObservedObject var lid: LidWorkManager
    @ObservedObject var l10n: L10n

    var body: some View {
        VStack(spacing: 16) {
            Text("MyMacTools")
                .font(.title2)
                .fontWeight(.bold)

            statusRow

            settings

            Button(l10n(manager.isRunning ? .buttonStop : .buttonStart)) {
                manager.toggle()
            }
            .keyboardShortcut(.defaultAction)

            progress

            Divider()

            lidSection
        }
        .padding(24)
        .frame(width: 320)
        // 값이 재부팅·강제 종료 뒤에도 남으므로, 창이 다시 앞으로 나올 때마다
        // 앱이 기억한 상태가 아니라 커널의 실제 값으로 맞춘다.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            lid.refreshFromSystem()
        }
        // 창을 닫았다 다시 열면 앱이 활성화된 뒤에 뷰가 만들어져 위 알림을 놓칠 수 있다.
        .onAppear { lid.refreshFromSystem() }
    }

    // MARK: - Sections

    private var statusRow: some View {
        HStack {
            Circle()
                .fill(manager.isRunning ? .green : .gray)
                .frame(width: 10, height: 10)
            Text(l10n(manager.isRunning ? .statusWorking : .statusIdle))
                .font(.body)
        }
    }

    private var settings: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text(l10n(.labelKeepWorking))
                Spacer(minLength: 4)
                Picker("", selection: $manager.hours) {
                    ForEach(BlackWorkManager.hourOptions, id: \.self) { hour in
                        Text("\(hour)").tag(hour)
                    }
                }
                .labelsHidden()
                .fixedSize()
                Text(l10n(.unitHour))
                    .foregroundStyle(.secondary)
                Picker("", selection: $manager.minutes) {
                    ForEach(BlackWorkManager.minuteOptions, id: \.self) { minute in
                        Text(String(format: "%02d", minute)).tag(minute)
                    }
                }
                .labelsHidden()
                .fixedSize()
                Text(l10n(.unitMinute))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Text(l10n(.labelScreenOffIn))
                Spacer(minLength: 4)
                Picker("", selection: $manager.displayDelaySeconds) {
                    ForEach(BlackWorkManager.displayDelayOptions, id: \.self) { seconds in
                        Text("\(seconds)").tag(seconds)
                    }
                }
                .labelsHidden()
                .fixedSize()
                Text(l10n(.unitSecond))
                    .foregroundStyle(.secondary)
            }

            Toggle(l10n(.toggleKeepScreenOff), isOn: $manager.keepScreenOff)

            // 덮개 기능이 켜져 있으면 `pmset sleepnow` 가 kIOReturnNotPermitted 로 거부된다.
            // 눌러도 아무 일이 없으므로 아예 잠가두고 caption 으로 이유를 알린다.
            Toggle(l10n(.toggleSleepWhenDone), isOn: $manager.sleepWhenDone)
                .disabled(manager.durationSeconds == nil || lid.isRunning)

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
            return l10n(.captionUnlimited)
        }
        // sleepWhenDone 이 꺼져 있어도 "평소 절전 동작으로 돌아갑니다" 는 거짓이다.
        // disablesleep=1 이면 시스템 잠자기 자체가 막혀 있다.
        if lid.isRunning {
            return l10n(.captionSleepBlockedByLid)
        }
        return manager.sleepWhenDone ? l10n(.captionWillSleep) : l10n(.captionNormalSleep)
    }

    /// 덮개를 닫아도 작업을 계속하는 기능. 위 세션과 독립이라 동시에 켤 수 있다.
    private var lidSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(lid.isRunning ? .green : .gray)
                    .frame(width: 10, height: 10)
                Text(l10n(.lidTitle))
                    .fontWeight(.medium)
            }

            Text(l10n(lid.isRunning ? .lidStatusOn : .lidStatusOff))
                .font(.caption)
                .foregroundStyle(.secondary)

            // 유지 시간. 켜져 있는 동안에는 못 바꾼다.
            HStack(spacing: 8) {
                Text(l10n(.labelKeepWorking))
                Spacer(minLength: 4)
                Picker("", selection: $lid.hours) {
                    ForEach(LidWorkManager.hourOptions, id: \.self) { hour in
                        Text("\(hour)").tag(hour)
                    }
                }
                .labelsHidden()
                .fixedSize()
                Text(l10n(.unitHour))
                    .foregroundStyle(.secondary)
                Picker("", selection: $lid.minutes) {
                    ForEach(LidWorkManager.minuteOptions, id: \.self) { minute in
                        Text(String(format: "%02d", minute)).tag(minute)
                    }
                }
                .labelsHidden()
                .fixedSize()
                Text(l10n(.unitMinute))
                    .foregroundStyle(.secondary)
            }
            .disabled(lid.isRunning)

            if lid.durationSeconds == nil {
                Text(l10n(.captionUnlimited))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            cautions

            if let remaining = lid.remaining {
                Text(l10n(.progressRemaining, Self.format(remaining)))
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if lid.autoStopFailed {
                Text(l10n(.lidAutoStopFailed))
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let error = lid.lastError {
                Text(l10n(.lidError, error))
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(l10n(lid.isRunning ? .buttonStop : .buttonStart)) {
                if case .changed(true) = lid.toggle() {
                    // 켜는 데 성공했으면 "끝나면 잠자기"를 끈다. 토글이 비활성화될 뿐
                    // 값은 남아 있어서, 그대로 두면 만료 시 `pmset sleepnow` 가
                    // kIOReturnNotPermitted 로 거부되고 아무 일도 없는 것처럼 보인다.
                    manager.sleepWhenDone = false
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// 프로그램이 강제하지 않고 사용자가 지켜야 하는 것들. 항상 보이게 둔다.
    private static let cautionKeys: [L10n.Key] = [
        .lidCautionPower, .lidCautionHeat, .lidCautionSurface, .lidCautionStop,
    ]

    private var cautions: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(l10n(.lidCautionTitle))
                    .fontWeight(.medium)
            }
            ForEach(Self.cautionKeys, id: \.self) { key in
                HStack(alignment: .top, spacing: 5) {
                    Text("•")
                    Text(l10n(key))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var progress: some View {
        if let countdown = manager.displayCountdown {
            Text(l10n(.progressScreenOff, countdown))
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.orange)
        } else if let grace = manager.screenGraceRemaining {
            Text(l10n(.progressReblank, grace))
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.orange)
        } else if manager.keepScreenOffGaveUp {
            Text(l10n(.statusKeepOffFailed))
                .font(.callout)
                .foregroundStyle(.red)
        } else if let remaining = manager.remaining {
            Text(l10n(.progressRemaining, Self.format(remaining)))
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
        } else if manager.isRunning {
            Text(l10n(.progressNoLimit))
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
