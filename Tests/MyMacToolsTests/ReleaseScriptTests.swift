import Foundation
import Testing

/// `scripts/release.sh` — 번호 올리기·태그·푸시·GitHub Release.
///
/// 임시 폴더에 맨 저장소(origin)와 작업 사본을 만들고, gh 는 받은 인자를 남기는 가짜로 바꿔 돌린다.
/// 사용자의 git 설정(전역·시스템)은 읽지 않는다.
struct ReleaseScriptTests {
    static let script = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("scripts/release.sh")

    struct Sandbox {
        let root: URL
        var origin: URL { root.appendingPathComponent("origin.git") }
        var work: URL { root.appendingPathComponent("work") }
        var plist: URL { work.appendingPathComponent("Resources/Info.plist") }
        var gh: URL { root.appendingPathComponent("gh") }
        var ghLog: URL { root.appendingPathComponent("gh.log") }

        var environment: [String: String] {
            ["PATH": "/usr/bin:/bin", "HOME": root.path, "MMT_GH": gh.path,
             "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1"]
        }

        init(version: String = "0.1.0") throws {
            root = FileManager.default.temporaryDirectory.appendingPathComponent("release-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: plist.deletingLastPathComponent(), withIntermediateDirectories: true)
            try """
            #!/bin/bash
            echo "$*" >> "\(ghLog.path)"
            """.write(to: gh, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: gh.path)
            try git(["init", "--quiet", "--bare", "--initial-branch=main", origin.path], in: root)
            try git(["init", "--quiet", "--initial-branch=main"])
            try git(["config", "user.name", "Test"])
            try git(["config", "user.email", "test@example.invalid"])
            try git(["remote", "add", "origin", origin.path])
            try setVersion(version)
            try git(["add", "."])
            try git(["commit", "--quiet", "-m", "Start"])
            try git(["push", "--quiet", "origin", "main"])
        }

        /// 원본과 같은 모양의 Info.plist. 스크립트가 한 줄만 바꾸는지 보려고 다른 키를 앞뒤에 둔다.
        func setVersion(_ version: String) throws {
            try """
            <?xml version="1.0" encoding="UTF-8"?>
            <plist version="1.0">
            <dict>
                <key>CFBundleName</key>
                <string>MyMacTools</string>
                <key>CFBundleShortVersionString</key>
                <string>\(version)</string>
                <key>LSMinimumSystemVersion</key>
                <string>14.0</string>
            </dict>
            </plist>

            """.write(to: plist, atomically: true, encoding: .utf8)
        }

        var version: String {
            let text = (try? String(contentsOf: plist, encoding: .utf8)) ?? ""
            guard let range = text.range(of: #"(?<=<key>CFBundleShortVersionString</key>\n    <string>)[^<]*"#,
                                         options: .regularExpression) else { return "" }
            return String(text[range])
        }

        @discardableResult
        func git(_ arguments: [String], in directory: URL? = nil) throws -> String {
            let result = try run("/usr/bin/git", arguments, in: directory ?? work)
            guard result.status == 0 else { throw GitError(arguments: arguments, output: result.output) }
            return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        struct GitError: Error {
            let arguments: [String]
            let output: String
        }

        func run(_ path: String, _ arguments: [String], in directory: URL) throws -> (status: Int32, output: String) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments
            process.currentDirectoryURL = directory
            process.environment = environment
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return (process.terminationStatus, String(decoding: data, as: UTF8.self))
        }

        func release(_ arguments: String...) throws -> (status: Int32, output: String) {
            try run("/bin/bash", [ReleaseScriptTests.script.path] + arguments, in: work)
        }

        /// origin 에 올라간 태그.
        var originTags: [String] {
            ((try? git(["tag", "--list"], in: origin)) ?? "").split(separator: "\n").map(String.init)
        }

        var ghCalls: [String] {
            ((try? String(contentsOf: ghLog, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
        }

        func remove() { try? FileManager.default.removeItem(at: root) }

        /// 거절했고, 그 이유가 `reason` 이다.
        func refuses(_ reason: String, _ arguments: String...) throws -> Bool {
            let result = try run("/bin/bash", [ReleaseScriptTests.script.path] + arguments, in: work)
            return result.status != 0 && result.output.contains(reason)
        }
    }

    @Test func initialTagsTheCurrentVersionWithoutBumping() throws {
        let box = try Sandbox()
        defer { box.remove() }
        let before = try box.git(["rev-parse", "HEAD"])
        let result = try box.release("initial", "First release")
        #expect(result.status == 0, "\(result.output)")
        #expect(box.version == "0.1.0")
        #expect(try box.git(["rev-parse", "HEAD"]) == before, "번호를 올리는 커밋이 없다")
        #expect(box.originTags == ["v0.1.0"])
        #expect(try box.git(["rev-parse", "v0.1.0^{commit}"], in: box.origin) == before)
        #expect(box.ghCalls.contains { $0.hasPrefix("release create v0.1.0 --verify-tag") })
        // 다른 호스트의 끊긴 로그인 때문에 거절하지 않도록 github.com 만 묻는다.
        #expect(box.ghCalls.first == "auth status --hostname github.com")
    }

    @Test func minorBumpsCommitsTagsAndPushesTogether() throws {
        let box = try Sandbox()
        defer { box.remove() }
        #expect(try box.release("initial", "First").status == 0)
        try box.git(["commit", "--quiet", "--allow-empty", "-m", "Add a feature"])

        let result = try box.release("minor", "Add a feature", "--trailer", "Co-Authored-By: Someone <x@example.invalid>")
        #expect(result.status == 0, "\(result.output)")
        #expect(box.version == "0.2.0")
        let message = try box.git(["log", "-1", "--format=%B"])
        #expect(message.hasPrefix("Release 0.2.0\n\nAdd a feature"))
        #expect(message.contains("Co-Authored-By: Someone <x@example.invalid>"), "git commit 인자를 넘긴다")
        #expect(try box.git(["diff", "--stat", "HEAD~1", "HEAD"]).contains("1 file changed, 1 insertion(+), 1 deletion(-)"),
                "Info.plist 의 한 줄만 바뀐다")
        #expect(box.originTags == ["v0.1.0", "v0.2.0"])
        let head = try box.git(["rev-parse", "HEAD"])
        #expect(try box.git(["rev-parse", "main"], in: box.origin) == head)
        #expect(try box.git(["rev-parse", "v0.2.0^{commit}"], in: box.origin) == head)
    }

    @Test func patchBumpsTheLastNumber() throws {
        let box = try Sandbox(version: "0.9.3")
        defer { box.remove() }
        #expect(try box.release("initial", "First").status == 0)
        #expect(try box.release("patch", "Fix a thing").status == 0)
        #expect(box.version == "0.9.4")
        #expect(try box.release("minor", "Add a thing").status == 0)
        #expect(box.version == "0.10.0", "숫자로 올린다")
        #expect(box.originTags.contains("v0.10.0"))
    }

    @Test func refusesADirtyTree() throws {
        let box = try Sandbox()
        defer { box.remove() }
        try "x".write(to: box.work.appendingPathComponent("loose.txt"), atomically: true, encoding: .utf8)
        #expect(try box.refuses("커밋하지 않은 변경", "initial", "First"))
        #expect(box.originTags.isEmpty && box.ghCalls.filter { $0.hasPrefix("release") }.isEmpty)
    }

    @Test func refusesASecondInitialAndAFirstMinor() throws {
        let box = try Sandbox()
        defer { box.remove() }
        #expect(try box.refuses("첫 릴리스는 initial", "minor", "Too early"))
        #expect(box.version == "0.1.0" && box.originTags.isEmpty)
        #expect(try box.release("initial", "First").status == 0)
        #expect(try box.refuses("이미 릴리스가 있다", "initial", "Again"))
        #expect(box.originTags == ["v0.1.0"])
    }

    /// 손으로 번호를 바꿨으면 무엇에서 올릴지 알 수 없다.
    @Test func refusesAVersionThatDoesNotMatchTheLastTag() throws {
        let box = try Sandbox()
        defer { box.remove() }
        #expect(try box.release("initial", "First").status == 0)
        try box.setVersion("0.5.0")
        try box.git(["commit", "--quiet", "-am", "Hand edit"])
        #expect(try box.refuses("마지막 태그", "patch", "Fix"))
        #expect(box.originTags == ["v0.1.0"])
    }

    @Test func refusesBehindOrigin() throws {
        let box = try Sandbox()
        defer { box.remove() }
        // 다른 곳에서 origin 에 올린 커밋.
        let other = box.root.appendingPathComponent("other")
        try box.git(["clone", "--quiet", box.origin.path, other.path], in: box.root)
        try box.git(["-c", "user.name=T", "-c", "user.email=t@example.invalid",
                     "commit", "--quiet", "--allow-empty", "-m", "Elsewhere"], in: other)
        try box.git(["push", "--quiet", "origin", "main"], in: other)
        #expect(try box.refuses("받지 않은 커밋", "initial", "First"))
        #expect(box.originTags.isEmpty)
    }

    @Test(arguments: [("1.0.0", "0.x 에 머문다"), ("0.1", "semver 가 아니다"), ("0.01.0", "semver 가 아니다")])
    func refusesVersionsOutsideZeroX(_ version: String, _ reason: String) throws {
        let box = try Sandbox(version: version)
        defer { box.remove() }
        #expect(try box.refuses(reason, "initial", "First"))
        #expect(box.originTags.isEmpty)
    }
}
