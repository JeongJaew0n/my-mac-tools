import Foundation
import Combine

final class CaffeinateManager: ObservableObject {
    @Published private(set) var isRunning = false
    private var process: Process?

    func start() {
        guard !isRunning else { return }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        proc.arguments = ["-di"]
        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isRunning = false
            }
        }
        do {
            try proc.run()
            process = proc
            isRunning = true
        } catch {
            print("Failed to start caffeinate: \(error)")
        }
    }

    func stop() {
        guard let proc = process, proc.isRunning else {
            isRunning = false
            return
        }
        proc.terminate()
        process = nil
        isRunning = false
    }

    func toggle() {
        if isRunning {
            stop()
        } else {
            start()
        }
    }
}
