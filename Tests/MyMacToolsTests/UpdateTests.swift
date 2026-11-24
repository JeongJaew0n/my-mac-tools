import Foundation
import Testing
@testable import MyMacTools

/// 앱 업데이트. GitHub 에는 묻지 않는다 — 응답 꼴과 판단만 시험한다. 바꾸기 도우미는 임시 폴더의 가짜 앱 번들로 돌린다.
struct SemVerTests {
    @Test(arguments: ["0.1.0", "0.10.2", "1.2.3", "0.0.0"])
    func readsThreeNumbers(_ text: String) {
        #expect(SemVer(text)?.description == text)
    }

    @Test(arguments: ["", "0.1", "0.1.0.0", "v0.1.0", "0.1.x", "0.01.0", "0.1.-1", "0.1.0-beta", " 0.1.0", "0.١.0"])
    func rejectsOtherShapes(_ text: String) {
        #expect(SemVer(text) == nil)
    }

    /// 글자가 아니라 숫자로 비교한다 — 0.10.0 은 0.9.9 보다 크다.
    @Test func comparesNumerically() throws {
        #expect(try #require(SemVer("0.10.0")) > #require(SemVer("0.9.9")))
        #expect(try #require(SemVer("0.2.0")) > #require(SemVer("0.1.12")))
        #expect(try #require(SemVer("0.1.1")) > #require(SemVer("0.1.0")))
        #expect(SemVer("0.1.0") == SemVer(0, 1, 0))
    }

    @Test func tagNeedsTheV() {
        #expect(SemVer(tag: "v0.3.1") == SemVer(0, 3, 1))
        #expect(SemVer(tag: "0.3.1") == nil)
        #expect(SemVer(0, 3, 1).tag == "v0.3.1")
    }
}

struct UpdateCheckTests {
    static func commit(_ sha: String, _ message: String) -> [String: Any] {
        ["sha": sha, "commit": ["message": message]]
    }

    static func json(_ object: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: object)
    }

    static func installed(_ version: String?, commit: String? = "abc") -> UpdateCheck.Installed {
        UpdateCheck.Installed(version: version.flatMap { SemVer($0) }, commit: commit, dirty: false)
    }

    static func release(_ version: String) -> UpdateCheck.Release {
        UpdateCheck.Release(version: SemVer(version)!)
    }

    @Test func releaseReadsItsTag() throws {
        let data = Self.json(["tag_name": "v0.2.0", "name": "v0.2.0", "target_commitish": "main"])
        #expect(try UpdateCheck.parseRelease(data) == Self.release("0.2.0"))
    }

    /// 그 태그로 받아 빌드하므로 꼴이 다른 태그는 받지 않는다.
    @Test(arguments: ["0.2.0", "release-1", "v0.2", "v0.2.0-beta"])
    func releaseRejectsOtherTags(_ tag: String) {
        #expect(throws: (any Error).self) { try UpdateCheck.parseRelease(Self.json(["tag_name": tag])) }
    }

    @Test func newerReleaseIsNeeded() {
        #expect(Self.installed("0.1.0").needs(Self.release("0.2.0")))
        #expect(Self.installed("0.9.3").needs(Self.release("0.10.0")))
    }

    /// 같거나 낮으면 최신이다. 릴리스 전 로컬 빌드가 번호를 앞서 있어도 바꿀 것이 없다.
    @Test(arguments: ["0.2.0", "0.2.1", "0.3.0"])
    func sameOrNewerInstalledIsUpToDate(_ version: String) {
        #expect(!Self.installed(version).needs(Self.release("0.2.0")))
    }

    /// 0.1.0 전 빌드는 버전을 모른다 — 어떤 릴리스든 새것으로 본다.
    @Test func unknownInstalledNeedsAnyRelease() {
        #expect(Self.installed(nil).needs(Self.release("0.1.0")))
    }

    /// 바뀐 커밋은 빌드 커밋 기준이 먼저, 그것이 GitHub 에 없을 때 지금 버전의 태그.
    @Test func compareBasesTryTheBuildCommitFirst() {
        #expect(Self.installed("0.1.0", commit: "abc").compareBases == ["abc", "v0.1.0"])
        #expect(Self.installed(nil, commit: "abc").compareBases == ["abc"])
        #expect(Self.installed("0.1.0", commit: nil).compareBases == ["v0.1.0"])
    }

    @Test func compareListsCommitsWithTheirFirstLine() throws {
        let data = Self.json(["status": "ahead", "ahead_by": 2, "commits": [
            Self.commit("aaa111", "Add a thing\n\nLonger body"),
            Self.commit("bbb222", "Release 0.2.0"),
        ]])
        #expect(try UpdateCheck.parseCompare(data).map(\.title) == ["Add a thing", "Release 0.2.0"])
    }

    @Test func malformedResponseThrows() {
        #expect(throws: (any Error).self) { try UpdateCheck.parseCompare(Data("{}".utf8)) }
        #expect(throws: (any Error).self) { try UpdateCheck.parseRelease(Data("{}".utf8)) }
    }

    /// 앱이 다시 켜지면 끊기는 것이 하나라도 있으면 막는다.
    @Test func blockersNameWhatWouldStop() {
        #expect(UpdateManager.blockers(sleep: false, lid: false, cover: false, speedTest: false, capture: false).isEmpty)
        #expect(UpdateManager.blockers(sleep: true, lid: false, cover: true, speedTest: false, capture: true)
                == [.tabScreenOff, .tabCover, .tabCaptureEdit])
    }
}

/// `UpdateManager.swapScript` — 앱이 끝난 뒤 설치된 앱을 바꾸는 도우미.
struct SwapScriptTests {
    struct Sandbox {
        let root: URL
        var installed: URL { root.appendingPathComponent("Applications/MyMacTools.app") }
        var new: URL { root.appendingPathComponent("build/MyMacTools.app") }
        var backup: URL { root.appendingPathComponent("previous/MyMacTools.app") }
        var marker: URL { root.appendingPathComponent("launched-abc") }
        var result: URL { root.appendingPathComponent("result") }
        var script: URL { root.appendingPathComponent("swap.sh") }
        var launcher: URL { root.appendingPathComponent("launch.sh") }

        init() throws {
            root = FileManager.default.temporaryDirectory.appendingPathComponent("swap-\(UUID().uuidString)")
            for (app, label) in [(installed, "old"), (new, "new")] {
                try FileManager.default.createDirectory(at: app.appendingPathComponent("Contents/MacOS"),
                                                        withIntermediateDirectories: true)
                try label.write(to: app.appendingPathComponent("Contents/label"), atomically: true, encoding: .utf8)
            }
            try UpdateManager.swapScript.write(to: script, atomically: true, encoding: .utf8)
        }

        func label(_ app: URL) -> String? {
            try? String(contentsOf: app.appendingPathComponent("Contents/label"), encoding: .utf8)
        }

        /// 가짜 `open`. `starts` 면 켜진 것처럼 신호 파일을 쓴다. 누구로 불렸는지 남긴다.
        func makeLauncher(starts: Bool) throws {
            let body = """
            #!/bin/bash
            echo "$1" >> "\(root.path)/launched-paths"
            \(starts ? "touch \"\(marker.path)\"" : "true")
            """
            try body.write(to: launcher, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: launcher.path)
        }

        func run(pid: Int32, timeout: Int = 1) throws -> Int32 {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [script.path, String(pid), new.path, installed.path, backup.path,
                                 marker.path, result.path, String(timeout)]
            process.environment = ["MMT_LAUNCH": launcher.path, "PATH": "/usr/bin:/bin"]
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        }

        var resultText: String {
            (try? String(contentsOf: result, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }

        func remove() { try? FileManager.default.removeItem(at: root) }
    }

    /// 이미 끝난 프로세스의 pid. 앱이 끝난 상황을 흉내 낸다.
    static func finishedPID() throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/true")
        try process.run()
        process.waitUntilExit()
        return process.processIdentifier
    }

    @Test func replacesAndKeepsThePrevious() throws {
        let box = try Sandbox()
        defer { box.remove() }
        try box.makeLauncher(starts: true)
        #expect(try box.run(pid: Self.finishedPID()) == 0)
        #expect(box.resultText == "updated")
        #expect(box.label(box.installed) == "new")
        #expect(box.label(box.backup) == "old")
    }

    /// 새 앱이 켜졌다는 신호가 없으면 이전 판으로 되돌리고 그것을 켠다.
    @Test func rollsBackWhenTheNewAppDoesNotStart() throws {
        let box = try Sandbox()
        defer { box.remove() }
        try box.makeLauncher(starts: false)
        #expect(try box.run(pid: Self.finishedPID()) != 0)
        #expect(box.resultText == "rolledBack launch")
        #expect(box.label(box.installed) == "old")
        let launched = try String(contentsOf: box.root.appendingPathComponent("launched-paths"), encoding: .utf8)
        #expect(launched.split(separator: "\n").count == 2, "새 앱 한 번, 되돌린 앱 한 번 켰다")
    }

    /// 앱이 끝나지 않으면(종료가 취소됨) 아무것도 바꾸지 않는다.
    @Test func changesNothingWhileTheAppKeepsRunning() throws {
        let box = try Sandbox()
        defer { box.remove() }
        try box.makeLauncher(starts: true)
        let sleeper = Process()
        sleeper.executableURL = URL(fileURLWithPath: "/bin/sleep")
        sleeper.arguments = ["10"]
        try sleeper.run()
        defer { sleeper.terminate() }
        #expect(try box.run(pid: sleeper.processIdentifier) != 0)
        #expect(box.resultText == "cancelled")
        #expect(box.label(box.installed) == "old")
        #expect(!FileManager.default.fileExists(atPath: box.backup.path))
    }
}
