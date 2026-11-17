import Foundation

/// 저장소 뿌리. 시험은 `Resources/` 의 문자열 파일을 직접 읽는다 — 앱 번들이 아니라
/// 저장소에 있는 것이 고칠 대상이다.
let repositoryRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // MyMacToolsTests
    .deletingLastPathComponent()  // Tests
    .deletingLastPathComponent()

let languages = ["ko", "en", "ja"]

/// `Localizable.strings` 를 키 → 값으로.
func strings(_ language: String) -> [String: String] {
    let url = repositoryRoot.appendingPathComponent("Resources/\(language).lproj/Localizable.strings")
    return NSDictionary(contentsOf: url) as? [String: String] ?? [:]
}
