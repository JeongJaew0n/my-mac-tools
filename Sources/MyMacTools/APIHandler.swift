import AppKit
import Darwin
import Foundation

/// API 요청 한 건을 처리한다.
///
/// 메서드 표와 거부 정책은 `docs/plans/agent-api/spec.md` 에 있고, 사용자를 위한 문서는
/// `docs/api.md` 다. 둘이 어긋나면 문서가 거짓이 되므로 메서드를 고칠 때 같이 고친다.
@MainActor
final class APIHandler {

    /// 정책으로 막거나 조건이 안 맞아 돌려보내는 이유.
    enum Failure: String, Error {
        case badRequest
        case unknownMethod
        case badParams
        case notFound
        /// 정책으로 막은 것. 사람의 확인을 받을 수 없어서 하지 않는다.
        case forbidden
        /// 사람의 인증이 필요한 것.
        case needsHuman
        case preconditionFailed
        case internalError
    }

    private let sleep: BlackWorkManager
    private let lid: LidWorkManager
    private let cover: ScreenCoverManager
    private let caffeine: CaffeinateScanner
    private let localhost: LocalhostManager

    init(sleep: BlackWorkManager, lid: LidWorkManager, cover: ScreenCoverManager,
         caffeine: CaffeinateScanner, localhost: LocalhostManager) {
        self.sleep = sleep
        self.lid = lid
        self.cover = cover
        self.caffeine = caffeine
        self.localhost = localhost
    }

    /// 요청 한 줄을 받아 응답 한 줄을 만든다.
    func respond(to line: Data) -> Data {
        guard let request = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let method = request["method"] as? String else {
            return encode(failure: .badRequest, "요청은 method 를 담은 JSON 한 줄이어야 합니다")
        }

        let params = request["params"] as? [String: Any] ?? [:]

        do {
            return encode(result: try dispatch(method, params))
        } catch let failure as Failure {
            return encode(failure: failure, message(for: failure, method: method))
        } catch {
            return encode(failure: .internalError, "\(error)")
        }
    }

    // MARK: - 메서드

    private func dispatch(_ method: String, _ params: [String: Any]) throws -> Any {
        switch method {
        case "status": return status()

        case "sleep.get": return sleepState()
        case "sleep.start": return try startSleep(params)
        case "sleep.stop":
            sleep.stop()
            return sleepState()

        case "lid.get":
            lid.refreshFromSystem()
            return lidState()
        // 관리자 인증이 필요하다. 에이전트 호출로 암호창이 튀어나오면 사용자는 무엇
        // 때문에 뜬 창인지 알 수 없다. 앱에서 직접 하게 돌려보낸다.
        case "lid.start", "lid.stop": throw Failure.needsHuman

        case "cover.get": return coverState()
        case "cover.start":
            guard cover.imagePath != nil else { throw Failure.preconditionFailed }
            cover.start()
            return coverState()
        case "cover.stop":
            cover.stop()
            return coverState()

        case "caffeinate.list":
            caffeine.refresh()
            return caffeine.processes.map(describe)
        case "caffeinate.stop": return try stopCaffeinate(params)

        case "ports.list": return try listPorts(params)
        case "ports.stop": return try stopPort(params)
        case "ports.open": return try openPort(params)

        default: throw Failure.unknownMethod
        }
    }

    private func status() -> [String: Any] {
        lid.refreshFromSystem()
        caffeine.refresh()
        localhost.refresh()
        return [
            "sleep": sleepState(),
            "lid": lidState(),
            "cover": coverState(),
            "localhost": ["listening": localhost.ports.count],
            "caffeinate": ["running": caffeine.processes.count],
        ]
    }

    private func sleepState() -> [String: Any] {
        var state: [String: Any] = [
            "running": sleep.isRunning,
            "hours": sleep.hours,
            "minutes": sleep.minutes,
            "screenMode": sleep.screenMode.rawValue,
            "displayDelaySeconds": sleep.displayDelaySeconds,
            "sleepWhenDone": sleep.sleepWhenDone,
        ]
        if let remaining = sleep.remaining { state["remainingSeconds"] = Int(remaining) }
        if let countdown = sleep.displayCountdown { state["screenOffInSeconds"] = countdown }
        return state
    }

    private func lidState() -> [String: Any] {
        ["running": lid.isRunning, "turnedOnByThisApp": lid.turnedOnByThisProcess]
    }

    private func coverState() -> [String: Any] {
        var state: [String: Any] = ["covering": cover.isCovering, "fillMode": cover.fillMode.rawValue]
        state["imagePath"] = cover.imagePath ?? ""
        return state
    }

    private func startSleep(_ params: [String: Any]) throws -> [String: Any] {
        // 준 것만 바꾼다. 안 준 값은 사용자가 창에서 골라둔 것을 그대로 쓴다.
        if let hours = params["hours"] as? Int {
            guard BlackWorkManager.hourOptions.contains(hours) else { throw Failure.badParams }
            sleep.hours = hours
        }
        if let minutes = params["minutes"] as? Int {
            guard BlackWorkManager.minuteOptions.contains(minutes) else { throw Failure.badParams }
            sleep.minutes = minutes
        }
        if let seconds = params["displayDelaySeconds"] as? Int {
            guard BlackWorkManager.displayDelayOptions.contains(seconds) else { throw Failure.badParams }
            sleep.displayDelaySeconds = seconds
        }
        if let raw = params["screenMode"] as? String {
            guard let mode = BlackWorkManager.ScreenMode(rawValue: raw) else { throw Failure.badParams }
            sleep.screenMode = mode
        }
        if let flag = params["sleepWhenDone"] as? Bool {
            sleep.sleepWhenDone = flag
        }

        sleep.start()
        return sleepState()
    }

    private func stopCaffeinate(_ params: [String: Any]) throws -> [String: Any] {
        guard let pid = params["pid"] as? Int else { throw Failure.badParams }
        caffeine.refresh()
        guard let target = caffeine.processes.first(where: { $0.pid == pid_t(pid) }) else {
            throw Failure.notFound
        }
        if let reason = caffeine.stop(target, manager: sleep) {
            return ["stopped": false, "reason": reason]
        }
        return ["stopped": true]
    }

    private func listPorts(_ params: [String: Any]) throws -> [[String: Any]] {
        localhost.refresh()

        var ports = localhost.ports
        if let raw = params["category"] as? String {
            guard let category = PortCategory(rawValue: raw) else { throw Failure.badParams }
            ports = ports.filter { category.matches($0) }
        }
        // 포트를 찾는 파라미터라 호출자가 숫자로 쓰는 것이 자연스럽다. 문자열만 받으면
        // `search=8501` 이 조용히 무시된다 — 실제로 그 버그를 먼저 만들었다.
        let search: String?
        switch params["search"] {
        case let text as String: search = text
        case let number as Int: search = String(number)
        case nil: search = nil
        default: throw Failure.badParams
        }
        if let search {
            let digits = search.filter(\.isNumber)
            if !digits.isEmpty { ports = ports.filter { String($0.port).contains(digits) } }
        }
        return ports.map(describe)
    }

    private func stopPort(_ params: [String: Any]) throws -> [String: Any] {
        guard let pid = params["pid"] as? Int else { throw Failure.badParams }
        localhost.refresh()
        guard let target = localhost.ports.first(where: { $0.pid == pid_t(pid) }) else {
            throw Failure.notFound
        }
        // 앱은 시스템 구성요소를 끌 때 사람에게 한 번 더 묻는다. 호출자에게는 물어볼
        // 화면이 없다. 확인을 받을 수 없으면 하지 않는다.
        guard !target.isSystem, !target.isSelf else { throw Failure.forbidden }

        if let reason = localhost.stop(target) {
            return ["stopped": false, "reason": reason]
        }
        return ["stopped": true]
    }

    private func openPort(_ params: [String: Any]) throws -> [String: Any] {
        guard let number = params["port"] as? Int, let port = UInt16(exactly: number) else {
            throw Failure.badParams
        }
        localhost.refresh()
        guard let target = localhost.ports.first(where: { $0.port == port }) else {
            throw Failure.notFound
        }
        localhost.open(target)
        return ["opened": target.url?.absoluteString ?? ""]
    }

    // MARK: - 값 만들기

    private func describe(_ process: CaffeinateProcess) -> [String: Any] {
        [
            "pid": Int(process.pid),
            "flags": process.flags.map(\.label),
            "utility": process.utility,
            "parent": process.parentName,
            "parentPath": process.parentPath,
            "startedAt": ISO8601DateFormatter().string(from: process.started),
            "isThisApp": process.isOurs,
            "canStop": process.canStop,
            "argsUnreadable": process.argsUnreadable,
        ]
    }

    private func describe(_ port: LocalPort) -> [String: Any] {
        [
            "port": Int(port.port),
            "pid": Int(port.pid),
            "process": port.processName,
            "processPath": port.processPath,
            "addresses": port.addresses,
            "families": port.families,
            "isSystem": port.isSystem,
            "startedFromTerminal": port.startedFromTerminal,
            "isWellKnown": port.isWellKnown,
            "bundleIdentifier": port.bundleIdentifier ?? "",
            // 끌 수 있는지 미리 알려준다. 호출한 뒤에 거부되는 것보다 낫다.
            "canStop": !port.isSystem && !port.isSelf,
        ]
    }

    // MARK: - 응답

    private func message(for failure: Failure, method: String) -> String {
        switch failure {
        case .needsHuman:
            return "'\(method)' 은 관리자 인증이 필요해 API 로는 하지 않습니다. 앱에서 직접 바꿔주세요."
        case .forbidden:
            return "시스템 구성요소이거나 이 앱 자신입니다. 앱에서 확인을 거쳐야 끌 수 있습니다."
        case .preconditionFailed:
            return "조건이 맞지 않습니다. 화면 가리기는 사진을 먼저 골라야 합니다."
        case .notFound:
            return "그 pid 나 포트가 목록에 없습니다."
        case .badParams:
            return "파라미터가 빠졌거나 값이 범위를 벗어났습니다."
        case .unknownMethod:
            return "'\(method)' 라는 메서드는 없습니다."
        case .badRequest:
            return "요청은 method 를 담은 JSON 한 줄이어야 합니다."
        case .internalError:
            return "처리 중 오류가 났습니다."
        }
    }

    private func encode(result: Any) -> Data {
        encode(["ok": true, "result": result])
    }

    private func encode(failure: Failure, _ message: String) -> Data {
        encode(["ok": false, "error": ["code": failure.rawValue, "message": message]])
    }

    private func encode(_ object: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))
            ?? Data(#"{"ok":false,"error":{"code":"internalError","message":"응답을 만들지 못했습니다"}}"#.utf8)
    }
}
