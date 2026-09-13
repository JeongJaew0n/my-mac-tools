import SwiftUI

/// 상단 탭. 한 번에 한 기능만 보여준다.
enum Tab: String, CaseIterable, Identifiable {
    case screenOff
    case lid

    var id: String { rawValue }

    var titleKey: L10n.Key {
        switch self {
        case .screenOff: return .tabScreenOff
        case .lid: return .tabLid
        }
    }
}

struct ContentView: View {
    @ObservedObject var manager: BlackWorkManager
    @ObservedObject var lid: LidWorkManager
    @ObservedObject var l10n: L10n

    /// 마지막으로 본 탭. `L10n` 이 언어를 `UserDefaults` 에 담아두는 것과 같은 이유로,
    /// 주로 쓰는 기능이 다음 실행에 바로 나오게 한다.
    @AppStorage("selectedTab") private var selection: Tab = .screenOff

    /// 창 높이. 탭마다 내용 높이가 달라 그대로 두면 전환할 때마다 창이 튄다.
    ///
    /// 실측(2026-09-13): 화면 끄기 탭 325, 덮개 탭 368. 긴 쪽에 여유를 더해 잡았다.
    /// `minHeight` 로는 안 된다 — `.windowResizability(.contentSize)` 는 내용의 *ideal*
    /// 크기를 쓰므로 최소치를 줘도 창이 커지지 않는다. 그래서 높이를 고정하고,
    /// 대신 내용을 `ScrollView` 로 감싸 오류 문구가 늘어나도 잘리지 않게 한다.
    private static let windowHeight: CGFloat = 380

    var body: some View {
        VStack(spacing: 0) {
            tabBar
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 8)

            Divider()

            ScrollView {
                Group {
                    switch selection {
                    case .screenOff: screenOffTab
                    case .lid: lidTab
                    }
                }
                .padding(20)
            }
            // 내용이 창에 들어가면 스크롤바도 바운스도 없다. 넘칠 때만 스크롤된다.
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(width: 320, height: Self.windowHeight, alignment: .top)
        // 값이 재부팅·강제 종료 뒤에도 남으므로, 창이 다시 앞으로 나올 때마다
        // 앱이 기억한 상태가 아니라 커널의 실제 값으로 맞춘다.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            lid.refreshFromSystem()
        }
        // 창을 닫았다 다시 열면 앱이 활성화된 뒤에 뷰가 만들어져 위 알림을 놓칠 수 있다.
        .onAppear { lid.refreshFromSystem() }
    }

    // MARK: - 탭바

    /// 탭 이름 옆의 점이 그 기능이 지금 돌고 있는지를 보여준다.
    ///
    /// 두 기능 모두 **시스템 상태**를 바꾸고, 덮개 기능은 앱을 꺼도 값이 남는다.
    /// 탭 뒤에 숨겨버리면 켜둔 사실이 화면 어디에도 없게 되므로, 어느 탭에 있든 보이게 한다.
    /// 점은 매니저의 `isRunning` 을 그대로 따라간다. 따로 기억하지 않는다.
    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isRunning(tab) ? .green : .gray)
                            .frame(width: 8, height: 8)
                        Text(l10n(tab.titleKey))
                            .fontWeight(selection == tab ? .semibold : .regular)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background {
                    // `.accessoryBar` 같은 기성 스타일에 맡기지 않고 직접 그린다.
                    // 선택 표시가 확실히 나오고, 위의 상태 점 색도 죽지 않는다.
                    if selection == tab {
                        RoundedRectangle(cornerRadius: 6).fill(.quaternary)
                    }
                }
            }
        }
    }

    private func isRunning(_ tab: Tab) -> Bool {
        switch tab {
        case .screenOff: return manager.isRunning
        case .lid: return lid.isRunning
        }
    }

    // MARK: - 화면 끄고 작업

    private var screenOffTab: some View {
        VStack(spacing: 16) {
            statusRow

            settings

            Button(l10n(manager.isRunning ? .buttonStop : .buttonStart)) {
                manager.toggle()
            }
            .keyboardShortcut(.defaultAction)

            progress
        }
    }

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
            // 잠긴 이유가 다른 탭에 있지만 caption 이 기능 이름을 직접 부르므로
            // 탭을 옮기지 않아도 읽을 수 있다.
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

    // MARK: - 덮개 닫아도 작업 진행

    /// 기능 이름은 탭 라벨이 지니므로 여기서 다시 제목을 달지 않는다.
    /// 대신 위 탭과 같은 모양의 상태 줄로 시작한다.
    private var lidTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(lid.isRunning ? .green : .gray)
                    .frame(width: 10, height: 10)
                Text(l10n(lid.isRunning ? .lidStatusOn : .lidStatusOff))
                    .font(.body)
            }

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

    /// 남은 시간을 H:MM:SS 로 표시한다.
    private static func format(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }
}
