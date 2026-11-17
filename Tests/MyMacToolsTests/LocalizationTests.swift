import Foundation
import Testing
@testable import MyMacTools

/// 현지화 문자열이 코드와 맞는가. 빠지면 화면에 키(`hosts.noApp`)가 그대로 찍힌다.
struct LocalizationTests {

    @Test(arguments: languages)
    func fileIsReadable(_ language: String) {
        #expect(!strings(language).isEmpty, "\(language) 문자열 파일을 읽지 못했다")
    }

    @Test(arguments: languages)
    func everyKeyHasText(_ language: String) {
        let table = strings(language)
        let missing = L10n.Key.allCases.map(\.rawValue).filter { table[$0] == nil }
        #expect(missing.isEmpty, "\(language) 에 없는 키: \(missing)")
    }

    @Test func languagesHaveTheSameKeys() {
        let base = Set(strings("ko").keys)
        for language in languages.dropFirst() {
            let different = base.symmetricDifference(Set(strings(language).keys)).sorted()
            #expect(different.isEmpty, "ko 와 \(language) 의 키가 다르다: \(different)")
        }
    }

    /// 형식 지정자의 순서·종류가 다르면 `String(format:)` 이 틀린 값을 찍거나 죽는다.
    @Test func formatSpecifiersMatchAcrossLanguages() {
        let pattern = try! NSRegularExpression(pattern: "%(?:\\d+\\$)?[@dfsu]|%ld|%lld")
        func specifiers(_ text: String) -> [String] {
            pattern.matches(in: text, range: NSRange(text.startIndex..., in: text))
                .map { String(text[Range($0.range, in: text)!]) }
                .sorted()
        }
        let ko = strings("ko")
        for language in languages.dropFirst() {
            let other = strings(language)
            for (key, text) in ko {
                guard let translated = other[key] else { continue }
                #expect(specifiers(text) == specifiers(translated),
                        "\(key): ko \(specifiers(text)) / \(language) \(specifiers(translated))")
            }
        }
    }
}
