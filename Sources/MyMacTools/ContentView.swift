import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// 상단 탭. 한 번에 한 기능만 보여준다.
enum Tab: String, CaseIterable, Identifiable {
    case screenOff
    case lid
    case cover
    case localhost

    var id: String { rawValue }

    var titleKey: L10n.Key {
        switch self {
        case .screenOff: return .tabScreenOff
        case .lid: return .tabLid
        case .cover: return .tabCover
        case .localhost: return .tabLocalhost
        }
    }

    /// 탭 아이콘. 상태 점 자리를 대신한다 — 320pt 에 탭 넷이라
    /// 점·아이콘·글자를 다 넣을 자리가 없다.
    var symbol: String {
        switch self {
        case .screenOff: return "cup.and.saucer.fill"   // caffeinate
        case .lid: return "laptopcomputer"              // 덮개
        case .cover: return "photo.fill"                // 사진으로 가리기
        case .localhost: return "network"               // 포트
        }
    }
}

struct ContentView: View {
    @ObservedObject var manager: BlackWorkManager
    @ObservedObject var lid: LidWorkManager
    @ObservedObject var cover: ScreenCoverManager
    @ObservedObject var caffeine: CaffeinateScanner
    @ObservedObject var localhost: LocalhostManager
    @ObservedObject var l10n: L10n

    /// 중지에 실패한 이유. 성공하면 비운다.
    @State private var caffeineError: String?

    /// 마지막으로 본 탭. `L10n` 이 언어를 `UserDefaults` 에 담아두는 것과 같은 이유로,
    /// 주로 쓰는 기능이 다음 실행에 바로 나오게 한다.
    @AppStorage("selectedTab") private var selection: Tab = .screenOff

    var body: some View {
        VStack(spacing: Design.Space.none) {
            tabBar
                .padding(.horizontal, Design.Inset.navX)
                .padding(.top, Design.Inset.navTop)
                .padding(.bottom, Design.Inset.navBottom)

            Divider()

            ScrollView {
                Group {
                    switch selection {
                    case .screenOff: screenOffTab
                    case .lid: lidTab
                    case .cover: coverTab
                    case .localhost: localhostTab
                    }
                }
                .padding(Design.Inset.screen)
            }
            // 내용이 창에 들어가면 스크롤바도 바운스도 없다. 넘칠 때만 스크롤된다.
            .scrollBounceBehavior(.basedOnSize)
        }
        // 고정이 아니라 **기본값 + 최소값**이다. 사용자가 창을 늘리고 줄일 수 있다.
        // `ideal` 이 처음 열릴 때의 크기가 되므로, 탭을 바꿔도 창이 튀지 않는 성질은 그대로다.
        .frame(minWidth: Design.Window.minWidth,
               idealWidth: Design.Window.width,
               maxWidth: .infinity,
               minHeight: Design.Window.minContentHeight,
               idealHeight: Design.Window.contentHeight,
               maxHeight: .infinity,
               alignment: .top)
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
        // 포트 목록도 같은 규칙을 쓴다. 규칙이 둘이 되지 않게 한다.
        .onAppear { localhost.startPolling() }
        .onDisappear { localhost.stopPolling() }
    }

    // MARK: - 탭바

    /// 탭 이름 옆의 점이 그 기능이 지금 돌고 있는지를 보여준다.
    ///
    /// 두 기능 모두 **시스템 상태**를 바꾸고, 덮개 기능은 앱을 꺼도 값이 남는다.
    /// 탭 뒤에 숨겨버리면 켜둔 사실이 화면 어디에도 없게 되므로, 어느 탭에 있든 보이게 한다.
    /// 점은 매니저의 `isRunning` 을 그대로 따라간다. 따로 기억하지 않는다.
    private var tabBar: some View {
        HStack(spacing: Design.Space.navItemGap) {
            ForEach(Tab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    HStack(spacing: Design.Space.labelGap) {
                        // 아이콘이 상태 점을 겸한다. 돌고 있으면 초록.
                        // 직접 그리는 탭바라 `.tabItem` 처럼 색이 template 으로 죽지 않는다.
                        Image(systemName: tab.symbol)
                            .font(.system(size: Design.Size.navIcon))
                            .foregroundStyle(isRunning(tab) ? Color.green : Color.secondary)
                        Text(l10n(tab.titleKey))
                            .fontWeight(selection == tab ? .semibold : .regular)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Design.Inset.navItemY)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background {
                    // `.accessoryBar` 같은 기성 스타일에 맡기지 않고 직접 그린다.
                    // 선택 표시가 확실히 나오고, 위의 상태 점 색도 죽지 않는다.
                    if selection == tab {
                        RoundedRectangle(cornerRadius: Design.Radius.control).fill(.quaternary)
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
        case .localhost: return localhost.isRunning
        }
    }

    // MARK: - 화면 끄고 작업

    private var screenOffTab: some View {
        VStack(spacing: Design.Space.blockLoose) {
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
            VStack(alignment: .leading, spacing: Design.Space.listItem) {
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
            .padding(.top, Design.Space.listItem)
        } label: {
            HStack(spacing: Design.Space.labelGap) {
                Text(l10n(.caffeineSectionTitle))
                    .font(.callout)
                // 접혀 있어도 몇 개가 돌고 있는지 보여야 목적을 달성한다.
                if !caffeine.processes.isEmpty {
                    Text("\(caffeine.processes.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                // 글자 뒤 빈 자리까지 눌리게 한다. 제목 폭만 눌리면 어디를 눌러야
                // 열리는지 눈으로 알 수 없다.
                Spacer(minLength: 0)
            }
            // `DisclosureGroup` 은 화살표만 눌린다. 제목을 눌러도 열고 닫히게 한다.
            .contentShape(Rectangle())
            .onTapGesture { caffeine.isExpanded.toggle() }
        }
    }

    private func caffeineRow(_ process: CaffeinateProcess) -> some View {
        VStack(alignment: .leading, spacing: Design.Space.rowTight) {
            HStack(spacing: Design.Space.inline) {
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
                HStack(spacing: Design.Space.chipGap) {
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
        .padding(Design.Inset.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Design.Radius.card)
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
            .padding(.horizontal, Design.Inset.chipX)
            .padding(.vertical, Design.Inset.chipY)
            .background(
                RoundedRectangle(cornerRadius: Design.Radius.chip)
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
                .frame(width: Design.Size.indicator, height: Design.Size.indicator)
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
        VStack(spacing: Design.Space.formRow) {
            HStack(spacing: Design.Space.inline) {
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
            HStack(spacing: Design.Space.inline) {
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
            HStack(spacing: Design.Space.inline) {
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
        VStack(alignment: .leading, spacing: Design.Space.block) {
            // 이 VStack 은 주의사항 목록 때문에 leading 정렬이다. 상태 줄만은 잠자기 방지
            // 탭과 같게 가운데에 두어야 해서 폭을 끝까지 펴고 그 안에서 가운데 정렬한다.
            HStack {
                Circle()
                    .fill(lid.isRunning ? .green : .gray)
                    .frame(width: Design.Size.indicator, height: Design.Size.indicator)
                Text(l10n(lid.isRunning ? .lidStatusOn : .lidStatusOff))
                    .font(.body)
            }
            .frame(maxWidth: .infinity)

            // 유지 시간. 켜져 있는 동안에는 못 바꾼다.
            HStack(spacing: Design.Space.inline) {
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
        VStack(alignment: .leading, spacing: Design.Space.listRow) {
            HStack(spacing: Design.Space.navItemGap) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(l10n(.lidCautionTitle))
                    .fontWeight(.medium)
            }
            ForEach(Self.cautionKeys, id: \.self) { key in
                HStack(alignment: .top, spacing: Design.Space.listRow) {
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
        VStack(spacing: Design.Space.blockLoose) {
            HStack {
                Circle()
                    .fill(cover.isCovering ? .green : .gray)
                    .frame(width: Design.Size.indicator, height: Design.Size.indicator)
                Text(l10n(cover.isCovering ? .coverStatusOn : .coverStatusOff))
                    .font(.body)
            }

            VStack(spacing: Design.Space.formRow) {
                HStack(spacing: Design.Space.inline) {
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

                HStack(spacing: Design.Space.inline) {
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

                HStack(spacing: Design.Space.inline) {
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

    // MARK: - 로컬호스트

    /// 듣고 있는 localhost 포트를 보여준다.
    ///
    /// 다른 셋과 달리 **켜고 끄는 Tool 이 아니다.** 시작 버튼이 없고, 보여주는 것과
    /// 여는 것·끄는 것만 있다. 그래서 상태행도 "켜짐/꺼짐" 이 아니라 개수를 말한다.
    private var localhostTab: some View {
        VStack(alignment: .leading, spacing: Design.Space.block) {
            VStack(alignment: .leading, spacing: Design.Space.rowTight) {
                HStack(spacing: Design.Space.labelGap) {
                    Circle()
                        .fill(localhost.isRunning ? .green : .gray)
                        .frame(width: Design.Size.indicator, height: Design.Size.indicator)
                    Text(localhost.ports.isEmpty
                         ? l10n(.localhostStatusNone)
                         : l10n(.localhostStatusCount, localhost.ports.count))
                        .font(.body)
                }
                // 커널이 다른 사용자의 fd 목록을 막는다. 안 보이는 것이 있다는 사실을
                // 화면에서 밝힌다 — 목록이 전부라고 믿으면 틀린 결론을 낸다.
                Text(l10n(.localhostOwnUserOnly))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            portFilters

            if localhost.ports.isEmpty {
                Text(l10n(.localhostEmpty))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if localhost.visiblePorts.isEmpty {
                // 듣는 것이 없는 것과 필터에 걸러진 것은 다른 상태다. 같은 문구를
                // 쓰면 포트를 놓쳤는지 필터 때문인지 알 수 없다.
                Text(l10n(.localhostNoMatch))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: Design.Space.listItem) {
                    ForEach(localhost.visiblePorts) { port in
                        portRow(port)
                    }
                }
            }

            if let error = localhost.lastError {
                Text(l10n(.localhostStopFailed, error))
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 범주 선택과 포트 검색.
    private var portFilters: some View {
        VStack(alignment: .leading, spacing: Design.Space.rowTight) {
            HStack(spacing: Design.Space.inline) {
                Picker("", selection: $localhost.category) {
                    ForEach(PortCategory.allCases) { category in
                        Text(l10n(category.titleKey)).tag(category)
                    }
                }
                .labelsHidden()
                .fixedSize()

                // 숫자만 의미가 있다. 글자를 받아도 걸러내지만, 아예 숫자 자판이
                // 뜨도록 힌트를 준다.
                TextField(l10n(.localhostSearchPrompt), text: $localhost.search)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
            }

            // 걸러낸 뒤 몇 개가 남았는지 알려준다. 필터를 걸어둔 것을 잊고 "포트가
            // 사라졌다" 고 오해하지 않게 한다.
            if localhost.isFiltered {
                Text(l10n(.localhostShowingCount, localhost.visiblePorts.count, localhost.ports.count))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func portRow(_ port: LocalPort) -> some View {
        VStack(alignment: .leading, spacing: Design.Space.rowTight) {
            HStack(spacing: Design.Space.inline) {
                // 이 화면을 여는 이유가 "몇 번이 잡혀 있나" 라서 포트를 가장 크게 둔다.
                Text("\(port.port)")
                    .font(.title3.monospacedDigit())
                Spacer(minLength: 4)
                Button(l10n(.localhostOpen)) { localhost.open(port) }
                    .controlSize(.small)
            }

            Text("\(port.processName) (pid \(port.pid))")
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .contentShape(Rectangle())
                .help(port.processPath.isEmpty ? port.processName : port.processPath)

            // 근거가 확실한 것만 라벨을 단다. "내가 띄운 것" 인지 "앱이 필요해서 띄운
            // 것" 인지는 어떤 신호로도 가려낼 수 없어(daemonize 하면 부모도 터미널도
            // 사라진다) 단정하지 않는다. 대신 번들 식별자를 그대로 보여주고 판단을
            // 사용자에게 남긴다. 근거는 `docs/plans/localhost-list/research.md`.
            HStack(spacing: Design.Space.chipGap) {
                if port.isSystem {
                    portChip(l10n(.localhostLabelSystem), tint: .red,
                             help: l10n(.localhostLabelSystemHelp))
                }
                if port.startedFromTerminal {
                    portChip(l10n(.localhostLabelTerminal), tint: .green,
                             help: l10n(.localhostLabelTerminalHelp))
                }
                if port.isWellKnown {
                    portChip(l10n(.localhostLabelWellKnown), tint: .orange,
                             help: l10n(.localhostLabelWellKnownHelp))
                }
                ForEach(port.addresses, id: \.self) { address in
                    portChip(address)
                }
                ForEach(port.families, id: \.self) { family in
                    portChip(family)
                }
            }

            // 라벨을 붙일 근거가 없을 때 주인을 가늠할 유일한 단서다.
            if let identifier = port.bundleIdentifier, !identifier.isEmpty {
                Text(identifier)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(Design.Inset.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Design.Radius.card)
                .fill(Color.primary.opacity(0.05)))
        .contextMenu {
            Button(l10n(.localhostStop)) {
                stopPort(port)
            }
            // 자기 자신을 끄는 버튼이 되면 안 된다.
            .disabled(port.isSelf)

            if port.isSelf {
                Text(l10n(.localhostSelf))
            }
        }
    }

    private func portChip(_ text: String, tint: Color? = nil,
                          help: String? = nil) -> some View {
        Text(text)
            .font(.caption2.monospaced())
            .foregroundStyle(tint ?? .primary)
            .padding(.horizontal, Design.Inset.chipX)
            .padding(.vertical, Design.Inset.chipY)
            .background(
                RoundedRectangle(cornerRadius: Design.Radius.chip)
                    .fill((tint ?? Color.primary).opacity(0.1)))
            .contentShape(Rectangle())
            .help(help ?? "")
    }

    /// 중지. 시스템 구성요소는 한 번 더 묻는다.
    ///
    /// 끄는 것을 막지는 않는다 — 사용자 판단이고, 스스로는 못 하는 일을 앱이 가로막는
    /// 것은 답답하다. 다만 실수로 누를 수는 없어야 한다.
    private func stopPort(_ port: LocalPort) {
        if port.isSystem {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = l10n(.localhostConfirmTitle, port.processName)
            alert.informativeText = l10n(.localhostConfirmBody)
            alert.addButton(withTitle: l10n(.localhostConfirmStop))
            alert.addButton(withTitle: l10n(.localhostConfirmCancel))
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        localhost.lastError = localhost.stop(port)
    }
}
