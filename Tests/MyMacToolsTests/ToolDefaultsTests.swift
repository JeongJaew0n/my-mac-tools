import Foundation
import Testing
@testable import MyMacTools

struct ToolDefaultsTests {

    /// 음소거 항목이 생기기 전에 저장된 값. 이 꼴을 못 읽으면 사용자가 저장한 기본값 전체가 사라진다.
    @Test func readsSavedDefaultsWrittenBeforeMuteExisted() throws {
        let old = #"{"sleepWhenDone":false,"hours":2,"screenMode":"keepOff","displayDelaySeconds":7,"minutes":30}"#
        let value = try JSONDecoder().decode(ToolDefaults.Sleep.self, from: Data(old.utf8))
        #expect(value == ToolDefaults.Sleep(hours: 2, minutes: 30, displayDelaySeconds: 7,
                                            screenMode: "keepOff", sleepWhenDone: false, muteWhileOff: false))
    }

    @Test func roundTrips() throws {
        var value = ToolDefaults.Sleep.builtIn
        value.muteWhileOff = true
        value.screenMode = "keepOn"
        let decoded = try JSONDecoder().decode(ToolDefaults.Sleep.self, from: JSONEncoder().encode(value))
        #expect(decoded == value)
    }

    @Test func builtInMatchesTheSessionDefaults() {
        let value = ToolDefaults.Sleep.builtIn
        #expect(value.screenMode == BlackWorkManager.ScreenMode.system.rawValue)
        #expect(BlackWorkManager.displayDelayOptions.contains(value.displayDelaySeconds))
        #expect(!value.muteWhileOff && !value.sleepWhenDone)
    }

    @Test func fallsBackWhenNothingIsSaved() {
        let key = "test.missing.\(UUID().uuidString)"
        #expect(ToolDefaults.load(key, fallback: ToolDefaults.Lid.builtIn) == ToolDefaults.Lid.builtIn)
    }
}
