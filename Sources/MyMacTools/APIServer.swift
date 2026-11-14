import Darwin
import Foundation

/// 에이전트가 이 앱의 기능을 셸에서 쓰게 해 주는 유닉스 도메인 소켓 서버.
///
/// 포트를 열지 않는다. 이 앱에는 **듣고 있는 포트를 보여주는 Tool** 이 있어서 HTTP 서버를
/// 열면 자기 목록에 자기가 나타나고, 포트는 같은 맥의 다른 프로그램에도 열려 있어 토큰이
/// 필요해진다. 유닉스 소켓은 파일 권한(`0600`)이 그 일을 대신한다.
/// 근거는 `docs/plans/agent-api/context.md`.
///
/// 프로토콜은 줄 단위 JSON 이다. 요청 한 줄을 받고 응답 한 줄을 쓰고 닫는다.
/// 프레이밍을 직접 만들지 않아도 `curl --unix-socket` · `nc -U` · python 한 줄로 다 된다.
final class APIServer {

    /// 소켓 자리.
    ///
    /// 샌드박스가 아니라서 이 경로를 그대로 쓴다. 나중에 샌드박스를 켜면 컨테이너 안으로
    /// 밀려나고, 그러면 컨테이너 밖의 에이전트가 닿지 못한다.
    static var socketURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MyMacTools", isDirectory: true)
            .appendingPathComponent("api.sock")
    }

    private let handler: APIHandler
    private var source: DispatchSourceRead?
    /// 우리가 bind 한 소켓 파일의 inode. 종료할 때 **우리 것일 때만** 지운다.
    private var boundInode: ino_t?
    private let queue = DispatchQueue(label: "com.jjw.mymactools.api")

    init(handler: APIHandler) {
        self.handler = handler
    }

    func start() {
        // 클라이언트가 먼저 끊으면(10초 타임아웃·Ctrl-C) 응답을 쓰는 순간 SIGPIPE 가 와서
        // **앱이 죽는다**(실측 — 종료 코드 141). 덮개를 켠 채 죽으면 맥이 잠들지 않는 상태로 남는다.
        // 소켓마다 거는 `SO_NOSIGPIPE` 로는 모자랐다 — 이미 끊긴 연결을 accept 하면 옵션이
        // 걸리지 않아 그대로 죽었다(실측). 프로세스 전체에서 무시하고, write 의 EPIPE 로 받는다.
        signal(SIGPIPE, SIG_IGN)

        let url = Self.socketURL
        let path = url.path

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            NSLog("[api] 폴더를 만들지 못했습니다: \(error)")
            return
        }

        // 다른 인스턴스(설치본과 `.build` 의 것 등)가 이미 듣고 있으면 빼앗지 않는다.
        // 빼앗으면 요청이 엉뚱한 쪽으로 가고, 그쪽을 끄면 소켓이 사라져 살아 있는 원래 앱이
        // "떠 있지 않다" 로 보인다.
        if Self.isListening(path) {
            NSLog("[api] 다른 인스턴스가 이미 듣고 있어 시작하지 않습니다: \(path)")
            return
        }

        // 앱이 강제 종료되면 소켓 파일이 남는다. 그 위에 다시 bind 하면 EADDRINUSE 이므로
        // 듣는 쪽이 없으면 지우고 만든다.
        try? FileManager.default.removeItem(at: url)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            NSLog("[api] socket 실패: \(String(cString: strerror(errno)))")
            return
        }

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        guard path.utf8.count < capacity else {
            NSLog("[api] 소켓 경로가 너무 깁니다: \(path)")
            close(fd)
            return
        }
        _ = withUnsafeMutableBytes(of: &address.sun_path) { raw in
            path.withCString { source in
                strncpy(raw.baseAddress!.assumingMemoryBound(to: CChar.self), source, capacity - 1)
            }
        }

        let size = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bound = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, size) }
        }
        guard bound == 0 else {
            NSLog("[api] bind 실패: \(String(cString: strerror(errno)))")
            close(fd)
            return
        }

        // 이 사용자만 열 수 있게 한다. 이것이 이 API 의 인증이다.
        chmod(path, 0o600)
        boundInode = Self.inode(of: path)

        guard listen(fd, 8) == 0 else {
            NSLog("[api] listen 실패: \(String(cString: strerror(errno)))")
            close(fd)
            return
        }

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in self?.acceptOne(fd) }
        // GCD 는 fd 를 cancel handler 가 돈 **뒤에** 닫으라고 한다. 먼저 닫으면 그 번호가
        // 재사용된 다른 fd 를 소스가 건드릴 수 있다.
        source.setCancelHandler { close(fd) }
        source.resume()
        self.source = source

        NSLog("[api] 준비됨: \(path)")
    }

    func stop() {
        // fd 는 cancel handler 가 닫는다.
        source?.cancel()
        source = nil
        // 그새 다른 인스턴스가 같은 경로에 새로 만들었으면 그것은 지우지 않는다.
        if let boundInode, Self.inode(of: Self.socketURL.path) == boundInode {
            try? FileManager.default.removeItem(at: Self.socketURL)
        }
    }

    /// 그 경로에서 누가 듣고 있는가 — 붙어 보고 바로 끊는다.
    private static func isListening(_ path: String) -> Bool {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        guard path.utf8.count < capacity else { return false }
        _ = withUnsafeMutableBytes(of: &address.sun_path) { raw in
            path.withCString { source in
                strncpy(raw.baseAddress!.assumingMemoryBound(to: CChar.self), source, capacity - 1)
            }
        }
        let size = socklen_t(MemoryLayout<sockaddr_un>.size)
        return withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, size) == 0 }
        }
    }

    private static func inode(of path: String) -> ino_t? {
        var info = stat()
        return stat(path, &info) == 0 ? info.st_ino : nil
    }

    // MARK: - Private

    private func acceptOne(_ listener: CInt) {
        let client = accept(listener, nil, nil)
        guard client >= 0 else { return }
        defer { close(client) }

        // SIGPIPE 는 `start()` 에서 프로세스 전체로 막았다. 소켓에도 걸어 두는 것은 겹으로다.
        var one: Int32 = 1
        setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))
        // 요청은 큐 하나에서 차례로 처리한다. 붙어 놓고 아무것도 안 보내는 클라이언트 하나가
        // 뒤의 요청을 모두 막지 않게 읽기·쓰기에 시한을 둔다. 클라이언트의 시한(10초)보다 짧게.
        var limit = timeval(tv_sec: 5, tv_usec: 0)
        setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &limit, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(client, SOL_SOCKET, SO_SNDTIMEO, &limit, socklen_t(MemoryLayout<timeval>.size))

        guard let line = readLine(from: client) else { return }

        // 상태를 건드리는 것은 모두 메인 액터에서 한다. 여기서 기다렸다가 답을 쓴다.
        let semaphore = DispatchSemaphore(value: 0)
        var response = Data()
        Task { @MainActor in
            response = self.handler.respond(to: line)
            semaphore.signal()
        }
        semaphore.wait()

        response.append(0x0A)
        response.withUnsafeBytes { raw in
            var sent = 0
            while sent < raw.count {
                let n = write(client, raw.baseAddress!.advanced(by: sent), raw.count - sent)
                guard n > 0 else { break }
                sent += n
            }
        }
    }

    /// 줄 하나를 읽는다. 개행이 없으면 상대가 닫을 때까지 읽는다.
    private func readLine(from fd: CInt) -> Data? {
        var collected = Data()
        var byte: UInt8 = 0
        // 한 줄짜리 요청이라 상한을 둔다. 이보다 긴 요청은 이 API 에 없다.
        while collected.count < 64 * 1024 {
            let n = read(fd, &byte, 1)
            guard n == 1 else { break }
            if byte == 0x0A { break }
            collected.append(byte)
        }
        return collected.isEmpty ? nil : collected
    }
}
