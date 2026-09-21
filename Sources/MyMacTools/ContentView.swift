import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// 상단 탭. 한 번에 한 기능만 보여준다.
enum Tab: String, CaseIterable, Identifiable {
    case screenOff
    case lid
    case cover

    var id: String { rawValue }

    var titleKey: L10n.Key {
        switch self {
        case .screenOff: return .tabScreenOff
        case .lid: return .tabLid
        case .cover: return .tabCover
        }
    }
}

struct ContentView: View {
    @ObservedObject var manager: BlackWorkManager
    @ObservedObject var lid: LidWorkManager
    @ObservedObject var cover: ScreenCoverManager
    @ObservedObject var caffeine: CaffeinateScanner
    @ObservedObject var l10n: L10n

    /// 중지에 실패한 이유. 성공하면 비운다.
    @State private var caffeineError: String?

    /// 마지막으로 본 탭. `L10n` 이 언어를 `UserDefaults` 에 담아두는 것과 같은 이유로,
    /// 주로 쓰는 기능이 다음 실행에 바로 나오게 한다.
    @AppStorage("selectedTab") private var selection: Tab = .screenOff

    var body: some View {
        VStack(spacing: Design.Spacing.none) {
            tabBar
                .padding(.horizontal, Design.Padding.tabBarHorizontal)
                .padding(.top, Design.Padding.tabBarTop)
                .padding(.bottom, Design.Padding.tabBarBottom)

            Divider()

            ScrollView {
                Group {
                    switch selection {
                    case .screenOff: screenOffTab
                    case .lid: lidTab
                    case .cover: coverTab
                    }
                }
                .padding(Design.Padding.content)
            }
            // 내용이 창에 들어가면 스크롤바도 바운스도 없다. 넘칠 때만 스크롤된다.
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(width: Design.Size.windowWidth, height: Design.Size.windowContentHeight, alignment: .top)
        // 값이 재부팅·강제 종료 뒤에도 남으므로, 창이 다시 앞으로 나올 때마다
        // 앱이 기억한 상태가 아니라 커널의 실제 값으로 맞춘다.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            lid.refreshFromSystem()
        }
        // 창을 닫았다 다시 열면 앱이 활성화된 뒤에 뷰가 만들어져 위 알림을 놓칠 수 있다.
        .onAppear { lid.refreshFromSystem() }
        // 카페인 목록은 **창이 보이는 동안만** 훑는다. 앱 생존에 묶으면, 창을 닫아도
        // 세션이 유지되게 바뀐 뒤로는 며칠 띄워둔 동안 계속 훑게 된다.
        .onAppear { caffeine.startPolling() }
        .onDisappear { caffeine.stopPolling() }
    }

    // MARK: - 탭바

    /// 탭 이름 옆의 점이 그 기능이 지금 돌고 있는지를 보여준다.
    ///
    /// 두 기능 모두 **시스템 상태**를 바꾸고, 덮개 기능은 앱을 꺼도 값이 남는다.
    /// 탭 뒤에 숨겨버리면 켜둔 사실이 화면 어디에도 없게 되므로, 어느 탭에 있든 보이게 한다.
    /// 점은 매니저의 `isRunning` 을 그대로 따라간다. 따로 기억하지 않는다.
    private var tabBar: some View {
        HStack(spacing: Design.Spacing.tabItem) {
            ForEach(Tab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    HStack(spacing: Design.Spacing.dotToLabel) {
                        Circle()
                            .fill(isRunning(tab) ? .green : .gray)
                            .frame(width: Design.Size.tabDot, height: Design.Size.tabDot)
                        Text(l10n(tab.titleKey))
                            .fontWeight(selection == tab ? .semibold : .regular)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Design.Padding.tabItemVertical)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background {
                    // `.accessoryBar` 같은 기성 스타일에 맡기지 않고 직접 그린다.
                    // 선택 표시가 확실히 나오고, 위의 상태 점 색도 죽지 않는다.
                    if selection == tab {
                        RoundedRectangle(cornerRadius: Design.Size.tabCornerRadius).fill(.quaternary)
                    }
                }
            }
        }
    }

    private func isRunning(_ tab: Tab) -> Bool {
        switch tab {
        case .screenOff: return manager.isRunning
        case .lid: return lid.isRunning
        case .cover: return cover.isCovering
        }
    }

    // MARK: - 화면 끄고 작업

    private var screenOffTab: some View {
        VStack(spacing: Design.Spacing.sleepBlock) {
            statusRow

            settings

            Button(l10n(manager.isRunning ? .buttonStop : .buttonStart)) {
                manager.toggle()
            }
            .keyboardShortcut(.defaultAction)

            progress

            Divider()

            caffeineSection
        }
    }

    // MARK: - 현재 실행중인 카페인

    /// 시스템에서 돌고 있는 `caffeinate` 를 전부 보여준다. 내가 켠 것만이 아니다.
    ///
    /// 내가 켠 것은 이미 상태행이 보여주므로, 이 목록의 값어치는 **모르게 돌고 있는 것**을
    /// 드러내는 데 있다. 그래서 부모 프로세스를 함께 그린다 — 부모를 숨기면 어느 앱이
    /// 띄운 것인지 알 수 없어, 이 기능을 만들게 된 오해를 그대로 반복한다.
    /// 근거는 `docs/plans/caffeinate-list/context.md`.
    private var caffeineSection: some View {
        DisclosureGroup(isExpanded: $caffeine.isExpanded) {
            VStack(alignment: .leading, spacing: Design.Spacing.caffeineItem) {
                if caffeine.processes.isEmpty {
                    Text(l10n(.caffeineEmpty))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(caffeine.processes) { process in
                        caffeineRow(process)
                    }
                }

                if let caffeineError {
                    Text(l10n(.caffeineStopFailed, caffeineError))
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Design.Spacing.caffeineItem)
        } label: {
            HStack(spacing: Design.Spacing.dotToLabel) {
                Text(l10n(.caffeineSectionTitle))
                    .font(.callout)
                // 접혀 있어도 몇 개가 돌고 있는지 보여야 목적을 달성한다.
                if !caffeine.processes.isEmpty {
                    Text("\(caffeine.processes.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func caffeineRow(_ process: CaffeinateProcess) -> some View {
        VStack(alignment: .leading, spacing: Design.Spacing.caffeineItemRow) {
            HStack(spacing: Design.Spacing.inRow) {
                Text("pid \(process.pid)")
                    .font(.caption.monospacedDigit())
                Spacer(minLength: 4)
                Text(elapsed(since: process.started))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if process.argsUnreadable {
                Text(l10n(.caffeineArgsUnreadable))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: Design.Spacing.caffeineChip) {
                    ForEach(process.flags) { flag in
                        caffeineChip(flag)
                    }
                }
            }

            if !process.utility.isEmpty {
                Text(l10n(.caffeineUtility, process.utility.joined(separator: " ")))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            // 이름은 사람이 읽을 것으로, 전체 경로는 툴팁으로 남긴다.
            Text(process.isOurs ? l10n(.caffeineOwnerThisApp) : process.parentName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .contentShape(Rectangle())
                .help(process.parentPath.isEmpty ? process.parentName : process.parentPath)
        }
        .padding(Design.Padding.caffeineItem)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Design.Size.caffeineItemCornerRadius)
                .fill(Color.primary.opacity(0.05)))
        .contextMenu {
            Button(l10n(.caffeineStop)) {
                caffeineError = caffeine.stop(process, manager: manager)
            }
            .disabled(!process.canStop)

            if !process.canStop {
                Text(l10n(.caffeineStopDenied))
            }
        }
    }

    @ViewBuilder
    private func caffeineChip(_ flag: CaffeinateFlag) -> some View {
        let chip = Text(flag.label)
            .font(.caption2.monospaced())
            .padding(.horizontal, Design.Padding.caffeineChipHorizontal)
            .padding(.vertical, Design.Padding.caffeineChipVertical)
            .background(
                RoundedRectangle(cornerRadius: Design.Size.caffeineChipCornerRadius)
                    .fill(Color.primary.opacity(0.1)))

        // 모르는 플래그는 설명을 달지 않는다. 지어낸 설명이 빈 칸보다 나쁘다.
        // `.help("")` 를 주는 대신 아예 붙이지 않는다.
        if let explanation = flag.explanation {
            chip
                // `Text` 의 히트 영역은 글자에 붙어 있어, 여백 위에서는 호버가 잡히지
                // 않는다. 칩 전체를 호버 영역으로 만들어야 툴팁이 뜬다.
                .contentShape(Rectangle())
                .help(l10n(explanation))
        } else {
            chip
        }
    }

    private func elapsed(since start: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(start)))
        if seconds < 60 { return "\(seconds)\(l10n(.unitSecond))" }
        if seconds < 3600 {
            return "\(seconds / 60)\(l10n(.unitMinute)) \(seconds % 60)\(l10n(.unitSecond))"
        }
        return "\(seconds / 3600)\(l10n(.unitHour)) \(seconds % 3600 / 60)\(l10n(.unitMinute))"
    }

    private var statusRow: some View {
        HStack {
            Circle()
                .fill(manager.isRunning ? .green : .gray)
                .frame(width: Design.Size.statusDot, height: Design.Size.statusDot)
            Text(l10n(statusKey))
                .font(.body)
        }
    }

    /// 화면 모드마다 사실이 다르다. "화면 꺼짐" 은 끄는 모드에서만 참이고,
    /// 맥북 기본설정대로 두는 모드는 언젠가 꺼지므로 "계속 켜짐" 이라고 할 수도 없다.
    private var statusKey: L10n.Key {
        guard manager.isRunning else { return .statusIdle }
        switch manager.screenMode {
        case .keepOff: return .statusWorking
        case .keepOn:  return .statusWorkingScreenOn
        case .system:  return .statusWorkingPlain
        }
    }

    private var settings: some View {
        VStack(spacing: Design.Spacing.settingsRow) {
            HStack(spacing: Design.Spacing.inRow) {
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

            // 셋이 서로 배타적이라 체크박스 여러 개가 아니라 목록 하나로 둔다.
            // 체크박스였다면 "끈 상태로 유지 + 계속 켜두기" 같은 모순 조합이 가능해진다.
            HStack(spacing: Design.Spacing.inRow) {
                Text(l10n(.labelScreenMode))
                Spacer(minLength: 4)
                Picker("", selection: $manager.screenMode) {
                    ForEach(BlackWorkManager.ScreenMode.allCases) { mode in
                        Text(l10n(mode.titleKey)).tag(mode)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }

            // 지연 시간은 화면을 끌 때만 의미가 있다.
            HStack(spacing: Design.Spacing.inRow) {
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
            .disabled(manager.screenMode != .keepOff)

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
        VStack(alignment: .leading, spacing: Design.Spacing.lidBlock) {
            // 이 VStack 은 주의사항 목록 때문에 leading 정렬이다. 상태 줄만은 잠자기 방지
            // 탭과 같게 가운데에 두어야 해서 폭을 끝까지 펴고 그 안에서 가운데 정렬한다.
            HStack {
                Circle()
                    .fill(lid.isRunning ? .green : .gray)
                    .frame(width: Design.Size.statusDot, height: Design.Size.statusDot)
                Text(l10n(lid.isRunning ? .lidStatusOn : .lidStatusOff))
                    .font(.body)
            }
            .frame(maxWidth: .infinity)

            // 유지 시간. 켜져 있는 동안에는 못 바꾼다.
            HStack(spacing: Design.Spacing.inRow) {
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

            // 잠자기 방지 탭과 같은 모양으로. 이 VStack 이 leading 정렬이라
            // 양쪽 Spacer 로 가운데에 둔다. `.frame(maxWidth:)` 을 버튼에 직접 걸면
            // 버튼 자체가 창 폭만큼 늘어나 모양이 달라진다.
            HStack {
                Spacer()
                Button(l10n(lid.isRunning ? .buttonStop : .buttonStart)) {
                    Actions.toggleLid(lid, manager)
                }
                Spacer()
            }
        }
    }

    /// 프로그램이 강제하지 않고 사용자가 지켜야 하는 것들. 항상 보이게 둔다.
    private static let cautionKeys: [L10n.Key] = [
        .lidCautionPower, .lidCautionHeat, .lidCautionSurface, .lidCautionStop,
    ]

    private var cautions: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.listRow) {
            HStack(spacing: Design.Spacing.tabItem) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(l10n(.lidCautionTitle))
                    .fontWeight(.medium)
            }
            ForEach(Self.cautionKeys, id: \.self) { key in
                HStack(alignment: .top, spacing: Design.Spacing.listRow) {
                    Text("•")
                    Text(l10n(key))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - 화면 가리기

    /// 잠금이 아니라는 것을 화면에서도 읽히게 둔다. 인증이 없는 것이 결함이 아니라
    /// 용도라는 점이 안 보이면, 자리를 비우는 보안 수단으로 잘못 쓰게 된다.
    private var coverTab: some View {
        VStack(spacing: Design.Spacing.sleepBlock) {
            HStack {
                Circle()
                    .fill(cover.isCovering ? .green : .gray)
                    .frame(width: Design.Size.statusDot, height: Design.Size.statusDot)
                Text(l10n(cover.isCovering ? .coverStatusOn : .coverStatusOff))
                    .font(.body)
            }

            VStack(spacing: Design.Spacing.settingsRow) {
                HStack(spacing: Design.Spacing.inRow) {
                    Text(l10n(.coverLabelImage))
                    Spacer(minLength: 4)
                    Button(l10n(.coverChooseImage), action: chooseImage)
                }

                // 고른 사진이 무엇인지 보이게 둔다. 전체 경로는 창 폭을 넘기므로 파일명만.
                Text(cover.imagePath.map { ($0 as NSString).lastPathComponent } ?? l10n(.coverNoImage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: Design.Spacing.inRow) {
                    Text(l10n(.coverLabelFillMode))
                    Spacer(minLength: 4)
                    Picker("", selection: $cover.fillMode) {
                        ForEach(ScreenCoverManager.FillMode.allCases) { mode in
                            Text(l10n(mode.titleKey)).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }

                HStack(spacing: Design.Spacing.inRow) {
                    Text(l10n(.coverLabelShortcut))
                    Spacer(minLength: 4)
                    ShortcutRecorder(
                        shortcut: cover.shortcut,
                        placeholder: l10n(.coverShortcutNone),
                        recordingLabel: l10n(.coverShortcutRecording),
                        onChange: cover.setShortcut)
                }

                Text(l10n(.coverShortcutHint))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(l10n(.coverNotALock))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if let path = cover.lastError {
                    Text(l10n(.coverImageError, (path as NSString).lastPathComponent))
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // 사진이 없으면 덮을 것이 없다.
            Button(l10n(cover.isCovering ? .buttonStop : .buttonStart)) {
                cover.toggle()
            }
            .disabled(cover.imagePath == nil)
        }
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        cover.setImage(path: url.path)
    }

    /// 남은 시간을 H:MM:SS 로 표시한다.
    private static func format(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }
}
