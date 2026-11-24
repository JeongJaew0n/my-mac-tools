import AppKit
import Foundation

/// GitHub 의 최신 릴리스가 설치된 버전보다 새것이면 그 릴리스를 이 맥에서 빌드해 바꾼다. 앱 메뉴의 "업데이트…".
///
/// 결정과 근거는 `docs/plans/app-update/spec.md` 와 `docs/plans/app-versioning/spec.md`. 요약하면:
/// - 새것은 버전(semver)으로만 판단한다. GitHub `releases/latest` 의 태그 `v0.y.z` 와 `CFBundleShortVersionString`.
/// - main 최신이 아니라 그 릴리스 태그를 앱 전용 사본에 받아 `scripts/build-app.sh` 로 빌드한다.
/// - 바꾸기는 앱이 끝난 뒤 도우미 스크립트가 한다. 새 앱이 켜졌다는 신호가 30초 안에 없으면 이전 판으로 되돌린다.
@MainActor
final class UpdateManager: ObservableObject {

    enum Phase: Equatable {
        case idle
        case checking
        case upToDate(latest: SemVer)
        case noRelease
        case available(UpdateCheck.Available)
        case working(Step)
        case restarting
        case failed(Failure)
    }

    enum Step: Equatable {
        case fetching
        case building
        case verifying
    }

    enum Failure: Equatable {
        /// GitHub 에 묻지 못했다.
        case network(String)
        /// 명령줄 도구(git·swift)가 없다.
        case noTools
        /// 받기·빌드가 실패했다. 기록 끝부분.
        case command(String)
        /// 빌드는 됐는데 결과가 기대와 다르다.
        case verify(String)
        /// 설치된 앱을 바꿀 수 없는 곳에 있다.
        case notWritable(String)
    }

    @Published private(set) var phase: Phase = .idle
    /// 지난 업데이트에서 새 앱이 켜지지 않아 이 판으로 되돌아왔다.
    @Published private(set) var rolledBack = false

    let installed: UpdateCheck.Installed
    let repository: String

    /// 새 앱이 켜지기를 기다리는 시간(초). **정한 값** — 이 맥에서 앱이 켜지는 데 1초 안팎이라 넉넉히 잡았다.
    static let launchTimeout = 30

    init(bundle: Bundle = .main) {
        installed = UpdateCheck.Installed(bundle: bundle)
        repository = bundle.object(forInfoDictionaryKey: "MyMacToolsRepository") as? String ?? "JeongJaew0n/my-mac-tools"
        if let result = try? String(contentsOf: Self.paths.result, encoding: .utf8) {
            rolledBack = result.hasPrefix("rolledBack")
            try? FileManager.default.removeItem(at: Self.paths.result)
        }
    }

    // MARK: - 경로

    struct Paths {
        let root: URL
        var source: URL { root.appendingPathComponent("source") }
        var log: URL { root.appendingPathComponent("build.log") }
        var script: URL { root.appendingPathComponent("swap.sh") }
        var backup: URL { root.appendingPathComponent("previous/MyMacTools.app") }
        var result: URL { root.appendingPathComponent("result") }
        func marker(_ commit: String) -> URL { root.appendingPathComponent("launched-\(commit)") }
    }

    static let paths = Paths(root: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("MyMacTools/Update"))

    /// 켜졌다는 신호. 도우미가 이 파일을 기다린다. 앱이 켜질 때 한 번 부른다.
    static func markLaunched(bundle: Bundle = .main) {
        guard let commit = UpdateCheck.Installed(bundle: bundle).commit else { return }
        try? FileManager.default.createDirectory(at: paths.root, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: paths.marker(commit).path, contents: Data())
    }

    // MARK: - 확인

    func check() async {
        phase = .checking
        do {
            let result = try await UpdateCheck.fetch(repository: repository, installed: installed)
            switch result {
            case .upToDate(let latest): phase = .upToDate(latest: latest)
            case .noRelease: phase = .noRelease
            case .available(let available): phase = .available(available)
            }
        } catch {
            phase = .failed(.network(error.localizedDescription))
        }
    }

    // MARK: - 받기·빌드·바꾸기

    /// 새 버전이 보일 때만 부른다. 막는 이유가 하나라도 있으면 부르지 않는다(화면이 버튼을 잠근다).
    func update() async {
        guard case .available(let available) = phase else { return }
        let tag = available.release.tag
        let paths = Self.paths
        let installedApp = Bundle.main.bundleURL
        guard installedApp.pathExtension == "app",
              FileManager.default.isWritableFile(atPath: installedApp.deletingLastPathComponent().path) else {
            phase = .failed(.notWritable(installedApp.path))
            return
        }
        // 명령줄 도구가 없을 때 git 을 부르면 설치 창이 튀어나온다. 먼저 본다.
        guard await Shell.run("/usr/bin/xcode-select", ["-p"]).status == 0 else {
            phase = .failed(.noTools)
            return
        }

        try? FileManager.default.createDirectory(at: paths.root, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: paths.log.path, contents: Data())

        phase = .working(.fetching)
        let remote = "https://github.com/\(repository).git"
        let fetched: Shell.Result
        if FileManager.default.fileExists(atPath: paths.source.appendingPathComponent(".git").path) {
            // 앱 전용 사본이라 갈아엎어도 된다. `.build` 는 git 이 무시하는 곳이라 남아 다음 빌드를 빠르게 한다.
            // 태그를 다시 단 경우도 받도록 --force. 태그는 `$1` 로 넘긴다.
            fetched = await Shell.run("/bin/bash", ["-c", """
                git fetch --quiet --force origin "refs/tags/$1:refs/tags/$1" \
                  && git reset --hard --quiet "refs/tags/$1" && git clean -fdq
                """, "fetch", tag], in: paths.source, log: paths.log)
        } else {
            fetched = await Shell.run("/usr/bin/git", ["clone", "--quiet", "--branch", tag, remote, paths.source.path],
                                      log: paths.log)
        }
        guard fetched.status == 0 else { return fail(.command(Self.tail(of: paths.log))) }

        let head = await Shell.run("/usr/bin/git", ["-C", paths.source.path, "rev-parse", "HEAD"])
        let target = head.output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard head.status == 0, !target.isEmpty else { return fail(.command(head.output)) }

        phase = .working(.building)
        let build = await Shell.run("/bin/bash", ["scripts/build-app.sh"], in: paths.source, log: paths.log)
        guard build.status == 0 else { return fail(.command(Self.tail(of: paths.log))) }

        phase = .working(.verifying)
        let newApp = paths.source.appendingPathComponent(".build/MyMacTools.app")
        guard let newBundle = Bundle(url: newApp) else { return fail(.verify("bundle")) }
        let built = UpdateCheck.Installed(bundle: newBundle)
        guard built.commit == target else { return fail(.verify("commit")) }
        guard built.version == available.release.version else {
            return fail(.verify("version \(built.version.map(String.init(describing:)) ?? "?") ≠ \(available.release.version)"))
        }
        guard await Shell.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", newApp.path]).status == 0 else {
            return fail(.verify("codesign"))
        }

        // 도우미를 띄우고 끝낸다. 도우미는 앱이 끝나기를 기다렸다가 바꾼다.
        do {
            try Self.swapScript.write(to: paths.script, atomically: true, encoding: .utf8)
        } catch {
            return fail(.verify(error.localizedDescription))
        }
        try? FileManager.default.removeItem(at: paths.marker(target))
        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/bash")
        helper.arguments = [paths.script.path, String(ProcessInfo.processInfo.processIdentifier), newApp.path,
                            installedApp.path, paths.backup.path, paths.marker(target).path, paths.result.path,
                            String(Self.launchTimeout)]
        do {
            try helper.run()
        } catch {
            return fail(.verify(error.localizedDescription))
        }
        phase = .restarting
        NSApp.terminate(nil)
    }

    private func fail(_ failure: Failure) {
        phase = .failed(failure)
    }

    /// 기록 끝부분. 화면에 보일 만큼만.
    static func tail(of log: URL, lines: Int = 12) -> String {
        let text = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
        return text.split(separator: "\n", omittingEmptySubsequences: false).suffix(lines).joined(separator: "\n")
    }

    /// 막는 이유. 앱이 다시 켜지면 끊기는 것들이다.
    nonisolated static func blockers(sleep: Bool, lid: Bool, cover: Bool, speedTest: Bool, capture: Bool) -> [L10n.Key] {
        var keys: [L10n.Key] = []
        if sleep { keys.append(.tabScreenOff) }
        if lid { keys.append(.tabLid) }
        if cover { keys.append(.tabCover) }
        if speedTest { keys.append(.tabSpeedTest) }
        if capture { keys.append(.tabCaptureEdit) }
        return keys
    }

    // MARK: - 도우미 스크립트

    /// 앱이 끝난 뒤 설치된 앱을 바꾼다.
    ///
    /// `swap.sh <앱 pid> <새 앱> <설치된 앱> <보관 자리> <켜짐 신호 파일> <결과 파일> [기다릴 초]`
    ///
    /// - 앱이 기다릴 시간 안에 끝나지 않으면(종료가 취소됨) 아무것도 바꾸지 않는다.
    /// - 설치된 앱을 보관 자리로 옮기고 새 앱을 복사한 뒤 켠다.
    /// - 새 앱이 신호 파일을 기다릴 시간 안에 쓰지 않으면 새 앱을 끄고 보관한 것으로 되돌린 뒤 켠다.
    ///
    /// 켜는 명령은 `MMT_LAUNCH` 로 바꿀 수 있다(시험용).
    nonisolated static let swapScript = #"""
    #!/bin/bash
    set -u
    PID="$1"; NEW="$2"; INSTALLED="$3"; BACKUP="$4"; MARKER="$5"; RESULT="$6"; TIMEOUT="${7:-30}"
    LAUNCH="${MMT_LAUNCH:-/usr/bin/open}"
    TICKS=$((TIMEOUT * 5))

    # 1. 앱이 끝나기를 기다린다.
    i=0
    while kill -0 "$PID" 2>/dev/null; do
        i=$((i + 1))
        if [ "$i" -gt "$TICKS" ]; then echo "cancelled" > "$RESULT"; exit 1; fi
        sleep 0.2
    done

    # 2. 보관하고 바꾼다.
    rm -rf "$BACKUP"
    mkdir -p "$(dirname "$BACKUP")"
    if ! mv "$INSTALLED" "$BACKUP"; then
        echo "failed move" > "$RESULT"; "$LAUNCH" "$INSTALLED"; exit 1
    fi
    if ! /usr/bin/ditto "$NEW" "$INSTALLED"; then
        rm -rf "$INSTALLED"; mv "$BACKUP" "$INSTALLED"
        echo "rolledBack copy" > "$RESULT"; "$LAUNCH" "$INSTALLED"; exit 1
    fi
    rm -f "$MARKER"
    "$LAUNCH" "$INSTALLED"

    # 3. 켜졌다는 신호를 기다린다.
    i=0
    while [ "$i" -lt "$TICKS" ]; do
        if [ -f "$MARKER" ]; then echo "updated" > "$RESULT"; exit 0; fi
        i=$((i + 1)); sleep 0.2
    done

    # 4. 켜지지 않았다. 떠 있으면 끄고 되돌린다.
    pkill -f -U "$(id -u)" "$INSTALLED/Contents/MacOS/" 2>/dev/null
    sleep 1
    rm -rf "$INSTALLED"
    mv "$BACKUP" "$INSTALLED"
    echo "rolledBack launch" > "$RESULT"
    "$LAUNCH" "$INSTALLED"
    exit 1
    """#
}

// MARK: - 버전

/// semver 번호 `major.minor.patch`. 이 앱은 0.x 에 머문다(`CLAUDE.md` 버전 절).
///
/// 사전 릴리스(`-beta`)·빌드 메타데이터는 쓰지 않아 받지 않는다.
struct SemVer: Comparable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int

    init(_ major: Int, _ minor: Int, _ patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// `0.2.10` 꼴. 숫자 셋이 아니거나 앞에 0 을 붙인 자리(`01`)가 있으면 `nil`.
    init?(_ text: String) {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        var numbers: [Int] = []
        for part in parts {
            guard !part.isEmpty, part.allSatisfy(\.isASCII), part.allSatisfy(\.isNumber),
                  part == "0" || !part.hasPrefix("0"), let number = Int(part) else { return nil }
            numbers.append(number)
        }
        self.init(numbers[0], numbers[1], numbers[2])
    }

    /// 릴리스 태그 `v0.2.10`. `v` 가 없으면 `nil`.
    init?(tag: String) {
        guard tag.hasPrefix("v") else { return nil }
        self.init(String(tag.dropFirst()))
    }

    var tag: String { "v\(self)" }
    var description: String { "\(major).\(minor).\(patch)" }

    static func < (a: SemVer, b: SemVer) -> Bool {
        (a.major, a.minor, a.patch) < (b.major, b.minor, b.patch)
    }
}

// MARK: - GitHub 비교

enum UpdateCheck: Equatable {
    /// 설치된 버전이 최신 릴리스와 같거나 더 높다.
    case upToDate(latest: SemVer)
    /// GitHub 에 릴리스가 하나도 없다.
    case noRelease
    case available(Available)

    struct Release: Equatable {
        let version: SemVer
        var tag: String { version.tag }
    }

    struct Available: Equatable {
        let release: Release
        /// 설치된 빌드 다음부터 그 릴리스까지, 오래된 것부터. 비교할 기준이 GitHub 에 없으면 비어 있다.
        let commits: [Commit]
        /// 설치된 앱의 버전을 모른다(0.1.0 전 빌드).
        let installedUnknown: Bool
    }

    struct Commit: Equatable, Identifiable {
        let sha: String
        /// 커밋 메시지 첫 줄.
        let title: String
        var id: String { sha }
    }

    /// 설치된 앱이 아는 자기 버전과 빌드 커밋.
    struct Installed: Equatable {
        let version: SemVer?
        let commit: String?
        /// 커밋하지 않은 수정이 섞인 빌드.
        let dirty: Bool

        init(version: SemVer?, commit: String?, dirty: Bool) {
            self.version = version
            self.commit = commit
            self.dirty = dirty
        }

        init(bundle: Bundle) {
            version = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String).flatMap { SemVer($0) }
            commit = bundle.object(forInfoDictionaryKey: "MyMacToolsCommit") as? String
            dirty = bundle.object(forInfoDictionaryKey: "MyMacToolsDirty") as? Bool ?? false
        }

        /// 이 릴리스가 새것인가. 설치된 버전을 모르면 새것으로 본다.
        func needs(_ release: Release) -> Bool {
            version.map { release.version > $0 } ?? true
        }

        /// 바뀐 커밋 목록을 구할 기준. 빌드 커밋이 GitHub 에 없으면(로컬 커밋으로 빌드) 그 버전의 태그로.
        var compareBases: [String] {
            [commit, version?.tag].compactMap { $0 }
        }
    }

    static func fetch(repository: String, installed: Installed) async throws -> UpdateCheck {
        let api = "https://api.github.com/repos/\(repository)"
        let (data, response) = try await get("\(api)/releases/latest")
        // 릴리스가 하나도 없으면 404.
        if response.statusCode == 404 { return .noRelease }
        guard response.statusCode == 200 else { throw HTTPError(status: response.statusCode) }
        let release = try parseRelease(data)
        guard installed.needs(release) else { return .upToDate(latest: release.version) }

        var commits: [Commit] = []
        for base in installed.compareBases {
            let (data, response) = try await get("\(api)/compare/\(base)...\(release.tag)")
            // GitHub 에 없는 커밋·태그면 404 — 다음 기준으로.
            if response.statusCode == 404 { continue }
            guard response.statusCode == 200 else { throw HTTPError(status: response.statusCode) }
            commits = try parseCompare(data)
            break
        }
        return .available(Available(release: release, commits: commits, installedUnknown: installed.version == nil))
    }

    struct HTTPError: LocalizedError {
        let status: Int
        var errorDescription: String? { "HTTP \(status)" }
    }

    private static func get(_ address: String) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: URL(string: address)!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        // 개인 정보 없이 앱 이름만.
        request.setValue("MyMacTools", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, response as! HTTPURLResponse)
    }

    /// `releases/latest` 응답. 태그가 `v0.y.z` 꼴이 아니면 오류 — 그 태그로 받아 빌드하므로 아무거나 받지 않는다.
    static func parseRelease(_ data: Data) throws -> Release {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = object["tag_name"] as? String else { throw CocoaError(.coderReadCorrupt) }
        guard let version = SemVer(tag: tag) else { throw ReleaseTagError(tag: tag) }
        return Release(version: version)
    }

    struct ReleaseTagError: LocalizedError {
        let tag: String
        var errorDescription: String? { "tag \(tag)" }
    }

    /// compare 응답의 커밋(기준에 없고 릴리스에 있는 것), 오래된 것부터.
    static func parseCompare(_ data: Data) throws -> [Commit] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let commits = object["commits"] as? [[String: Any]] else { throw CocoaError(.coderReadCorrupt) }
        return commits.compactMap(commit)
    }

    private static func commit(_ object: [String: Any]) -> Commit? {
        guard let sha = object["sha"] as? String,
              let message = (object["commit"] as? [String: Any])?["message"] as? String else { return nil }
        let title = message.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
        return Commit(sha: sha, title: title)
    }
}

// MARK: - 명령 실행

/// 업데이트가 부르는 명령. 메인 스레드를 막지 않는다.
enum Shell {
    struct Result {
        let status: Int32
        let output: String
    }

    /// 앱을 Finder 에서 켜면 PATH 가 짧다. 빌드 스크립트가 쓰는 swift·codesign·sips·PlistBuddy 가 보이게 한다.
    static let environment: [String: String] = {
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:/usr/libexec"
        return env
    }()

    /// `log` 를 주면 출력을 그 파일에 덧붙이고, 아니면 돌려준다.
    static func run(_ path: String, _ arguments: [String], in directory: URL? = nil, log: URL? = nil) async -> Result {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments
            process.environment = environment
            if let directory { process.currentDirectoryURL = directory }
            let pipe = Pipe()
            let handle = log.flatMap { try? FileHandle(forWritingTo: $0) }
            if let handle {
                handle.seekToEndOfFile()
                process.standardOutput = handle
                process.standardError = handle
            } else {
                process.standardOutput = pipe
                process.standardError = pipe
            }
            process.terminationHandler = { finished in
                let output = handle == nil
                    ? String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self) : ""
                try? handle?.close()
                continuation.resume(returning: Result(status: finished.terminationStatus, output: output))
            }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: Result(status: -1, output: error.localizedDescription))
            }
        }
    }

    static func script(_ text: String, in directory: URL, log: URL) async -> Result {
        await run("/bin/bash", ["-c", text], in: directory, log: log)
    }
}
