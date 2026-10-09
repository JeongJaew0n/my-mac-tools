import Combine
import Foundation
import Network

/// 속도 측정 한 번의 결과.
struct SpeedResult: Codable, Equatable, Identifiable {
    let date: Date
    /// bit/s. `networkQuality` 의 `dl_throughput` — 바이트 수로 검산해 단위를 확인했다.
    let downloadBitsPerSecond: Double
    let uploadBitsPerSecond: Double
    /// 회선이 바쁠 때 1분에 주고받을 수 있는 왕복 수. 클수록 좋다.
    let responsivenessRPM: Double
    /// 한가할 때의 왕복 지연(ms).
    let baseRTTMilliseconds: Double
    let interfaceName: String
    /// `wifi`, `wiredEthernet` 같은 것. 못 읽으면 빈 문자열.
    let interfaceType: String
    let endpoint: String

    var id: Date { date }

    /// `networkQuality -c` 의 JSON 을 읽는다. 필요한 키가 없으면 nil.
    static func parse(_ data: Data, at date: Date) -> SpeedResult? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let down = object["dl_throughput"] as? Double,
              let up = object["ul_throughput"] as? Double else { return nil }

        let types = (object["other"] as? [String: Any])?["interface-type"] as? [String: Any]
        return SpeedResult(
            date: date,
            downloadBitsPerSecond: down,
            uploadBitsPerSecond: up,
            responsivenessRPM: object["responsiveness"] as? Double ?? 0,
            baseRTTMilliseconds: object["base_rtt"] as? Double ?? 0,
            interfaceName: object["interface_name"] as? String ?? "",
            interfaceType: types?.keys.sorted().first ?? "",
            endpoint: object["test_endpoint"] as? String ?? "")
    }
}

/// 인터넷 속도를 잰다. macOS 에 들어 있는 `networkQuality` 를 띄운다.
///
/// **누를 때만 잰다.** 1회에 21초, 147 MB 를 썼다(실측). 측정은 정해진 시간 동안 최대로
/// 흘려보내는 방식이라 회선이 빠를수록 더 쓴다. 이 앱의 다른 목록처럼 저절로 돌면 안 된다.
/// 근거는 `docs/plans/speed-test/context.md`.
@MainActor
final class SpeedTestManager: ObservableObject {

    enum State: Equatable {
        case idle
        case running(started: Date)
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    /// 최근 결과. 새것이 앞이다.
    @Published private(set) var history: [SpeedResult] = []
    /// 지금 회선이 비싼가 — 테더링·셀룰러(`isExpensive`) 또는 저데이터 모드(`isConstrained`).
    @Published private(set) var isExpensiveNetwork = false

    var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    var latest: SpeedResult? { history.first }

    /// 최대 실행 시간(초). 실측 21초에 여유를 둔다. 느린 회선에서 끝없이 돌지 않게 한다.
    static let maximumRuntime = 30
    /// 남겨 둘 결과 수. 속도는 한 번보다 비교할 때 의미가 있다.
    static let historyLimit = 10

    private static let historyKey = "speedTestHistory"
    private static let executable = "/usr/bin/networkQuality"

    private var process: Process?
    /// 취소한 종료를 실패로 그리지 않게 표시해 둔다.
    private var cancelling = false
    private let pathMonitor = NWPathMonitor()

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.historyKey),
           let saved = try? JSONDecoder().decode([SpeedResult].self, from: data) {
            history = saved
        }
        // 회선 상태는 이벤트로 받는다. 폴링하지 않는다.
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let expensive = path.isExpensive || path.isConstrained
            Task { @MainActor in self?.isExpensiveNetwork = expensive }
        }
        pathMonitor.start(queue: DispatchQueue(label: "com.jjw.mymactools.path"))
    }

    deinit {
        pathMonitor.cancel()
    }

    func start() {
        guard !isRunning else { return }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: Self.executable)
        proc.arguments = ["-c", "-M", String(Self.maximumRuntime)]
        let output = Pipe()
        let errors = Pipe()
        proc.standardOutput = output
        proc.standardError = errors

        let started = Date()
        cancelling = false

        // 출력은 끝날 때 한 번에 온다. 파이프가 가득 차 멈추지 않게 종료 전에 따로 읽는다.
        // 두 파이프를 **따로** 읽는다. 한쪽을 다 읽은 뒤 다른 쪽을 읽으면, 뒤쪽이 먼저 가득
        // 찼을 때 프로세스는 쓰기를, 우리는 읽기를 기다리며 서로 멈춘다.
        let reader = DispatchQueue(label: "com.jjw.mymactools.speedtest", attributes: .concurrent)
        let collected = Collected()
        let group = DispatchGroup()
        group.enter()
        reader.async {
            collected.output = output.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.enter()
        reader.async {
            collected.error = errors.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        proc.terminationHandler = { [weak self] finished in
            group.wait()
            let status = finished.terminationStatus
            let reason = finished.terminationReason
            let out = collected.output
            let err = String(data: collected.error, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            Task { @MainActor in
                self?.finish(status: status, reason: reason, output: out, error: err, started: started)
            }
        }

        do {
            try proc.run()
        } catch {
            state = .failed("\(error.localizedDescription)")
            return
        }
        process = proc
        state = .running(started: started)
    }

    /// 측정을 멈춘다. 잘못 눌렀을 때 데이터를 다 쓰게 두지 않는다.
    func cancel() {
        guard let process, process.isRunning else { return }
        cancelling = true
        process.terminate()
    }

    func clearHistory() {
        history = []
        persist()
    }

    // MARK: - Private

    private func finish(status: Int32, reason: Process.TerminationReason,
                        output: Data, error: String, started: Date) {
        process = nil

        if cancelling {
            cancelling = false
            state = .idle
            return
        }

        // 실패를 "0 Mbps" 로 그리지 않는다. 오프라인·서버 오류는 이유를 그대로 보여준다.
        guard reason == .exit, status == 0,
              let result = SpeedResult.parse(output, at: started) else {
            let detail = error.isEmpty ? "networkQuality exited with \(status)" : error
            state = .failed(detail)
            return
        }

        history.insert(result, at: 0)
        if history.count > Self.historyLimit {
            history.removeLast(history.count - Self.historyLimit)
        }
        persist()
        state = .idle
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: Self.historyKey)
    }
}

/// 읽기 큐가 채우고 종료 처리기가 읽는 출력.
///
/// 두 쪽이 다른 스레드라 컴파일러는 경합을 의심한다. 실제로는 `DispatchGroup` 이 순서를
/// 보장한다 — 처리기는 `group.wait()` 로 읽기가 끝나기를 기다린 뒤에만 읽는다.
private final class Collected: @unchecked Sendable {
    var output = Data()
    var error = Data()
}
