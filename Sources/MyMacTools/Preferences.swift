import Combine
import Foundation

/// 사용자가 고른 설정.
///
/// 지금은 "어떤 Tool 을 탭으로 보일 것인가" 하나뿐이다.
@MainActor
final class Preferences: ObservableObject {

    /// **숨긴** 탭을 저장한다. 보이는 것을 저장하지 않는 이유가 있다.
    ///
    /// 보이는 것을 저장하면 나중에 Tool 을 추가했을 때 그 목록에 없으므로 **기본으로
    /// 숨겨진다.** 새 기능을 만들고도 설정을 열어 켜야 보이는 셈이다. 숨긴 것만
    /// 저장하면 모르는 Tool 은 자동으로 보인다.
    private static let storageKey = "hiddenTabs"

    @Published private(set) var hidden: Set<Tab> {
        didSet {
            guard hidden != oldValue else { return }
            UserDefaults.standard.set(hidden.map(\.rawValue), forKey: Self.storageKey)
        }
    }

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: Self.storageKey) ?? []
        hidden = Set(saved.compactMap(Tab.init(rawValue:)))
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
