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
    private var listener: CInt = -1
    private var source: DispatchSourceRead?
    private let queue = DispatchQueue(label: "com.jjw.mymactools.api")

    init(handler: APIHandler) {
        self.handler = handler
    }

    func start() {
        let url = Self.socketURL
        let path = url.path

        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            NSLog("[api] 폴더를 만들지 못했습니다: \(error)")
            return
        }

        // 앱이 강제 종료되면 소켓 파일이 남는다. 그 위에 다시 bind 하면 EADDRINUSE 이므로
        // 시작할 때마다 지우고 만든다.
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

        guard listen(fd, 8) == 0 else {
            NSLog("[api] listen 실패: \(String(cString: strerror(errno)))")
            close(fd)
            return
        }

        listener = fd
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in self?.acceptOne() }
        source.resume()
        self.source = source

        NSLog("[api] 준비됨: \(path)")
    }

    func stop() {
        source?.cancel()
        source = nil
        if listener >= 0 {
            close(listener)
            listener = -1
        }
        try? FileManager.default.removeItem(at: Self.socketURL)
    }

    // MARK: - Private

    private func acceptOne() {
        let client = accept(listener, nil, nil)
        guard client >= 0 else { return }
        defer { close(client) }

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
