import Foundation
import Testing
@testable import MyMacTools

/// 앱 업데이트. GitHub 에는 묻지 않는다 — 응답 꼴만 시험한다. 바꾸기 도우미는 임시 폴더의 가짜 앱 번들로 돌린다.
struct UpdateCheckTests {
    static func commit(_ sha: String, _ message: String) -> [String: Any] {
        ["sha": sha, "commit": ["message": message]]
    }

    static func json(_ object: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: object)
    }

    @Test func compareListsNewCommitsWithTheirFirstLine() throws {
        let data = Self.json(["status": "ahead", "ahead_by": 2, "commits": [
            Self.commit("aaa111", "Add a thing\n\nLonger body"),
            Self.commit("bbb222", "Fix the thing"),
        ]])
        guard case .available(let available) = try UpdateCheck.parseCompare(data) else {
            Issue.record("새 커밋이 있어야 한다"); return
        }
        #expect(available.latest == "bbb222")
        #expect(available.commits.map(\.title) == ["Add a thing", "Fix the thing"])
        #expect(!available.installedUnknown)
    }

    @Test(arguments: ["identical", "behind"])
    func nothingAheadIsUpToDate(_ status: String) throws {
        let data = Self.json(["status": status, "ahead_by": 0, "commits": [[String: Any]]()])
        #expect(try UpdateCheck.parseCompare(data) == .upToDate)
    }

    /// 밀지 않은 로컬 커밋으로 빌드해 갈라졌어도 main 에 새 것이 있으면 업데이트할 것이 있다.
    @Test func divergedWithNewCommitsIsAvailable() throws {
        let data = Self.json(["status": "diverged", "ahead_by": 1, "behind_by": 3,
                              "commits": [Self.commit("ccc333", "On main")]])
        guard case .available(let available) = try UpdateCheck.parseCompare(data) else {
            Issue.record("새 커밋이 있어야 한다"); return
        }
        #expect(available.latest == "ccc333")
    }

    @Test func latestOnlyWhenInstalledIsUnknown() throws {
        let data = Self.json(Self.commit("ddd444", "Latest\nbody"))
        guard case .available(let available) = try UpdateCheck.parseLatest(data) else {
            Issue.record("최신 커밋이 있어야 한다"); return
        }
        #expect(available.installedUnknown && available.commits.map(\.title) == ["Latest"])
    }

    @Test func malformedResponseThrows() {
        #expect(throws: (any Error).self) { try UpdateCheck.parseCompare(Data("{}".utf8)) }
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
