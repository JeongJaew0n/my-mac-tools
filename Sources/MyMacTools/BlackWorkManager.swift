import Foundation
import Combine

/// 지정한 시간 동안 화면만 끈 채 작업을 계속 돌린다.
///
/// - 시스템 유휴 잠자기는 `caffeinate -i` 로 막는다.
///   `-d`(디스플레이 슬립 방지)는 화면을 끄려는 목적과 정반대라 절대 쓰지 않는다.
/// - 화면은 지연 시간이 지난 뒤 `pmset displaysleepnow` 로 끈다.
final class BlackWorkManager: ObservableObject {
    /// 유지 시간 - 시 (0...24)
    static let hourOptions = Array(0...24)
    /// 유지 시간 - 분 (0, 10, ... 50)
    static let minuteOptions = Array(stride(from: 0, through: 50, by: 10))
    /// 화면이 꺼지기까지의 지연(초)
    static let displayDelayOptions = [3, 5, 7, 10]

    @Published var hours = 0
    @Published var minutes = 0
    @Published var displayDelaySeconds = 5
    /// 유지 시간이 끝나면 잠자기로 보낼지 여부. 무제한(0h 00m)이면 의미 없다.
    @Published var sleepWhenDone = false

    @Published private(set) var isRunning = false
    /// 세션 남은 시간(초). 무제한이거나 정지 상태면 nil.
    @Published private(set) var remaining: TimeInterval?
    /// 화면이 꺼지기까지 남은 초. 이미 껐거나 정지 상태면 nil.
    @Published private(set) var displayCountdown: Int?

    private var process: Process?
    private var endDate: Date?
    private var ticker: Timer?

    /// 선택한 유지 시간(초). 0시간 0분이면 nil = 시간 제한 없음.
    var durationSeconds: Int? {
        let total = hours * 3600 + minutes * 60
        return total == 0 ? nil : total
    }

    /// 세션 시작 — caffeinate 를 띄우고 화면 끄기 카운트다운을 건다.
    func start() {
        guard !isRunning else { return }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")

        var arguments = ["-i"]
        if let seconds = durationSeconds {
            arguments += ["-t", String(seconds)]
        }
        proc.arguments = arguments

        proc.terminationHandler = { [weak self] finished in
            DispatchQueue.main.async {
                self?.handleTermination(of: finished)
            }
        }

        do {
            try proc.run()
        } catch {
            print("Failed to start caffeinate: \(error)")
            return
        }

        process = proc
        isRunning = true
        displayCountdown = displayDelaySeconds
        if let seconds = durationSeconds {
            endDate = Date().addingTimeInterval(TimeInterval(seconds))
        }
        startTicker()
    }

    /// 세션 정지 — caffeinate 를 끄고 아직 안 꺼진 화면 예약도 취소한다.
    /// 수동 정지이므로 `sleepWhenDone` 이 켜져 있어도 잠자기로 보내지 않는다.
    func stop() {
        let running = process
        // handleTermination 이 이 종료를 만료로 오인하지 않도록 먼저 끊는다.
        process = nil
        if let running, running.isRunning {
            running.terminate()
        }
        reset()
    }

    func toggle() {
        if isRunning {
            stop()
        } else {
            start()
        }
    }

    // MARK: - Private

    /// caffeinate 가 스스로 끝난 경우. 지정한 시간을 다 채웠을 때만 잠자기로 보낸다.
    /// 외부에서 kill 당한 경우까지 잠재우면 곤란하므로 만료 시각에 도달했는지 확인한다.
    private func handleTermination(of finished: Process) {
        guard process === finished else { return }  // stop() 이 이미 정리한 종료

        let expired = endDate.map { $0.timeIntervalSinceNow <= 1 } ?? false
        let shouldSleep = sleepWhenDone && expired
        reset()

        if shouldSleep {
            sleepSystem()
        }
    }

    /// 세션 종료(수동 정지 · 시간 만료 양쪽) 후 상태를 되돌린다. 여러 번 불려도 안전하다.
    private func reset() {
        stopTicker()
        process = nil
        endDate = nil
        remaining = nil
        displayCountdown = nil
        isRunning = false
    }

    private func startTicker() {
        stopTicker()
        updateRemaining()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        updateRemaining()

        guard let current = displayCountdown else { return }
        let next = current - 1
        if next <= 0 {
            displayCountdown = nil
            turnOffDisplay()
        } else {
            displayCountdown = next
        }
    }

    private func updateRemaining() {
        guard let endDate else {
            remaining = nil
            return
        }
        remaining = max(0, endDate.timeIntervalSinceNow)
    }

    private func sleepSystem() {
        run("/usr/bin/pmset", ["sleepnow"], failureMessage: "Failed to sleep")
    }

    private func turnOffDisplay() {
        run("/usr/bin/pmset", ["displaysleepnow"], failureMessage: "Failed to turn off display")
    }

    private func run(_ path: String, _ arguments: [String], failureMessage: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = arguments
        do {
            try proc.run()
        } catch {
            print("\(failureMessage): \(error)")
        }
    }
}
