import Foundation
import Testing
@testable import MyMacTools

struct CaffeinateParseTests {
    @Test func splitsBundledFlagsAndValues() {
        let parsed = CaffeinateFlag.parse(["-dimsu", "-t", "300", "-w12"])
        #expect(parsed.flags.map(\.label) == ["-d", "-i", "-m", "-s", "-u", "-t 300", "-w 12"])
        #expect(parsed.utility.isEmpty)
    }

    @Test func wrappedCommandStartsAtFirstNonFlag() {
        let parsed = CaffeinateFlag.parse(["-i", "make", "-j8"])
        #expect(parsed.flags.map(\.label) == ["-i"])
        #expect(parsed.utility == ["make", "-j8"])
    }

    /// 모르는 플래그에 설명을 지어 붙이지 않는다.
    @Test func unknownFlagHasNoExplanation() {
        let parsed = CaffeinateFlag.parse(["-x", "-i"])
        #expect(parsed.flags.first?.explanation == nil)
        #expect(parsed.flags.last?.explanation == .caffeineFlagI)
    }

    @Test func valueMissingAtEndIsKeptAsIs() {
        #expect(CaffeinateFlag.parse(["-t"]).flags.map(\.label) == ["-t"])
    }
}

struct IntelliJTemplateTests {
    @Test func defaultPaletteFillsEveryPlaceholder() throws {
        let rendered = IntelliJThemeTemplate.render(IntelliJThemeTemplate.defaultPalette)
        for text in [rendered.pluginXML, rendered.themeJSON, rendered.schemeXML] {
            #expect(!text.contains("{{"), "채우지 못한 자리표시자가 남았다")
        }
        #expect(try JSONSerialization.jsonObject(with: Data(rendered.themeJSON.utf8)) is [String: Any])
        #expect(try XMLDocument(xmlString: rendered.schemeXML).rootElement() != nil)
        #expect(try XMLDocument(xmlString: rendered.pluginXML).rootElement() != nil)
    }

    @Test func darkFollowsEditorBackground() {
        var palette = IntelliJThemeTemplate.defaultPalette
        palette[.editorBackground] = "#1E1F22"
        #expect(IntelliJThemeTemplate.render(palette).isDark)
        palette[.editorBackground] = "#FFFFFF"
        #expect(!IntelliJThemeTemplate.render(palette).isDark)
    }

    @Test func normalizesHex() {
        #expect(IntelliJThemeTemplate.normalized("#abc123") == "ABC123")
        #expect(IntelliJThemeTemplate.normalized(" abc123 ") == "ABC123")
        #expect(IntelliJThemeTemplate.normalized("#abc") == nil)
        #expect(IntelliJThemeTemplate.normalized("zzzzzz") == nil)
        #expect(IntelliJThemeTemplate.normalized(nil) == nil)
    }

    @Test func luminanceEnds() {
        #expect(IntelliJThemeTemplate.luminance("#000000") == 0)
        #expect(abs(IntelliJThemeTemplate.luminance("#FFFFFF") - 1) < 1e-9)
    }
}

struct IPAddressTests {
    @Test(arguments: ["192.168.0.1", "::1", "fe80::1", "2001:db8::8a2e:370:7334"])
    func accepts(_ text: String) { #expect(MacInfoManager.looksLikeIP(text)) }

    @Test(arguments: ["", "256.1.1.1", "1.2.3", "example.com", "<html>"])
    func rejects(_ text: String) { #expect(!MacInfoManager.looksLikeIP(text)) }
}
