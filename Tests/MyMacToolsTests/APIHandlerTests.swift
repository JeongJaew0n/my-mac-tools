import Foundation
import Testing
@testable import MyMacTools

/// API 의 응답 꼴과 거절 경로. **세션을 실제로 켜는 요청은 보내지 않는다** — 시험이 caffeinate 를
/// 띄우거나 화면을 끄면 사용자의 맥이 바뀐다. 거절되는 요청은 아무것도 바꾸지 않아야 한다.
@MainActor
struct APIHandlerTests {
    let sleep = BlackWorkManager()
    let handler: APIHandler

    init() {
        handler = APIHandler(sleep: sleep, lid: LidWorkManager(), cover: ScreenCoverManager(),
                             caffeine: CaffeinateScanner(), localhost: LocalhostManager(),
                             speedTest: SpeedTestManager(), macInfo: MacInfoManager(),
                             thermal: ThermalManager(), intellij: IntelliJThemeManager())
    }

    private func call(_ request: String) throws -> [String: Any] {
        let data = handler.respond(to: Data(request.utf8))
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func errorCode(_ request: String) throws -> String? {
        let response = try call(request)
        #expect(response["ok"] as? Bool == false)
        return (response["error"] as? [String: Any])?["code"] as? String
    }

    @Test func rejectsMalformedRequests() throws {
        #expect(try errorCode("not json") == "badRequest")
        #expect(try errorCode(#"{"params":{}}"#) == "badRequest")
        #expect(try errorCode(#"{"method":"no.such"}"#) == "unknownMethod")
    }

    @Test func sleepGetListsEverySetting() throws {
        let response = try call(#"{"method":"sleep.get"}"#)
        #expect(response["ok"] as? Bool == true)
        let state = try #require(response["result"] as? [String: Any])
        for key in ["running", "hours", "minutes", "screenMode", "displayDelaySeconds", "sleepWhenDone", "muteWhileOff"] {
            #expect(state[key] != nil, "sleep.get 에 \(key) 가 없다")
        }
    }

    /// 형까지 본다. 거절되면 창의 값도 그대로여야 한다(모두 검사한 뒤 한꺼번에 반영).
    @Test(arguments: [
        #"{"hours":"2"}"#, #"{"hours":1.5}"#, #"{"hours":25}"#, #"{"minutes":15}"#,
        #"{"sleepWhenDone":1}"#, #"{"muteWhileOff":"yes"}"#, #"{"screenMode":"dim"}"#,
        #"{"displayDelaySeconds":4}"#, #"{"hours":3,"screenMode":"dim"}"#,
    ])
    func sleepStartRejectsBadParams(_ params: String) throws {
        let before = (sleep.hours, sleep.minutes, sleep.screenMode, sleep.muteWhileOff, sleep.sleepWhenDone)
        #expect(try errorCode(#"{"method":"sleep.start","params":\#(params)}"#) == "badParams")
        #expect(!sleep.isRunning)
        #expect(before == (sleep.hours, sleep.minutes, sleep.screenMode, sleep.muteWhileOff, sleep.sleepWhenDone))
    }

    /// 끄기·열기는 대상이 확실할 때만 한다. 형이 틀리거나 목록에 없으면 아무것도 하지 않는다.
    /// pid·포트는 쓰이지 않는 값을 골랐다 — 목록에 있으면 실제로 꺼지므로 `notFound` 만 기대한다.
    @Test(arguments: [
        (#"{"method":"caffeinate.stop"}"#, "badParams"),
        (#"{"method":"caffeinate.stop","params":{"pid":"123"}}"#, "badParams"),
        (#"{"method":"caffeinate.stop","params":{"pid":2147483000}}"#, "notFound"),
        (#"{"method":"ports.stop"}"#, "badParams"),
        (#"{"method":"ports.stop","params":{"pid":2147483000}}"#, "notFound"),
        (#"{"method":"ports.open","params":{"port":70000}}"#, "badParams"),
        (#"{"method":"ports.open","params":{"port":"80"}}"#, "badParams"),
        (#"{"method":"ports.list","params":{"category":"nope"}}"#, "badParams"),
        (#"{"method":"ports.list","params":{"search":"abc"}}"#, "badParams"),
    ])
    func targetedActionsNeedAValidTarget(_ request: String, _ code: String) throws {
        #expect(try errorCode(request) == code)
    }

    /// 사진이 없으면 덮지 않는다. 시험 프로세스에는 저장된 사진이 없다.
    @Test func coverStartNeedsAnImage() throws {
        UserDefaults.standard.removeObject(forKey: "coverImagePath")
        let handler = APIHandler(sleep: sleep, lid: LidWorkManager(), cover: ScreenCoverManager(),
                                 caffeine: CaffeinateScanner(), localhost: LocalhostManager(),
                                 speedTest: SpeedTestManager(), macInfo: MacInfoManager(),
                                 thermal: ThermalManager(), intellij: IntelliJThemeManager())
        let data = handler.respond(to: Data(#"{"method":"cover.start"}"#.utf8))
        let response = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect((response["error"] as? [String: Any])?["code"] as? String == "preconditionFailed")
    }

    /// 상태를 읽는 메서드는 늘 `ok` 다.
    @Test(arguments: ["sleep.get", "lid.get", "cover.get", "speedtest.status", "intellij.info"])
    func readMethodsSucceed(_ method: String) throws {
        #expect(try call(#"{"method":"\#(method)"}"#)["ok"] as? Bool == true)
    }

    /// 관리자 인증이나 다른 앱을 끄는 일은 사람에게 돌려보낸다.
    @Test(arguments: ["lid.start", "lid.stop", "intellij.apply", "intellij.restore"])
    func humanOnlyMethods(_ method: String) throws {
        #expect(try errorCode(#"{"method":"\#(method)"}"#) == "needsHuman")
    }
}
