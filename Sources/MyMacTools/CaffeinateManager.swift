import Foundation
import Combine

final class CaffeinateManager: ObservableObject {
    /// 선택 가능한 시간 값 (0...24)
    static let hourOptions = Array(0...24)
    /// 선택 가능한 분 값 (0, 10, ... 50)
    static let minuteOptions = Array(stride(from: 0, through: 50, by: 10))

    @Published private(set) var isRunning = false
    @Published var hours = 0
    @Published var minutes = 0
    /// 남은 시간(초). 무제한이거나 정지 상태면 nil.
    @Published private(set) var remaining: TimeInterval?

    private var process: Process?
    private var endDate: Date?
    private var ticker: Timer?

    /// 선택한 지속 시간(초). 0시간 0분이면 nil = 시간 제한 없음.
    var durationSeconds: Int? {
        let total = hours * 3600 + minutes * 60
        return total == 0 ? nil : total
    }

    func start() {
        guard !isRunning else { return }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")

        var arguments = ["-di"]
        if let seconds = durationSeconds {
            arguments += ["-t", String(seconds)]
        }
        proc.arguments = arguments

        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.reset()
            }
        }

        do {
            try proc.run()
            process = proc
            isRunning = true

            if let seconds = durationSeconds {
                endDate = Date().addingTimeInterval(TimeInterval(seconds))
                startTicker()
            }
        } catch {
            print("Failed to start caffeinate: \(error)")
        }
    }

    func stop() {
        if let proc = process, proc.isRunning {
            proc.terminate()
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

    /// 프로세스 종료(수동 정지 · 시간 만료 양쪽) 후 상태를 되돌린다. 여러 번 불려도 안전하다.
    private func reset() {
        stopTicker()
        process = nil
        endDate = nil
        remaining = nil
        isRunning = false
    }

    private func startTicker() {
        stopTicker()
        updateRemaining()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateRemaining()
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func updateRemaining() {
        guard let endDate else {
            remaining = nil
            return
        }
        remaining = max(0, endDate.timeIntervalSinceNow)
    }
}
