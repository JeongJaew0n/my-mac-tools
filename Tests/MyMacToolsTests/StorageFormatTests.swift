import AppKit
import Foundation
import Testing
@testable import MyMacTools

/// 사용자 맥에 이미 저장된 꼴. 이름을 바꾸거나 항목을 더하다 이 꼴을 못 읽게 되면, 업데이트한 순간
/// 사용자의 설정이 말없이 사라진다.
struct StorageFormatTests {

    /// '화면 끈 채로 작업' · 화면 가리기 단축키(`screenOffShortcut` · `coverShortcut`).
    @Test func shortcutAsStored() throws {
        let stored = #"{"keyCode":46,"modifiers":786432,"displayKey":"M"}"#
        let shortcut = try JSONDecoder().decode(Shortcut.self, from: Data(stored.utf8))
        #expect(shortcut.keyCode == 46)
        #expect(shortcut.display == "⌃⌥M")
    }

    /// 덮어도 작업 기본값(`default.lid`).
    @Test func lidDefaultsAsStored() throws {
        let value = try JSONDecoder().decode(ToolDefaults.Lid.self, from: Data(#"{"hours":3,"minutes":20}"#.utf8))
        #expect(value == ToolDefaults.Lid(hours: 3, minutes: 20))
    }

    /// 탭·화면 모드는 raw 값으로 저장된다(`selectedTab`, `default.sleep` 의 `screenMode`, `hiddenTabs`).
    @Test func savedRawValuesStillMeanTheSameThing() {
        #expect(Tab(rawValue: "screenOff") == .screenOff)
        #expect(Tab(rawValue: "intellijTheme") == .intellijTheme)
        #expect(BlackWorkManager.ScreenMode(rawValue: "keepOff") == .keepOff)
        #expect(BlackWorkManager.ScreenMode(rawValue: "keepOn") == .keepOn)
        #expect(BlackWorkManager.ScreenMode(rawValue: "system") == .system)
    }
}

/// 이름을 조립해서 쓰는 현지화 키. 컴파일러가 못 잡는다.
struct ComposedKeyTests {
    /// 색 역할마다 `intellij.role.<rawValue>` 가 있어야 한다. 없으면 그 자리에 탭 이름이 대신 나온다.
    @Test func everyIntelliJRoleHasALabel() {
        let missing = IntelliJThemeTemplate.Role.allCases.filter {
            L10n.Key(rawValue: "intellij.role." + $0.rawValue) == nil
        }
        #expect(missing.isEmpty, "이름 키가 없는 색 역할: \(missing.map(\.rawValue))")
    }

    /// 모든 화면 모드·탭·모양에 이름이 있다.
    @Test func enumTitlesResolveInEveryLanguage() {
        let keys = BlackWorkManager.ScreenMode.allCases.map(\.titleKey)
            + Tab.allCases.map(\.titleKey)
            + AppAppearance.allCases.map(\.titleKey)
        for language in languages {
            let table = strings(language)
            let missing = keys.map(\.rawValue).filter { table[$0] == nil }
            #expect(missing.isEmpty, "\(language): \(missing)")
        }
    }
}
