import Combine
import Darwin
import Foundation

/// 지금 돌고 있는 `caffeinate` 하나.
struct CaffeinateProcess: Identifiable, Equatable {
    let pid: pid_t
    let ppid: pid_t
    let uid: uid_t
    /// 사람이 읽을 부모 이름. `MyMacTools`, `claude`, `zsh` 처럼.
    let parentName: String
    /// 부모의 실행 파일 전체 경로. 툴팁으로 보여준다. 못 읽으면 빈 문자열.
    let parentPath: String
    let started: Date
    /// `argv` 에서 뽑은 플래그. 묶음(`-dimsu`)은 이미 쪼개져 있다.
    let flags: [CaffeinateFlag]
    /// `caffeinate -i make` 처럼 감싸서 실행하는 명령. 없으면 빈 배열.
    let utility: [String]
    /// 인자를 읽지 못했는가. 다른 사용자 소유면 커널이 막는다.
    let argsUnreadable: Bool

    var id: pid_t { pid }

    /// 이 앱이 띄운 것인가. `BlackWorkManager` 가 직접 자식으로 띄우므로 부모가 우리다.
    var isOurs: Bool { ppid == getpid() }

    /// 내가 끌 수 있는가. 다른 사용자(보통 root) 소유는 `SIGTERM` 이 통하지 않는다.
    var canStop: Bool { uid == getuid() }
}

/// `caffeinate` 플래그 하나.
struct CaffeinateFlag: Identifiable, Equatable {
    /// 칩에 그릴 글자. `-i`, `-t 300` 처럼 이미 사람이 읽을 모양이다.
    let label: String
    /// 호버 설명. 모르는 플래그면 nil — 지어내지 않는다.
    let explanation: L10n.Key?

    var id: String { label }

    /// 값을 받는 플래그. `getopt` 이므로 `-t300` 처럼 붙여 쓸 수도 있다.
    private static let takesValue: Set<Character> = ["t", "w"]

    private static let explanations: [Character: L10n.Key] = [
        "d": .caffeineFlagD,
        "i": .caffeineFlagI,
        "m": .caffeineFlagM,
        "s": .caffeineFlagS,
        "u": .caffeineFlagU,
        "t": .caffeineFlagT,
        "w": .caffeineFlagW,
    ]

    /// `argv` 를 플래그와 감싼 명령으로 가른다.
    ///
    /// 첫 원소(`argv[0]`)는 넘겨받기 전에 떼어둔다. `-` 로 시작하지 않는 토큰이
    /// 값으로 쓰이지 않았다면 그 지점부터는 감싸서 실행하는 명령이다.
    static func parse(_ arguments: [String]) -> (flags: [CaffeinateFlag], utility: [String]) {
        var flags: [CaffeinateFlag] = []
        var index = arguments.startIndex

        while index < arguments.endIndex {
            let token = arguments[index]
            guard token.hasPrefix("-"), token.count > 1 else { break }

            let characters = Array(token.dropFirst())
            var position = 0
            while position < characters.count {
                let character = characters[position]
                position += 1

                guard takesValue.contains(character) else {
                    flags.append(CaffeinateFlag(label: "-\(character)",
                                                explanation: explanations[character]))
                    continue
                }

                // 값은 같은 토큰에 붙어 있거나(`-t300`) 다음 토큰이다(`-t 300`).
                let attached = String(characters[position...])
                if !attached.isEmpty {
                    position = characters.count
                    flags.append(CaffeinateFlag(label: "-\(character) \(attached)",
                                                explanation: explanations[character]))
                } else if arguments.index(after: index) < arguments.endIndex {
                    index = arguments.index(after: index)
                    flags.append(CaffeinateFlag(label: "-\(character) \(arguments[index])",
                                                explanation: explanations[character]))
                } else {
                    // 값 없이 끝났다. 원문 그대로 둔다.
                    flags.append(CaffeinateFlag(label: "-\(character)",
                                                explanation: explanations[character]))
                }
            }

            index = arguments.index(after: index)
        }

        return (flags, Array(arguments[index...]))
    }
}

/// 시스템에서 돌고 있는 `caffeinate` 를 훑는다.
///
/// `ps` 를 띄우지 않고 `sysctl` 을 직접 부른다. 창이 열려 있는 동안 몇 초마다 훑게 되는데,
/// 그때마다 `fork`/`exec` 를 하는 것은 낭비다. `LidWorkManager` 가 `ioreg` 대신 IOKit 을,
/// `BlackWorkManager` 가 `pmset` 대신 `CGDisplayIsAsleep` 을 부르는 것과 같은 판단이다.
/// 근거는 `docs/plans/caffeinate-list/context.md`.
@MainActor
final class CaffeinateScanner: ObservableObject {
    @Published private(set) var processes: [CaffeinateProcess] = []
    /// 목록을 펼쳤는가. 펼치면 더 자주 훑는다.
    @Published var isExpanded = false {
        didSet {
            guard isExpanded != oldValue else { return }
            if isExpanded { refresh() }
            restartTimer()
        }
    }

    /// 접혀 있을 때. 개수 배지만 최신으로 두면 되므로 느슨하게 둔다.
    private static let collapsedInterval: TimeInterval = 5
    /// 펼쳤을 때.
    private static let expandedInterval: TimeInterval = 2

    private var timer: Timer?

    /// 창이 보이는 동안만 훑는다.
    ///
    /// 앱이 살아 있는 동안이 아니다. 메뉴바가 생기면서 창을 닫아도 세션이 끊기지 않게
    /// 바뀌었으므로(`docs/plans/menu-bar-item/spec.md`), 앱 생존에 묶어두면 창을 닫고
    /// 며칠 띄워둔 동안 계속 훑는다. 보이지 않는 것을 위해 훑지 않는다.
    func startPolling() {
        refresh()
        restartTimer()
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    /// 한 번 훑는다. 목록이 그대로면 `@Published` 를 건드리지 않는다.
    func refresh() {
        let found = Self.scan()
        guard found != processes else { return }
        processes = found
    }

    /// 중지한다. **이 앱이 띄운 것은 매니저를 거친다.**
    ///
    /// `kill` 로 바로 죽이면 `BlackWorkManager.handleTermination` 이 `stop()` 을 거치지 않은
    /// 종료를 **만료로 오인한다.** 만료 직전 구간이면 `sleepWhenDone` 이 켜져 있을 때
    /// `pmset sleepnow` 까지 간다. 사용자가 목록에서 끈 것이 맥을 잠재우면 안 된다.
    /// 근거는 `docs/plans/caffeinate-list/spec.md` 의 *함정* 절.
    ///
    /// - Returns: 실패하면 `errno` 문자열, 성공하면 nil.
    func stop(_ process: CaffeinateProcess, manager: BlackWorkManager) -> String? {
        defer { refresh() }

        if process.isOurs {
            manager.stop()
            return nil
        }

        guard kill(process.pid, SIGTERM) == 0 else {
            return String(cString: strerror(errno))
        }
        return nil
    }

    // MARK: - Private

    private func restartTimer() {
        timer?.invalidate()
        let interval = isExpanded ? Self.expandedInterval : Self.collapsedInterval
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private static func scan() -> [CaffeinateProcess] {
        let all = ProcessSnapshot.all()
        guard !all.isEmpty else { return [] }

        // 부모 이름을 찾을 때 쓴다. 같은 스냅숏에서 꺼내므로 추가 `sysctl` 이 없다.
        var namesByPID: [pid_t: String] = [:]
        namesByPID.reserveCapacity(all.count)
        for entry in all {
            namesByPID[entry.kp_proc.p_pid] = ProcessSnapshot.shortName(of: entry)
        }

        return all
            .filter { ProcessSnapshot.shortName(of: $0) == "caffeinate" }
            .map { entry -> CaffeinateProcess in
                let pid = entry.kp_proc.p_pid
                let ppid = entry.kp_eproc.e_ppid
                let arguments = argumentsOf(pid)
                let parentPath = ProcessSnapshot.executablePath(of: ppid)
                // `argv[0]` 은 실행 파일 이름이라 플래그가 아니다.
                let parsed = CaffeinateFlag.parse(Array((arguments ?? []).dropFirst()))

                return CaffeinateProcess(
                    pid: pid,
                    ppid: ppid,
                    uid: entry.kp_eproc.e_ucred.cr_uid,
                    parentName: ProcessSnapshot.friendlyName(
                        of: ppid, path: parentPath, shortName: namesByPID[ppid] ?? ""),
                    parentPath: parentPath ?? "",
                    started: ProcessSnapshot.startDate(of: entry),
                    flags: parsed.flags,
                    utility: parsed.utility,
                    argsUnreadable: arguments == nil)
            }
            .sorted { $0.started > $1.started }
    }

    /// `argv` 원본. 다른 사용자 소유면 커널이 막으므로 nil.
    private static func argumentsOf(_ pid: pid_t) -> [String]? {
        var limit: Int32 = 0
        var limitSize = MemoryLayout<Int32>.size
        var limitName: [Int32] = [CTL_KERN, KERN_ARGMAX]
        guard sysctl(&limitName, 2, &limit, &limitSize, nil, 0) == 0, limit > 0 else { return nil }

        var buffer = [CChar](repeating: 0, count: Int(limit))
        var size = Int(limit)
        var name: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        guard sysctl(&name, 3, &buffer, &size, nil, 0) == 0,
              size > MemoryLayout<Int32>.size else { return nil }

        var count: Int32 = 0
        withUnsafeMutableBytes(of: &count) { raw in
            _ = buffer.withUnsafeBytes { source in
                raw.copyMemory(from: UnsafeRawBufferPointer(rebasing: source[0..<MemoryLayout<Int32>.size]))
            }
        }
        guard count > 0 else { return nil }

        // 레이아웃: argc, 실행 경로, NUL 패딩, 그 뒤에 argc 개의 문자열.
        var index = MemoryLayout<Int32>.size
        while index < size, buffer[index] != 0 { index += 1 }
        while index < size, buffer[index] == 0 { index += 1 }

        var arguments: [String] = []
        while index < size, arguments.count < Int(count) {
            let start = index
            while index < size, buffer[index] != 0 { index += 1 }
            arguments.append(String(cString: Array(buffer[start..<index]) + [0]))
            index += 1
        }

        return arguments.isEmpty ? nil : arguments
    }
}
