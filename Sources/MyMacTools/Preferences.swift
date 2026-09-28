import AppKit
import Combine
import Foundation

/// 앱의 모양. 시스템을 그대로 따르거나, 이 앱만 라이트·다크로 고정한다.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var titleKey: L10n.Key {
        switch self {
        case .system: return .appearanceSystem
        case .light: return .appearanceLight
        case .dark: return .appearanceDark
        }
    }

    /// `nil` 이면 시스템을 따른다.
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

/// 사용자가 고른 설정.
///
/// 어떤 Tool 을 탭으로 보일지, 앱의 모양을 무엇으로 할지.
@MainActor
final class Preferences: ObservableObject {

    /// **숨긴** 탭을 저장한다. 보이는 것을 저장하지 않는 이유가 있다.
    ///
    /// 보이는 것을 저장하면 나중에 Tool 을 추가했을 때 그 목록에 없으므로 **기본으로
    /// 숨겨진다.** 새 기능을 만들고도 설정을 열어 켜야 보이는 셈이다. 숨긴 것만
    /// 저장하면 모르는 Tool 은 자동으로 보인다.
    private static let storageKey = "hiddenTabs"
    private static let appearanceKey = "appearance"

    /// 앱 전체의 모양. 바꾸는 즉시 모든 창에 먹는다.
    ///
    /// `NSApp.appearance` 하나로 본 창·설정 창·화면 가리기가 함께 바뀐다. 색 토큰은
    /// 그리는 순간의 appearance 로 라이트·다크를 고르므로 따로 할 일이 없다.
    @Published var appearance: AppAppearance {
        didSet {
            guard appearance != oldValue else { return }
            UserDefaults.standard.set(appearance.rawValue, forKey: Self.appearanceKey)
            Self.apply(appearance)
        }
    }

    @Published private(set) var hidden: Set<Tab> {
        didSet {
            guard hidden != oldValue else { return }
            UserDefaults.standard.set(hidden.map(\.rawValue), forKey: Self.storageKey)
        }
    }

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: Self.storageKey) ?? []
        hidden = Set(saved.compactMap(Tab.init(rawValue:)))
        appearance = UserDefaults.standard.string(forKey: Self.appearanceKey)
            .flatMap(AppAppearance.init(rawValue:)) ?? .system
        // `didSet` 은 init 에서 돌지 않으므로 저장된 값을 여기서 한 번 적용한다.
        Self.apply(appearance)
    }

    private static func apply(_ appearance: AppAppearance) {
        NSApplication.shared.appearance = appearance.nsAppearance
    }

    /// 탭바에 그릴 것. 순서는 `Tab.allCases` 를 따른다.
    var visibleTabs: [Tab] {
        Tab.allCases.filter { !hidden.contains($0) }
    }

    func isVisible(_ tab: Tab) -> Bool {
        !hidden.contains(tab)
    }

    /// 끌 수 있는가.
    ///
    /// 마지막 하나는 끄지 못한다. 탭이 0개면 창이 빈 화면이 되고, 되돌리는 길이
    /// 설정 창뿐인데 그 창을 여는 법을 모르면 갇힌다.
    func canHide(_ tab: Tab) -> Bool {
        !(isVisible(tab) && visibleTabs.count <= 1)
    }

    func setVisible(_ tab: Tab, _ visible: Bool) {
        if visible {
            hidden.remove(tab)
        } else {
            guard canHide(tab) else { return }
            hidden.insert(tab)
        }
    }
}
