import Foundation
import Combine
import IOKit
import IOKit.pwr_mgt

/// 덮개를 닫아도 맥이 잠들지 않게 해 모든 앱을 계속 돌린다.
///
/// - 덮개 닫기 잠자기는 유휴 잠자기가 아니라 **강제 잠자기 경로**라
///   `caffeinate` 의 assertion(`-d/-i/-m/-s/-u`)으로는 막을 수 없다.
///   실측으로 확인했다 — caffeinate 가 떠 있는 상태에서도 `Clamshell Sleep` 이 기록된다.
/// - 유일한 수단은 `pmset -a disablesleep` 이다. 커널 `IOPMrootDomain` 의
///   `SleepDisabled` 를 뒤집으며 이 플래그가 덮개 닫기 잠자기를 결정한다.
///   `man pmset` 에 문서화되지 않은 비공식 플래그다.
/// - `disablesleep` 은 **시스템 잠자기 전체**를 끈다. 켜져 있는 동안에는 덮개를
///   열어두어도 맥이 잠들지 않는다. 화면 슬립은 별개라 그대로 동작한다.
///
/// `BlackWorkManager` 와 달리 이 기능은 **프로세스가 아니라 시스템 설정**을 바꾼다.
/// 앱이 죽어도, 재부팅해도 값이 남는다. 그래서 상태를 로컬 플래그로 기억하지 않고
/// 항상 커널에서 실제 값을 읽는다.
final class LidWorkManager: ObservableObject {
    /// 토글 시도의 결과. UI 가 무엇을 보여줄지 결정한다.
    enum ToggleOutcome: Equatable {
        /// 값이 의도대로 바뀌었다.
        case changed(Bool)
        /// 사용자가 인증 다이얼로그를 취소했다. 상태는 그대로다.
        case cancelled
        /// 인증은 지났지만 실제 값이 바뀌지 않았거나 실행에 실패했다.
        case failed(String)
    }

    /// 커널의 실제 값. 앱이 기억한 값이 아니다.
    @Published private(set) var isRunning = false
    /// 마지막 토글이 실패했을 때의 사유. 성공하거나 다시 시도하면 지운다.
    @Published private(set) var lastError: String?

    /// 유지 시간 - 시 (0...24). `BlackWorkManager` 와 같은 폭을 쓴다.
    static let hourOptions = Array(0...24)
    /// 유지 시간 - 분 (0, 10, ... 50)
    static let minuteOptions = Array(stride(from: 0, through: 50, by: 10))

    @Published var hours = 0
    @Published var minutes = 0

    /// 남은 시간(초). 무제한이거나 꺼져 있으면 nil.
    @Published private(set) var remaining: TimeInterval?
    /// 시간이 끝났는데 자동으로 끄지 못했는가.
    @Published private(set) var autoStopFailed = false

    /// 선택한 유지 시간(초). 0시간 0분이면 nil = 시간 제한 없음.
    var durationSeconds: Int? {
        let total = hours * 3600 + minutes * 60
        return total == 0 ? nil : total
    }

    /// 이 프로세스가 켠 것인가.
    ///
    /// 켜져 있다는 사실만으로는 누가 켰는지 알 수 없다. 다른 도구나 사용자의 터미널이
    /// 켜둔 것을 앱이 종료하면서 말없이 꺼버리면 남의 상태를 망가뜨리는 것이다.
    /// 읽는 것은 주인을 가리지 않지만, **쓰는 것은 가린다.**
    private(set) var turnedOnByThisProcess = false

    private var endDate: Date?
    private var ticker: Timer?

    init() {
        refreshFromSystem()
    }

    /// 커널에서 `SleepDisabled` 를 다시 읽어 `isRunning` 을 맞춘다.
    ///
    /// 앱 실행 시와 창이 다시 활성화될 때 호출한다. 이 앱이 켜둔 것이든, 이전 실행이
    /// 잔류시킨 것이든, 다른 수단으로 켜진 것이든 구분하지 않고 실제 상태를 그대로 보여준다.
    func refreshFromSystem() {
        isRunning = Self.readSleepDisabled() ?? false
    }

    @discardableResult
    func start() -> ToggleOutcome { apply(true) }

    @discardableResult
    func stop() -> ToggleOutcome { apply(false) }

    @discardableResult
    func toggle() -> ToggleOutcome { apply(!isRunning) }

    // MARK: - Private

    /// `pmset -a disablesleep <0|1>` 을 관리자 권한으로 실행하고, 커널 값을 다시 읽어 확인한다.
    ///
    /// 성공했다고 가정하고 `isRunning` 을 먼저 바꾸지 않는다. 사용자가 인증을 취소하면
    /// 값이 그대로이므로, 낙관적으로 갱신하면 버튼과 실제 상태가 어긋난다.
    private func apply(_ enabled: Bool) -> ToggleOutcome {
        let outcome = Self.runPrivileged(disableSleep: enabled)

        switch outcome {
        case .cancelled:
            refreshFromSystem()
            lastError = nil
            return .cancelled

        case .failed(let reason):
            refreshFromSystem()
            lastError = reason
            return .failed(reason)

        case .ok:
            // 방어적 폴링. 20회 반복 측정에서는 pmset 종료 직후 첫 읽기가 항상 새 값이었고
            // 지연이 관측되지 않았다(0/20). 알려진 결함이 아니라, 부하나 다른 머신에서
            // powerd 반영이 늦을 경우 성공을 실패로 오판하지 않기 위한 여유다.
            // 값이 이미 맞으면 첫 반복에서 바로 빠져나오므로 비용이 없다.
            guard waitForSleepDisabled(toBecome: enabled) else {
                let reason = "pmset did not change SleepDisabled"
                lastError = reason
                return .failed(reason)
            }
            if enabled {
                turnedOnByThisProcess = true
                autoStopFailed = false
                startCountdownIfNeeded()
            } else {
                clearCountdown()
            }
            lastError = nil
            return .changed(enabled)
        }
    }

    /// `SleepDisabled` 가 원하는 값이 될 때까지 최대 0.5초 기다린다. 되면 true.
    /// 기다리는 동안 `isRunning` 도 같이 갱신된다.
    private func waitForSleepDisabled(toBecome expected: Bool) -> Bool {
        for _ in 0..<10 {
            refreshFromSystem()
            if isRunning == expected { return true }
            Thread.sleep(forTimeInterval: 0.05)
        }
        refreshFromSystem()
        return isRunning == expected
    }

    /// 인증 창을 띄우지 않고 끄기만 시도한다. 성공하면 true.
    ///
    /// 종료 경로 전용이다. 종료 중에는 인증 창이 뜨지 않거나 사용자가 취소할 수 있어
    /// 창을 띄우는 경로로 넘어가면 안 된다. 실패하면 호출한 쪽이 사용자에게 물어야 한다.
    func revertWithoutPrompting() -> Bool {
        guard Self.execute(
            "/usr/bin/sudo", ["-n", "/usr/bin/pmset", "-a", "disablesleep", "0"]
        ).status == 0 else { return false }

        guard waitForSleepDisabled(toBecome: false) else { return false }
        turnedOnByThisProcess = false
        clearCountdown()
        lastError = nil
        return true
    }

    // MARK: - 유지 시간

    /// 유지 시간이 지정돼 있으면 1초 티커를 건다. 무제한이면 아무것도 하지 않는다.
    private func startCountdownIfNeeded() {
        clearCountdown()
        guard let seconds = durationSeconds else { return }

        endDate = Date().addingTimeInterval(TimeInterval(seconds))
        remaining = TimeInterval(seconds)

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func clearCountdown() {
        ticker?.invalidate()
        ticker = nil
        endDate = nil
        remaining = nil
    }

    private func tick() {
        guard let endDate else { return }

        let left = endDate.timeIntervalSinceNow
        guard left <= 0 else {
            remaining = left
            return
        }

        // 만료. 인증 창은 절대 띄우지 않는다 — 덮개를 닫아두고 자리를 비운 상황이
        // 전형이라 아무도 암호를 칠 수 없고, 창만 떠 있는 채로 맥이 계속 깨어 있게 된다.
        // 조용히 끌 수 없으면 끄지 못했다고 알리기만 하고 켜진 상태를 유지한다.
        if !revertWithoutPrompting() {
            clearCountdown()
            autoStopFailed = true
            refreshFromSystem()
        }
    }

    private enum RunResult {
        case ok
        case cancelled
        case failed(String)
    }

    /// `pmset -a disablesleep <0|1>` 을 root 로 실행한다.
    ///
    /// sudoers 규칙이 있으면 암호 없이 실행하고, 없으면 관리자 인증 창으로 넘어간다.
    /// 규칙 파일을 지우면 자동으로 후자로 돌아가므로 앱을 고칠 필요가 없다.
    private static func runPrivileged(disableSleep enabled: Bool) -> RunResult {
        let flag = enabled ? "1" : "0"

        // 먼저 그냥 해본다. `-n` 은 절대 암호를 묻지 않으므로, 규칙이 없으면 조용히 실패한다.
        // 미리 가능 여부를 따져보는 것보다 정확하다 — 실행해봐야만 알 수 있기 때문이다.
        //
        // `sudo -n -l` 로 가능 여부를 먼저 묻는 방법은 쓰지 않는다. `-l` 은 "암호 없이
        // 되는가"가 아니라 "허용되는가"를 보므로 관리자 계정이면 무엇이든 통과한다.
        let sudo = execute("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "-a", "disablesleep", flag])
        if sudo.status == 0 { return .ok }

        let dialog = runViaAuthorizationDialog(flag: flag)
        // 인증 창까지 실패했으면 sudo 쪽 사유도 함께 남긴다. 둘 중 하나만 봐서는
        // 원인을 못 찾는 경우가 있다.
        if case .failed(let reason) = dialog, !sudo.stderr.isEmpty {
            return .failed("\(reason) (sudo: \(sudo.stderr))")
        }
        return dialog
    }

    /// 관리자 인증 다이얼로그를 띄워 명령을 실행한다.
    ///
    /// 앱이 ad-hoc 서명이라 `SMJobBless` 기반 권한 헬퍼를 쓸 수 없다. sudoers 규칙 없이
    /// root 를 얻는 수단은 이것뿐이다.
    ///
    /// 메인 스레드에서 동기로 실행한다. `NSAppleScript` 가 메인 스레드 전용이고,
    /// 인증 다이얼로그가 떠 있는 동안 앱이 멈춰 있는 것이 자연스럽기 때문이다.
    /// 부수 효과로 `BlackWorkManager` 의 1초 티커도 그동안 멈춰, 암호를 입력하는 사이에
    /// 화면이 꺼지는 것을 덜어준다.
    private static func runViaAuthorizationDialog(flag: String) -> RunResult {
        // 셸에 넘기는 값은 리터럴 0/1 뿐이라 주입 여지가 없다.
        let source = "do shell script \"/usr/bin/pmset -a disablesleep \(flag)\""
                   + " with administrator privileges"

        guard let script = NSAppleScript(source: source) else {
            return .failed("could not build the authorization script")
        }

        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)

        guard let errorInfo else { return .ok }

        // -128 = errAEEventUserCancelled. 사용자가 암호창을 닫은 정상 경로다.
        let code = errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
        if code == -128 { return .cancelled }

        let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "authorization failed (\(code))"
        return .failed(message)
    }

    private struct ExecResult {
        let status: Int32
        let stderr: String
    }

    private static func execute(_ path: String, _ arguments: [String]) -> ExecResult {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = arguments
        proc.standardOutput = FileHandle.nullDevice
        let errors = Pipe()
        proc.standardError = errors

        do {
            try proc.run()
        } catch {
            return ExecResult(status: -1, stderr: "\(error)")
        }

        // 파이프가 가득 차 프로세스가 멈추지 않도록 종료를 기다리기 전에 읽는다.
        let data = errors.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()

        let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return ExecResult(status: proc.terminationStatus, stderr: text)
    }

    /// 커널 `IOPMrootDomain` 의 `SleepDisabled`.
    ///
    /// `ioreg` 프로세스를 띄우지 않고 IOKit 을 직접 읽는다. `BlackWorkManager` 가
    /// 같은 이유로 `pmset` 대신 `CGDisplayIsAsleep` 을 쓰는 것과 같은 판단이다.
    private static func readSleepDisabled() -> Bool? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }

        let property = IORegistryEntryCreateCFProperty(
            service, "SleepDisabled" as CFString, kCFAllocatorDefault, 0
        )
        return property?.takeRetainedValue() as? Bool
    }
}
