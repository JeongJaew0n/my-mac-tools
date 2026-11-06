import AppKit
import SwiftUI

/// IntelliJ 를 끄기 전에 확인받는 동작.
enum IntelliJAction: Identifiable {
    case apply, restore
    var id: Self { self }
}

/// IntelliJ 색 Tool 의 화면.
///
/// 자주 쓰는 색 열 개를 먼저 보이고, 나머지는 '더 보기' 안에 묶음별로 둔다. 견본을 누르면
/// macOS 색 패널이 열린다. 근거는 `docs/plans/intellij-theme/spec.md`.
///
/// 견본의 색은 **사용자가 고른 데이터** 라 `Design.Color` 를 거치지 않는다. 이 화면 자체의
/// 글자·상태 색은 다른 Tool 과 같이 토큰을 쓴다.
struct IntelliJThemeView: View {
    @ObservedObject var manager: IntelliJThemeManager
    @ObservedObject var l10n: L10n

    @State private var showsAllColors = false
    @State private var presetName = ""
    @State private var pending: IntelliJAction?

    private typealias Role = IntelliJThemeTemplate.Role
    private typealias Section = IntelliJThemeTemplate.Section

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Space.block) {
            targetBlock

            Divider()

            colorsBlock

            Divider()

            presetBlock

            Divider()

            applyBlock
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // IntelliJ 를 밖에서 바꿨을 수 있다. 탭을 열 때마다 설정 파일을 다시 읽는다.
        .onAppear { manager.refresh() }
        .confirmationDialog(l10n(pending == .restore ? .intellijConfirmRestoreTitle : .intellijConfirmApplyTitle),
                            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
                            titleVisibility: .visible,
                            presenting: pending) { action in
            Button(l10n(action == .apply ? .intellijConfirmApply : .intellijConfirmRestore)) {
                perform(action)
            }
            Button(l10n(.quitCancel), role: .cancel) {}
        } message: { _ in
            Text(l10n(.intellijConfirmBody))
        }
    }

    // MARK: - 대상

    private var targetBlock: some View {
        VStack(alignment: .leading, spacing: Design.Space.rowTight) {
            HStack(spacing: Design.Space.inline) {
                Image(systemName: "paintpalette")
                    .foregroundStyle(Design.Color.textSecondary)
                if let target = manager.target {
                    Text("\(target.displayName) \(target.version)")
                } else {
                    Text(l10n(.intellijTargetMissing))
                }
                Spacer(minLength: 0)
            }
            if manager.target != nil {
                Text(currentThemeLine)
                    .font(.caption)
                    .foregroundStyle(Design.Color.textSecondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var currentThemeLine: String {
        if manager.isApplied { return l10n(.intellijCurrentThemeOurs) }
        return l10n(.intellijCurrentTheme, manager.currentThemeID ?? l10n(.intellijThemeDefault))
    }

    // MARK: - 색

    private var colorsBlock: some View {
        VStack(alignment: .leading, spacing: Design.Space.listRow) {
            Text(l10n(.intellijSectionMain))
                .font(.callout)

            ForEach(roles(in: .main)) { colorRow($0) }

            DisclosureGroup(isExpanded: $showsAllColors) {
                VStack(alignment: .leading, spacing: Design.Space.block) {
                    ForEach(Section.allCases.filter { $0 != .main }, id: \.self) { section in
                        VStack(alignment: .leading, spacing: Design.Space.listRow) {
                            Text(l10n(key(for: section)))
                                .font(.caption)
                                .foregroundStyle(Design.Color.textSecondary)
                            ForEach(roles(in: section)) { colorRow($0) }
                        }
                    }
                }
                .padding(.top, Design.Space.rowTight)
            } label: {
                HStack(spacing: Design.Space.labelGap) {
                    Text(l10n(.intellijMore, Role.allCases.count - roles(in: .main).count))
                    // 다른 펼침과 같이 글자 뒤 빈 자리까지 눌리게 한다.
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
                .onTapGesture { showsAllColors.toggle() }
            }

            Text(l10n(.intellijColorHelp))
                .font(.caption2)
                .foregroundStyle(Design.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func colorRow(_ role: Role) -> some View {
        HStack(spacing: Design.Space.inline) {
            Text(l10n(key(for: role)))
                .lineLimit(1)
            Spacer(minLength: Design.Space.inline)
            Text("#" + manager.hex(role))
                .font(.caption.monospaced())
                .foregroundStyle(Design.Color.textSecondary)
                .textSelection(.enabled)
            ColorPicker(l10n(key(for: role)), selection: binding(for: role), supportsOpacity: false)
                .labelsHidden()
                .disabled(manager.isBusy)
        }
    }

    private func binding(for role: Role) -> Binding<Color> {
        Binding(
            get: { Color(nsColor: Self.nsColor(manager.hex(role))) },
            set: { color in
                guard let hex = Self.hex(NSColor(color)) else { return }
                manager.setHex(hex, for: role)
            })
    }

    private func roles(in section: Section) -> [Role] {
        Role.allCases.filter { $0.section == section }
    }

    // MARK: - 프리셋

    private var presetBlock: some View {
        VStack(alignment: .leading, spacing: Design.Space.listRow) {
            Text(l10n(.intellijPresets))
                .font(.callout)

            HStack(spacing: Design.Space.inline) {
                TextField(l10n(.intellijPresetName), text: $presetName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(save)
                // 같은 이름이 있으면 누르기 전에 덮어쓴다는 것을 알린다.
                Button(l10n(manager.hasPreset(named: presetName) ? .intellijOverwrite : .intellijSave), action: save)
                    .disabled(trimmedName.isEmpty)
            }
            .controlSize(.small)

            Menu(l10n(.intellijLoad)) {
                Button(l10n(.intellijLoadDefault, IntelliJThemeTemplate.defaultName)) {
                    manager.loadDefault()
                }
                if !manager.presets.isEmpty {
                    Divider()
                    ForEach(manager.presets) { preset in
                        Button(preset.name) {
                            manager.loadPreset(preset)
                            presetName = preset.name
                        }
                    }
                    Divider()
                    Menu(l10n(.intellijDelete)) {
                        ForEach(manager.presets) { preset in
                            Button(preset.name) { manager.deletePreset(preset) }
                        }
                    }
                }
            }
            .controlSize(.small)
            .fixedSize()
            .disabled(manager.isBusy)
        }
    }

    private var trimmedName: String {
        presetName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        manager.savePreset(named: trimmedName)
    }

    // MARK: - 적용

    private var applyBlock: some View {
        VStack(alignment: .leading, spacing: Design.Space.listRow) {
            Button(l10n(.intellijApply)) { request(.apply) }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(manager.isBusy || manager.target == nil)

            Text(l10n(.intellijApplyNote))
                .font(.caption2)
                .foregroundStyle(Design.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let previous = manager.previous {
                Button(l10n(.intellijRestore, previous.themeID ?? l10n(.intellijThemeDefault))) {
                    request(.restore)
                }
                .buttonStyle(.link)
                .controlSize(.small)
                .disabled(manager.isBusy)
            }

            statusLine
        }
    }

    /// IntelliJ 가 켜져 있을 때만 묻는다. 꺼져 있으면 파일만 쓰므로 물을 것이 없다.
    private func request(_ action: IntelliJAction) {
        if manager.isIntelliJRunning {
            pending = action
        } else {
            perform(action)
        }
    }

    private func perform(_ action: IntelliJAction) {
        Task {
            switch action {
            case .apply: await manager.apply()
            case .restore: await manager.restore()
            }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        if let status = manager.status {
            HStack(alignment: .firstTextBaseline, spacing: Design.Space.labelGap) {
                if case .working = status {
                    ProgressView().controlSize(.mini)
                }
                Text(message(for: status))
                    .font(.caption)
                    .foregroundStyle(color(for: status))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func message(for status: IntelliJThemeManager.Status) -> String {
        switch status {
        case .working(.quitting): return l10n(.intellijStepQuitting)
        case .working(.writing): return l10n(.intellijStepWriting)
        case .working(.relaunching): return l10n(.intellijStepRelaunching)
        case .applied(true): return l10n(.intellijApplied)
        case .applied(false): return l10n(.intellijAppliedNotRunning)
        case .restored(true): return l10n(.intellijRestored)
        case .restored(false): return l10n(.intellijRestoredNotRunning)
        case .presetSaved(let name): return l10n(.intellijPresetSaved, name)
        case .presetLoaded(let name): return l10n(.intellijPresetLoaded, name)
        case .failed(.notInstalled): return l10n(.intellijTargetMissing)
        case .failed(.noConfigDir(let path)): return l10n(.intellijFailNoConfig, path)
        case .failed(.didNotQuit): return l10n(.intellijFailDidNotQuit)
        case .failed(.nothingToRestore): return l10n(.intellijFailNothingToRestore)
        case .failed(.writeFailed(let reason)): return l10n(.intellijFailWrite, reason)
        }
    }

    private func color(for status: IntelliJThemeManager.Status) -> Color {
        switch status {
        case .failed: return Design.Color.statusError
        case .applied, .restored: return Design.Color.statusRunning
        default: return Design.Color.textSecondary
        }
    }

    // MARK: - 문자열 키

    /// 역할마다 `intellij.role.<rawValue>` 키가 있다. 없으면 키 이름이 그대로 보여 바로 드러난다.
    private func key(for role: Role) -> L10n.Key {
        L10n.Key(rawValue: "intellij.role." + role.rawValue) ?? .tabIntelliJTheme
    }

    private func key(for section: Section) -> L10n.Key {
        switch section {
        case .main: return .intellijSectionMain
        case .ui: return .intellijSectionUI
        case .editor: return .intellijSectionEditor
        case .code: return .intellijSectionCode
        case .kotlin: return .intellijSectionKotlin
        }
    }

    // MARK: - 색 ↔ hex

    /// IntelliJ 의 hex 는 sRGB 다. 색 패널이 다른 색 공간으로 줘도 sRGB 로 바꿔 저장한다.
    static func nsColor(_ hex: String) -> NSColor {
        let value = UInt32(hex, radix: 16) ?? 0
        return NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
                       green: CGFloat((value >> 8) & 0xFF) / 255,
                       blue: CGFloat(value & 0xFF) / 255,
                       alpha: 1)
    }

    static func hex(_ color: NSColor) -> String? {
        guard let srgb = color.usingColorSpace(.sRGB) else { return nil }
        func byte(_ c: CGFloat) -> Int { Int((min(max(c, 0), 1) * 255).rounded()) }
        return String(format: "%02X%02X%02X", byte(srgb.redComponent), byte(srgb.greenComponent), byte(srgb.blueComponent))
    }
}
