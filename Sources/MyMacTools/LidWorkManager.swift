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

        // 성공이든 실패든 실제 값을 다시 읽는다. 이것만이 신뢰할 수 있는 상태다.
        refreshFromSystem()

        switch outcome {
        case .cancelled:
            lastError = nil
            return .cancelled

        case .failed(let reason):
            lastError = reason
            return .failed(reason)

        case .ok:
            guard isRunning == enabled else {
                // 인증은 통과했는데 값이 안 바뀐 경우. pmset 이 거부했거나 무언가가 되돌렸다.
                let reason = "pmset did not change SleepDisabled"
                lastError = reason
                return .failed(reason)
            }
            lastError = nil
            return .changed(enabled)
        }
    }

    private enum RunResult {
        case ok
        case cancelled
        case failed(String)
    }

    /// 관리자 인증 다이얼로그를 띄워 명령을 실행한다.
    ///
    /// 앱이 ad-hoc 서명이라 `SMJobBless` 기반 권한 헬퍼를 쓸 수 없다. 설치 과정 없이
    /// root 를 얻는 수단은 이것뿐이다.
    ///
    /// 메인 스레드에서 동기로 실행한다. `NSAppleScript` 가 메인 스레드 전용이고,
    /// 인증 다이얼로그가 떠 있는 동안 앱이 멈춰 있는 것이 자연스럽기 때문이다.
    /// 부수 효과로 `BlackWorkManager` 의 1초 티커도 그동안 멈춰, 암호를 입력하는 사이에
    /// 화면이 꺼지는 것을 덜어준다.
    private static func runPrivileged(disableSleep enabled: Bool) -> RunResult {
        // 셸에 넘기는 값은 리터럴 0/1 뿐이라 주입 여지가 없다.
        let flag = enabled ? "1" : "0"
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
