import AppKit
import Foundation
import Testing
@testable import MyMacTools

/// 저장값을 읽고 쓰는 상태 전이. 세션·pmset·화면 덮기는 부르지 않는다.
///
/// 시험 프로세스의 `UserDefaults` 는 앱(`com.jjw.mymactools`)과 다른 도메인이라 사용자 설정을 건드리지 않는다.
/// 같은 키를 쓰는 시험끼리 섞이지 않게 모두 `@MainActor` 에서 기다림 없이 돈다.
@MainActor
struct SleepDefaultsTests {
    init() { UserDefaults.standard.removeObject(forKey: ToolDefaults.sleepKey) }

    @Test func saveThenRestore() {
        defer { UserDefaults.standard.removeObject(forKey: ToolDefaults.sleepKey) }
        let manager = BlackWorkManager()
        manager.hours = 2
        manager.minutes = 30
        manager.screenMode = .keepOn
        manager.saveAsDefault()
        #expect(manager.matchesDefault)
        #expect(manager.defaultDurationSeconds == 2 * 3600 + 30 * 60)

        manager.hours = 0
        manager.minutes = 0
        manager.screenMode = .system
        #expect(!manager.matchesDefault)
        #expect(manager.durationSeconds == nil, "0시간 0분은 제한 없음")
        #expect(manager.defaultDurationSeconds == 9000, "메뉴에 보일 시간은 창의 값이 아니라 저장한 값")

        manager.restoreDefault()
        #expect((manager.hours, manager.minutes, manager.screenMode) == (2, 30, .keepOn))
        #expect(!manager.isRunning, "되돌리기는 세션을 켜지 않는다")
    }

    /// 저장의 뜻은 "다음에도 이걸로 시작" 이다.
    @Test func newManagerStartsFromSavedDefault() {
        defer { UserDefaults.standard.removeObject(forKey: ToolDefaults.sleepKey) }
        ToolDefaults.save(ToolDefaults.Sleep(hours: 1, minutes: 10, displayDelaySeconds: 7,
                                             screenMode: "keepOff", sleepWhenDone: true, muteWhileOff: true),
                          key: ToolDefaults.sleepKey)
        let manager = BlackWorkManager()
        #expect((manager.hours, manager.minutes, manager.displayDelaySeconds) == (1, 10, 7))
        #expect(manager.screenMode == .keepOff && manager.sleepWhenDone && manager.muteWhileOff)
    }

    /// 저장값이 망가졌으면 코드에 박힌 값으로 시작한다(앱이 죽지 않는다).
    @Test func corruptSavedDefaultFallsBack() {
        defer { UserDefaults.standard.removeObject(forKey: ToolDefaults.sleepKey) }
        UserDefaults.standard.set(Data("not json".utf8), forKey: ToolDefaults.sleepKey)
        let manager = BlackWorkManager()
        #expect(manager.screenMode == .system && manager.hours == 0)
    }

    /// 덮개 기능이 켜져 있으면 "끝나면 잠자기" 를 기본값에서 싣지 않는다(`pmset sleepnow` 가 거부된다).
    @Test func restoringDefaultsFollowsTheLidRule() {
        defer { UserDefaults.standard.removeObject(forKey: ToolDefaults.sleepKey) }
        ToolDefaults.save(ToolDefaults.Sleep(hours: 1, minutes: 0, displayDelaySeconds: 5,
                                             screenMode: "system", sleepWhenDone: true, muteWhileOff: false),
                          key: ToolDefaults.sleepKey)
        let manager = BlackWorkManager()
        let lid = LidWorkManager()  // 시스템의 지금 값을 읽기만 한다
        manager.sleepWhenDone = false
        Actions.restoreSleepDefault(manager, lid: lid)
        #expect(manager.sleepWhenDone == !lid.isRunning)
    }
}

@MainActor
struct PreferencesTests {
    static let keys = ["hiddenTabs", "appearance"]
    init() { Self.keys.forEach(UserDefaults.standard.removeObject(forKey:)) }

    /// 모든 탭을 숨긴 값은 받지 않는다 — 탭바가 비면 되돌릴 길이 없다.
    @Test func refusesASavedValueThatHidesEverything() {
        defer { Self.keys.forEach(UserDefaults.standard.removeObject(forKey:)) }
        UserDefaults.standard.set(Tab.allCases.map(\.rawValue), forKey: "hiddenTabs")
        #expect(Preferences().visibleTabs == Tab.allCases)
    }

    /// 모르는 이름(지운 Tool)은 무시하고, 새로 생긴 Tool 은 저절로 보인다(숨긴 것만 저장하므로).
    @Test func ignoresUnknownNamesAndShowsTheRest() {
        defer { Self.keys.forEach(UserDefaults.standard.removeObject(forKey:)) }
        UserDefaults.standard.set(["gone", Tab.lid.rawValue], forKey: "hiddenTabs")
        let preferences = Preferences()
        #expect(preferences.visibleTabs == Tab.allCases.filter { $0 != .lid })
    }

    @Test func cannotHideTheLastVisibleTab() {
        defer { Self.keys.forEach(UserDefaults.standard.removeObject(forKey:)) }
        let preferences = Preferences()
        for tab in Tab.allCases.dropLast() { preferences.setVisible(tab, false) }
        let last = Tab.allCases.last!
        #expect(preferences.visibleTabs == [last])
        #expect(!preferences.canHide(last))
        preferences.setVisible(last, false)
        #expect(preferences.visibleTabs == [last])
        #expect(UserDefaults.standard.stringArray(forKey: "hiddenTabs")?.count == Tab.allCases.count - 1)
    }

    @Test func unknownAppearanceFallsBackToSystem() {
        defer { Self.keys.forEach(UserDefaults.standard.removeObject(forKey:)) }
        UserDefaults.standard.set("sepia", forKey: "appearance")
        #expect(Preferences().appearance == .system)
    }
}

/// 화면 가리기 중 **덮지 않는** 경로만. 사진이 있으면 실제로 모든 화면을 덮으므로 `start()` 는
/// 사진이 없을 때만 부른다.
@MainActor
struct CoverTests {
    init() { UserDefaults.standard.removeObject(forKey: "coverImagePath") }

    @Test func unreadableImageIsNotRemembered() {
        let cover = ScreenCoverManager()
        cover.setImage(path: "/nonexistent/photo.png")
        #expect(cover.lastError == "/nonexistent/photo.png")
        #expect(cover.imagePath == nil)
        #expect(UserDefaults.standard.string(forKey: "coverImagePath") == nil)
    }

    /// 사진 없이 단색으로 덮으면 무슨 일인지 알 수 없다. 덮지 않고 이유를 남긴다.
    @Test func startWithoutImageDoesNotCover() {
        let cover = ScreenCoverManager()
        cover.start()
        #expect(!cover.isCovering)
        #expect(cover.lastError == "")
    }

    @Test func readableImageIsRememberedWithoutCovering() throws {
        defer { UserDefaults.standard.removeObject(forKey: "coverImagePath") }
        let path = repositoryRoot.appendingPathComponent("Resources/AppIcon.png").path
        try #require(NSImage(contentsOfFile: path) != nil, "시험용 그림을 읽지 못했다: \(path)")
        let cover = ScreenCoverManager()
        cover.setImage(path: path)
        #expect(cover.imagePath == path && cover.lastError == nil && !cover.isCovering)
        #expect(UserDefaults.standard.string(forKey: "coverImagePath") == path)
    }
}
