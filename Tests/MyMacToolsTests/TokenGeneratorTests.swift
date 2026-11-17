import Foundation
import Testing

/// `scripts/build-tokens.py` — 토큰의 단일 출처에서 `Design.swift` 를 만드는 생성기.
/// 파이썬을 따로 띄워 생성기 모듈을 불러 시험한다. 파일은 쓰지 않는다.
struct TokenGeneratorTests {
    static let script = repositoryRoot.appendingPathComponent("scripts/build-tokens.py").path

    /// 생성기를 모듈로 불러 `body` 를 돌린다. 종료 코드와 출력.
    func python(_ body: String) throws -> (status: Int32, output: String) {
        let program = """
        import importlib.util, json, sys
        spec = importlib.util.spec_from_file_location("bt", \(String(reflecting: Self.script)))
        bt = importlib.util.module_from_spec(spec); spec.loader.exec_module(bt)
        def tokens(primitive=None, semantic=None):
            return {"primitive": primitive or {}, "semantic": semantic or {}}
        def fails(document):
            try:
                bt.resolve(document)
            except SystemExit as error:
                print("FAIL", error); return
            print("OK")
        \(body)
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", "-I", "-c", program]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return (process.terminationStatus, output)
    }

    /// 생성물이 토큰과 같다. 다르면 누군가 `Design.swift` 를 직접 고쳤거나 생성을 잊었다.
    @Test func generatedFilesAreUpToDate() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", Self.script, "--check"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }

    @Test func referencesResolveThroughLayers() throws {
        let result = try python("""
        numbers, _, _ = bt.resolve(tokens({"space": {"5": {"value": 8}}},
                                          {"space": {"inline": {"value": "{primitive.space.5}"},
                                                     "gap": {"value": "{semantic.space.inline}"}}}))
        print(numbers["semantic.space.gap"])
        """)
        #expect(result.status == 0)
        #expect(result.output.trimmingCharacters(in: .whitespacesAndNewlines) == "8")
    }

    /// 잘못된 토큰은 생성하지 않고 멈춘다. 멈추지 않으면 틀린 값이 화면 코드로 간다.
    @Test(arguments: [
        ("순환 참조", ##"fails(tokens({"space": {"a": {"value": "{primitive.space.b}"}, "b": {"value": "{primitive.space.a}"}}}))"##),
        ("없는 참조", ##"fails(tokens(semantic={"space": {"x": {"value": "{primitive.space.9}"}}}))"##),
        ("숫자 아님", ##"fails(tokens({"space": {"a": {"value": "eight"}}}))"##),
        ("틀린 색", ##"fails(tokens({"color": {"a": {"value": "#12345"}}}))"##),
        ("모르는 시스템 색", ##"fails(tokens(semantic={"color": {"a": {"value": {"system": "teal"}}}}))"##),
        ("알파 범위", ##"fails(tokens({"color": {"a": {"value": "#FFFFFF"}}}, {"color": {"b": {"value": {"light": {"ref": "{primitive.color.a}", "alpha": 1.5}, "dark": "{primitive.color.a}"}}}}))"##),
        ("시스템 색에 알파", ##"fails(tokens(semantic={"color": {"s": {"value": {"system": "red"}}, "b": {"value": {"light": {"ref": "{semantic.color.s}", "alpha": 0.5}, "dark": "{semantic.color.s}"}}}}))"##),
    ])
    func rejectsBrokenTokens(_ name: String, _ body: String) throws {
        let result = try python(body)
        #expect(result.output.hasPrefix("FAIL"), "\(name): \(result.output)")
    }

    /// 테마는 값만 덮어쓴다. 역할 이름은 그대로, 가리키던 값이 따라 바뀐다.
    @Test func themeOverridesOnlyPrimitiveValues() throws {
        let result = try python("""
        base = tokens({"space": {"5": {"value": 8}}}, {"space": {"inline": {"value": "{primitive.space.5}"}}})
        bt.merge(base, {"$name": "roomy", "primitive": {"space": {"5": {"value": 12}}}})
        numbers, _, _ = bt.resolve(base)
        print(numbers["semantic.space.inline"], sorted(numbers))
        """)
        #expect(result.output.trimmingCharacters(in: .whitespacesAndNewlines)
                == "12 ['primitive.space.5', 'semantic.space.inline']")
    }
}
