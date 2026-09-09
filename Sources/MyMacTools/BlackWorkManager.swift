import Foundation
import Combine
import CoreGraphics

/// 지정한 시간 동안 화면만 끈 채 작업을 계속 돌린다.
///
/// - 시스템 유휴 잠자기는 `caffeinate -i` 로 막는다.
///   `-d`(디스플레이 슬립 방지)는 화면을 끄려는 목적과 정반대라 절대 쓰지 않는다.
/// - 화면은 지연 시간이 지난 뒤 `pmset displaysleepnow` 로 끈다.
/// - `keepScreenOff` 를 켜면 입력으로 화면이 깨어나도 유예 시간 뒤에 다시 끈다.
final class BlackWorkManager: ObservableObject {
    /// 화면 끄기 유지 단계.
    enum ScreenPhase: Equatable {
        /// 관리하지 않음 (아직 안 껐거나 `keepScreenOff` 가 꺼져 있음)
        case idle
        /// 방금 껐다. 다음 틱에 실제로 꺼졌는지 확인한다.
        case verifying
        /// 꺼진 것을 확인했다. 깨어나는지 지켜본다.
        case watching
        /// 깨어났다. 남은 유예 초가 0이 되면 다시 끈다.
        case grace(Int)
        /// 연속 실패로 포기했다. 세션 자체는 계속 돈다.
        case gaveUp
    }

    /// 화면이 깨어난 뒤 다시 끄기까지의 유예(초). Stop 을 누르러 갈 시간이다.
    static let screenGraceSeconds = 10
    /// 이만큼 연속으로 "껐는데 안 꺼짐"이면 포기한다. 없으면 화면이 무한히 깜빡인다.
    private static let maxReblankFailures = 3
    /// 유지 시간 - 시 (0...24)
    static let hourOptions = Array(0...24)
    /// 유지 시간 - 분 (0, 10, ... 50)
    static let minuteOptions = Array(stride(from: 0, through: 50, by: 10))
    /// 화면이 꺼지기까지의 지연(초)
    static let displayDelayOptions = [3, 5, 7, 10]

    @Published var hours = 0
    @Published var minutes = 0
    @Published var displayDelaySeconds = 5
    /// 입력으로 화면이 깨어나도 계속 꺼둘지 여부.
    @Published var keepScreenOff = false
    /// 유지 시간이 끝나면 잠자기로 보낼지 여부. 무제한(0h 00m)이면 의미 없다.
    @Published var sleepWhenDone = false

    @Published private(set) var isRunning = false
    /// 세션 남은 시간(초). 무제한이거나 정지 상태면 nil.
    @Published private(set) var remaining: TimeInterval?
    /// 화면이 꺼지기까지 남은 초. 이미 껐거나 정지 상태면 nil.
    @Published private(set) var displayCountdown: Int?
    /// 화면 끄기 유지 단계.
    @Published private(set) var screenPhase: ScreenPhase = .idle

    private var process: Process?
    private var endDate: Date?
    private var ticker: Timer?
    private var reblankFailures = 0

    /// 화면이 다시 꺼지기까지 남은 초. 유예 중이 아니면 nil.
    var screenGraceRemaining: Int? {
        if case .grace(let seconds) = screenPhase { return seconds }
        return nil
    }

    /// 화면을 계속 끄는 데 실패해 포기했는가.
    var keepScreenOffGaveUp: Bool { screenPhase == .gaveUp }

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
        screenPhase = .idle
        reblankFailures = 0
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

        if let current = displayCountdown {
            let next = current - 1
            if next <= 0 {
                displayCountdown = nil
                turnOffDisplay()
                screenPhase = keepScreenOff ? .verifying : .idle
            } else {
                displayCountdown = next
            }
            return
        }

        advanceScreenPhase()
    }

    /// 1초마다 화면 상태를 보고 유지 단계를 진행한다.
    ///
    /// `pmset` 을 주기적으로 무조건 쏘지 않는 이유:
    /// 프로세스 기동이 1회 66ms 인 반면 `CGDisplayIsAsleep` 조회는 8.5us 라 훨씬 싸고,
    /// 무엇보다 벽시계로 쏘면 깨어난 직후 곧바로 꺼져 유예가 0초가 될 수 있다.
    private func advanceScreenPhase() {
        switch screenPhase {
        case .idle, .gaveUp:
            break

        case .verifying:
            if displayIsAsleep {
                reblankFailures = 0
                screenPhase = .watching
            } else {
                reblankFailures += 1
                if reblankFailures >= Self.maxReblankFailures {
                    screenPhase = .gaveUp
                } else {
                    turnOffDisplay()
                }
            }

        case .watching:
            if !displayIsAsleep {
                screenPhase = .grace(Self.screenGraceSeconds)
            }

        case .grace(let secondsLeft):
            let next = secondsLeft - 1
            if next <= 0 {
                turnOffDisplay()
                screenPhase = .verifying
            } else {
                screenPhase = .grace(next)
            }
        }
    }

    /// 주 디스플레이가 꺼져 있는가. CoreGraphics 공개 API 라 권한이 필요 없다.
    private var displayIsAsleep: Bool {
        CGDisplayIsAsleep(CGMainDisplayID()) != 0
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
