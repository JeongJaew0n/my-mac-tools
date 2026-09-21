import AppKit
import Combine
import Darwin
import Foundation

/// 듣고 있는 localhost 포트 하나.
///
/// 같은 프로세스가 같은 포트를 IPv4·IPv6 두 소켓으로 듣는 일이 흔하다
/// (`ControlCenter:7000` 등). 그것은 서버 하나이므로 한 줄로 합치고 주소군만 모은다.
struct LocalPort: Identifiable, Equatable {
    let port: UInt16
    let pid: pid_t
    /// 사람이 읽을 프로세스 이름.
    let processName: String
    /// 실행 파일 전체 경로. 툴팁으로 보여준다. 못 읽으면 빈 문자열.
    let processPath: String
    /// 바인드된 주소들. `127.0.0.1` · `::1` · `0.0.0.0` · `::` 중에서.
    let addresses: [String]
    /// `IPv4` · `IPv6`.
    let families: [String]
    /// Apple 이 시스템 구성요소로 서명한 것. 함부로 끄면 안 된다.
    let isSystem: Bool
    /// 제어 터미널을 쥐고 있다 = 셸에서 띄운 것. 없다고 아닌 것은 아니다.
    let startedFromTerminal: Bool
    /// 번들·서명 식별자. 라벨을 붙일 근거가 없을 때 이것만 보여준다.
    let bundleIdentifier: String?

    var id: String { "\(pid):\(port)" }

    /// 표준으로 배정된 대역. IANA 기준 0–1023 이다.
    var isWellKnown: Bool { port < 1024 }

    /// 이 앱 자신인가. 자기를 끄는 버튼이 되면 안 되므로 중지를 막는다.
    var isSelf: Bool { pid == getpid() }

    /// 브라우저로 열 주소. HTTP 서버인지는 확인하지 않는다 — 확인하려면 요청을
    /// 보내야 하고, 남의 개발 서버에 앱이 말을 거는 것은 이 앱이 할 일이 아니다.
    var url: URL? { URL(string: "http://localhost:\(port)") }
}

/// 듣고 있는 localhost 포트를 훑는다.
///
/// `lsof` 를 띄우지 않고 `libproc` 을 직접 부른다. 실측으로 `lsof` 와 결과가 정확히
/// 일치했고 전수 조회가 5ms 미만이다. 근거는 `docs/plans/localhost-list/research.md`.
///
/// **내 uid 소유만 보인다.** `PROC_PIDLISTFDS` 가 다른 사용자의 프로세스를 막기 때문이다
/// (실측 — 188개 거부). 개발 서버는 전부 내 uid 라 목적에는 맞지만, 화면에서 그 사실을
/// 한 줄로 알린다.
@MainActor
final class LocalhostManager: ObservableObject {
    @Published private(set) var ports: [LocalPort] = []
    /// 중지에 실패한 이유. 성공하면 비운다.
    @Published var lastError: String?

    /// 탭 점과 메뉴바가 보는 값. 듣고 있는 것이 하나라도 있으면 켜진 것으로 본다.
    var isRunning: Bool { !ports.isEmpty }

    private static let interval: TimeInterval = 2

    /// localhost 로 닿는 주소. `0.0.0.0` · `::` 는 모든 인터페이스라 localhost 도 포함한다.
    private static let localAddresses: Set<String> = ["127.0.0.1", "::1", "0.0.0.0", "::"]

    private var timer: Timer?

    /// pid 별 코드 서명 캐시.
    ///
    /// 서명 조회가 비싸다 — 17개에 24~64ms(실측). 2초 폴링마다 부르면 메인 스레드가
    /// 걸린다. 살아 있는 pid 의 서명은 바뀌지 않으므로 한 번만 읽고 들고 있는다.
    /// 값이 nil 인 것도 캐시한다. 못 읽는 프로세스를 매번 다시 두드리지 않게.
    private var signingCache: [pid_t: ProcessSnapshot.SigningInfo?] = [:]

    /// 창이 보이는 동안만 훑는다. 카페인 목록과 같은 규칙이다.
    func startPolling() {
        refresh()
        timer?.invalidate()
        let timer = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    /// 한 번 훑는다. 목록이 그대로면 `@Published` 를 건드리지 않는다.
    func refresh() {
        let found = scan()
        guard found != ports else { return }
        ports = found
    }

    /// 그 포트를 잡고 있는 프로세스를 끈다.
    ///
    /// - Returns: 실패하면 `errno` 문자열, 성공하면 nil.
    func stop(_ port: LocalPort) -> String? {
        defer { refresh() }

        // 자기 자신은 끄지 않는다. 화면에서도 막아두지만 여기서 한 번 더 본다.
        guard !port.isSelf else { return nil }

        guard kill(port.pid, SIGTERM) == 0 else {
            return String(cString: strerror(errno))
        }
        return nil
    }

    func open(_ port: LocalPort) {
        guard let url = port.url else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Private

    /// 소켓 하나에서 뽑은 것. 합치기 전의 중간 형태다.
    private struct Socket {
        let pid: pid_t
        let port: UInt16
        let address: String
        let family: String
    }

    private func scan() -> [LocalPort] {
        let all = ProcessSnapshot.all()
        var namesByPID: [pid_t: String] = [:]
        namesByPID.reserveCapacity(all.count)
        for entry in all {
            namesByPID[entry.kp_proc.p_pid] = ProcessSnapshot.shortName(of: entry)
        }

        var sockets: [Socket] = []
        var hasTerminal: [pid_t: Bool] = [:]
        for entry in all {
            let pid = entry.kp_proc.p_pid
            guard pid > 0 else { continue }
            let found = Self.listeningSockets(of: pid)
            guard !found.isEmpty else { continue }
            sockets += found
            hasTerminal[pid] = ProcessSnapshot.hasControllingTerminal(entry)
        }

        // 죽은 pid 의 캐시는 버린다. 창을 오래 띄워두면 계속 쌓인다.
        let alive = Set(sockets.map(\.pid))
        signingCache = signingCache.filter { alive.contains($0.key) }

        // 같은 (pid, 포트) 를 한 줄로 합친다. 주소·주소군은 모아서 보여준다.
        let grouped = Dictionary(grouping: sockets) { "\($0.pid):\($0.port)" }

        return grouped.values.compactMap { group -> LocalPort? in
            guard let first = group.first else { return nil }
            let path = ProcessSnapshot.executablePath(of: first.pid)

            let signing = signingCache[first.pid]
                ?? { let read = ProcessSnapshot.signingInfo(of: first.pid)
                     signingCache[first.pid] = read
                     return read }()

            return LocalPort(
                port: first.port,
                pid: first.pid,
                processName: ProcessSnapshot.friendlyName(
                    of: first.pid, path: path, shortName: namesByPID[first.pid] ?? ""),
                processPath: path ?? "",
                addresses: Array(Set(group.map(\.address))).sorted(),
                families: Array(Set(group.map(\.family))).sorted(),
                isSystem: signing?.isPlatformBinary ?? false,
                startedFromTerminal: hasTerminal[first.pid] ?? false,
                bundleIdentifier: signing?.identifier)
        }
        // 이 화면을 여는 이유가 "몇 번이 잡혀 있나" 라서 포트 순으로 둔다.
        // 시작 시각 순서는 여기서 쓸 데가 없다.
        .sorted { ($0.port, $0.pid) < ($1.port, $1.pid) }
    }

    /// 그 프로세스가 듣고 있는 소켓들. 다른 사용자 소유면 커널이 막으므로 빈 배열.
    private static func listeningSockets(of pid: pid_t) -> [Socket] {
        let sizeHint = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard sizeHint > 0 else { return [] }

        // 조회 사이에 fd 가 늘어날 수 있다. 여유를 두고 받는다.
        let capacity = Int(sizeHint) / MemoryLayout<proc_fdinfo>.stride + 16
        var descriptors = [proc_fdinfo](repeating: proc_fdinfo(), count: capacity)
        let got = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, &descriptors,
                              Int32(capacity * MemoryLayout<proc_fdinfo>.stride))
        guard got > 0 else { return [] }

        var found: [Socket] = []
        for descriptor in descriptors.prefix(Int(got) / MemoryLayout<proc_fdinfo>.stride)
            where descriptor.proc_fdtype == UInt32(PROX_FDTYPE_SOCKET) {

            var info = socket_fdinfo()
            let read = proc_pidfdinfo(pid, descriptor.proc_fd, PROC_PIDFDSOCKETINFO, &info,
                                      Int32(MemoryLayout<socket_fdinfo>.stride))
            // UDP 는 LISTEN 상태가 없어 같은 기준으로 판정할 수 없다. TCP 만 본다.
            guard read > 0, info.psi.soi_kind == SOCKINFO_TCP else { continue }

            let tcp = info.psi.soi_proto.pri_tcp
            guard tcp.tcpsi_state == TSI_S_LISTEN else { continue }

            guard let socket = Self.socket(of: pid, tcp.tcpsi_ini) else { continue }
            found.append(socket)
        }
        return found
    }

    private static func socket(of pid: pid_t, _ ini: in_sockinfo) -> Socket? {
        // `insi_lport` 는 네트워크 바이트 순서다.
        let port = UInt16(bigEndian: UInt16(truncatingIfNeeded: ini.insi_lport))
        guard port > 0 else { return nil }

        let address: String
        let family: String

        if ini.insi_vflag & UInt8(INI_IPV4) != 0 {
            family = "IPv4"
            var raw = in_addr(s_addr: ini.insi_laddr.ina_46.i46a_addr4.s_addr)
            var text = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            inet_ntop(AF_INET, &raw, &text, socklen_t(INET_ADDRSTRLEN))
            address = String(cString: text)
        } else if ini.insi_vflag & UInt8(INI_IPV6) != 0 {
            family = "IPv6"
            var raw = ini.insi_laddr.ina_6
            var text = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
            inet_ntop(AF_INET6, &raw, &text, socklen_t(INET6_ADDRSTRLEN))
            address = String(cString: text)
        } else {
            return nil
        }

        guard localAddresses.contains(address) else { return nil }
        return Socket(pid: pid, port: port, address: address, family: family)
    }
}
