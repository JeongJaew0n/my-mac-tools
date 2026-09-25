import SwiftUI

/// `MyMacTools > 설정…` (`⌘,`) 로 열리는 창.
///
/// SwiftUI 의 `Settings` 씬에 넣으면 앱 메뉴 항목과 단축키가 자동으로 붙는다.
/// 직접 `NSWindow` 를 띄우면 그 둘을 손으로 만들어야 하고 macOS 관례와 어긋난다.
struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var l10n: L10n

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Space.block) {
            Text(l10n(.settingsTabsTitle))
                .font(.headline)

            VStack(alignment: .leading, spacing: Design.Space.formRow) {
                ForEach(Tab.allCases) { tab in
                    row(tab)
                }
            }

            Text(l10n(.settingsTabsNote))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Design.Inset.panel)
        .frame(width: Design.Window.settingsWidth, alignment: .leading)
    }

    private func row(_ tab: Tab) -> some View {
        // 마지막 하나는 끌 수 없다. 토글을 잠그고 왜 잠겼는지 아래에 쓴다.
        let locked = !preferences.canHide(tab)

        return Toggle(isOn: Binding(
            get: { preferences.isVisible(tab) },
            set: { preferences.setVisible(tab, $0) }
        )) {
            HStack(spacing: Design.Space.labelGap) {
                Image(systemName: tab.symbol)
                    .font(.system(size: Design.Size.navIcon))
                    .foregroundStyle(.secondary)
                Text(l10n(tab.titleKey))
            }
        }
        .toggleStyle(.switch)
        .disabled(locked)
        .help(locked ? l10n(.settingsTabsLastOne) : "")
    }
}
