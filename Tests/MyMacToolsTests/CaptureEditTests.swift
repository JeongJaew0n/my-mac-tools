import AppKit
import Testing
@testable import MyMacTools

/// 캡처 편집의 모델·내보내기. **사용자의 클립보드(`NSPasteboard.general`)는 쓰지 않는다** — 시험마다
/// 이름이 다른 클립보드를 만들어 쓰고 지운다. 편집 창과 안내 창도 띄우지 않는다.
struct CaptureEditTests {

    /// 흰 바탕 그림. `scale` 2 면 레티나 캡처처럼 픽셀이 포인트의 두 배다.
    static func whiteImage(points: CGSize, scale: CGFloat) -> NSBitmapImageRep {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(points.width * scale),
                                   pixelsHigh: Int(points.height * scale), bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: rep.pixelsWide, height: rep.pixelsHigh).fill()
        NSGraphicsContext.restoreGraphicsState()
        rep.size = points
        return rep
    }

    static func withPasteboard<T>(_ body: (NSPasteboard) throws -> T) rethrows -> T {
        let pasteboard = NSPasteboard(name: .init("MyMacToolsTests.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        return try body(pasteboard)
    }

    static func document(points: CGSize = CGSize(width: 100, height: 50), scale: CGFloat = 2) -> CaptureDocument {
        let rep = whiteImage(points: points, scale: scale)
        return CaptureDocument(image: CaptureImage(cgImage: rep.cgImage!, pointSize: rep.size))
    }

    /// 내보낸 PNG 를 다시 읽는다.
    static func exported(_ document: CaptureDocument) throws -> NSBitmapImageRep {
        let data = try #require(document.pngData())
        return try #require(NSBitmapImageRep(data: data))
    }

    /// 픽셀 색(0~1). `x`·`y` 는 포인트, 왼쪽 위가 원점.
    static func color(_ rep: NSBitmapImageRep, at point: CGPoint, scale: CGFloat) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let color = rep.colorAt(x: Int(point.x * scale), y: Int(point.y * scale))!.usingColorSpace(.sRGB)!
        return (color.redComponent, color.greenComponent, color.blueComponent)
    }

    // MARK: - 클립보드 읽기

    @Test func readsRetinaPNGWithItsPointSize() throws {
        try Self.withPasteboard { pasteboard in
            let rep = Self.whiteImage(points: CGSize(width: 100, height: 50), scale: 2)
            pasteboard.clearContents()
            pasteboard.setData(rep.representation(using: .png, properties: [:]), forType: .png)
            let image = try #require(CaptureImage.read(from: pasteboard))
            #expect(image.pixelSize == CGSize(width: 200, height: 100))
            #expect(image.pointSize == CGSize(width: 100, height: 50))
            #expect(image.scale == 2)
        }
    }

    @Test func readsTIFF() throws {
        try Self.withPasteboard { pasteboard in
            let rep = Self.whiteImage(points: CGSize(width: 30, height: 20), scale: 1)
            pasteboard.clearContents()
            pasteboard.setData(rep.tiffRepresentation, forType: .tiff)
            let image = try #require(CaptureImage.read(from: pasteboard))
            #expect(image.pixelSize == CGSize(width: 30, height: 20))
        }
    }

    @Test func noImageOnAPasteboardWithText() {
        Self.withPasteboard { pasteboard in
            pasteboard.clearContents()
            pasteboard.setString("글자뿐", forType: .string)
            #expect(CaptureImage.read(from: pasteboard) == nil)
        }
    }

    // MARK: - 내보내기

    /// 원본 해상도(레티나 2배) 그대로, 해상도 정보도 그대로.
    @Test func exportKeepsPixelsAndPointSize() throws {
        let document = Self.document()
        document.add(Mark(shape: .stroke([CGPoint(x: 5, y: 5), CGPoint(x: 50, y: 5)]), color: .red, width: .regular))
        let rep = try Self.exported(document)
        #expect(rep.pixelsWide == 200 && rep.pixelsHigh == 100)
        #expect(rep.size == CGSize(width: 100, height: 50))
    }

    /// 그린 자리는 그 색이고, 네모 안쪽과 바깥은 그대로다. 위아래가 뒤집히지 않았는지도 본다.
    @Test func rectangleLandsWhereItWasDrawn() throws {
        let document = Self.document()
        document.add(Mark(shape: .rectangle(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 60, y: 30)),
                          color: .red, width: .regular))
        let rep = try Self.exported(document)
        let edge = Self.color(rep, at: CGPoint(x: 10, y: 20), scale: 2)
        #expect(edge.r > 0.9 && edge.g < 0.4 && edge.b < 0.4, "왼쪽 변은 빨강: \(edge)")
        let top = Self.color(rep, at: CGPoint(x: 35, y: 10), scale: 2)
        #expect(top.r > 0.9 && top.g < 0.4, "위 변(y=10)은 빨강 — 뒤집혔으면 y=40 에 그려진다: \(top)")
        let inside = Self.color(rep, at: CGPoint(x: 35, y: 20), scale: 2)
        #expect(inside.r > 0.95 && inside.g > 0.95 && inside.b > 0.95, "안쪽은 그대로 흰색: \(inside)")
        let mirrored = Self.color(rep, at: CGPoint(x: 35, y: 40), scale: 2)
        #expect(mirrored.g > 0.95, "뒤집힌 자리에는 아무것도 없다: \(mirrored)")
    }

    /// 굵기는 포인트 단위다. 레티나에서는 픽셀로 두 배가 된다.
    @Test func widthIsInPoints() throws {
        let document = Self.document(points: CGSize(width: 60, height: 40))
        document.add(Mark(shape: .stroke([CGPoint(x: 0, y: 20), CGPoint(x: 60, y: 20)]), color: .black, width: .thick))
        let rep = try Self.exported(document)
        // 8pt 선 → 가운데에서 위아래로 4pt 안은 검정, 6pt 밖은 흰색.
        #expect(Self.color(rep, at: CGPoint(x: 30, y: 16.5), scale: 2).r < 0.1)
        #expect(Self.color(rep, at: CGPoint(x: 30, y: 13), scale: 2).r > 0.9)
    }

    @Test func textIsDrawnNearItsOrigin() throws {
        let document = Self.document(points: CGSize(width: 200, height: 80))
        document.add(Mark(shape: .text("WWW", at: CGPoint(x: 10, y: 10)), color: .blue, width: .regular))
        let rep = try Self.exported(document)
        var blue = 0
        for x in stride(from: 10, to: 110, by: 2) {
            for y in stride(from: 10, to: 50, by: 2) where Self.color(rep, at: CGPoint(x: x, y: y), scale: 2).b > 0.8
                && Self.color(rep, at: CGPoint(x: x, y: y), scale: 2).r < 0.3 { blue += 1 }
        }
        #expect(blue > 20, "글자 상자 안에 파란 픽셀이 있어야 한다 (\(blue))")
        let below = Self.color(rep, at: CGPoint(x: 30, y: 75), scale: 2)
        #expect(below.r > 0.95, "글자 아래쪽 멀리는 그대로")
    }

    /// 넣는 것은 PNG 하나. 원본 TIFF 가 남으면 붙여넣는 앱이 그것을 고를 수 있다.
    /// macOS 는 PNG 에서 바꾼 TIFF 를 스스로 함께 내놓는다 — 그것도 원본이 아니라 결과여야 한다.
    @Test func writesOnlyPNG() throws {
        try Self.withPasteboard { pasteboard in
            pasteboard.clearContents()
            pasteboard.setData(Self.whiteImage(points: CGSize(width: 10, height: 10), scale: 1).tiffRepresentation,
                               forType: .tiff)
            let document = Self.document()
            #expect(document.write(to: pasteboard))
            #expect(pasteboard.types?.first == .png)
            let back = try #require(CaptureImage.read(from: pasteboard))
            #expect(back.pixelSize == CGSize(width: 200, height: 100))
            let tiff = try #require(pasteboard.data(forType: .tiff).flatMap(NSBitmapImageRep.init(data:)))
            #expect(tiff.pixelsWide == 200, "TIFF 로 읽어도 원본(10×10)이 아니라 결과다")
        }
    }

    // MARK: - 되돌리기

    @Test func undoRemovesTheLastMark() {
        let document = Self.document()
        let a = Mark(shape: .arrow(from: .zero, to: CGPoint(x: 10, y: 10)), color: .red, width: .thin)
        let b = Mark(shape: .rectangle(from: .zero, to: CGPoint(x: 5, y: 5)), color: .blue, width: .thick)
        document.add(a)
        document.add(b)
        document.undo()
        #expect(document.marks == [a])
        document.undo()
        document.undo()
        #expect(document.marks.isEmpty && !document.canUndo)
    }

    /// 빈 글자는 넣지 않는다. 되돌리기 한 번이 아무것도 안 지우는 것처럼 보인다.
    @Test func blankTextIsNotAMark() {
        let document = Self.document()
        document.add(Mark(shape: .text("  ", at: .zero), color: .red, width: .regular))
        document.add(Mark(shape: .stroke([]), color: .red, width: .regular))
        #expect(document.marks.isEmpty)
    }

    // MARK: - 크기·모양 계산

    @Test func windowFitsHalfTheScreenAndNeverGrows() {
        let screen = CGSize(width: 1512, height: 945)
        let full = CaptureDocument.fittedSize(CGSize(width: 1512, height: 982), in: screen, fraction: 0.5)
        #expect(full.width <= 756 && full.height <= 472.5)
        #expect(abs(full.width / full.height - 1512 / 982) < 0.01, "비율 유지")
        let small = CGSize(width: 300, height: 200)
        #expect(CaptureDocument.fittedSize(small, in: screen, fraction: 0.5) == small, "작은 그림은 키우지 않는다")
    }

    @Test func arrowHeadIsSymmetricBehindTheTip() {
        let tip = CGPoint(x: 100, y: 0)
        let (left, right) = MarkRenderer.arrowHead(from: .zero, to: tip, width: PenWidth.regular.points)
        #expect(left.x < tip.x && right.x < tip.x)
        #expect(abs(left.y + right.y) < 1e-9 && abs(left.x - right.x) < 1e-9)
        let length = hypot(tip.x - left.x, tip.y - left.y)
        #expect(abs(length - max(PenWidth.regular.points * Design.Capture.arrowHeadRatio, Design.Capture.arrowHeadMin)) < 1e-9)
    }

    @Test func rectangleFromAnyDragDirection() {
        let r = MarkRenderer.rect(CGPoint(x: 50, y: 40), CGPoint(x: 10, y: 5))
        #expect(r == CGRect(x: 10, y: 5, width: 40, height: 35))
    }

    /// 펜 색은 라이트·다크에서 같다 — 결과 그림이 화면 모양을 따라 바뀌면 안 된다.
    @Test(arguments: PenColor.allCases)
    func penColorIgnoresAppearance(_ color: PenColor) {
        func value(_ name: NSAppearance.Name) -> NSColor {
            var result = NSColor.clear
            NSAppearance(named: name)!.performAsCurrentDrawingAppearance {
                result = color.nsColor.usingColorSpace(.sRGB)!
            }
            return result
        }
        #expect(value(.aqua) == value(.darkAqua))
    }
}

/// 캡처 편집 단축키의 기본값과 지움 기억.
struct CaptureShortcutDefaultsTests {
    func suite() -> UserDefaults {
        let name = "MyMacToolsTests.capture.\(UUID().uuidString)"
        return UserDefaults(suiteName: name)!
    }

    @Test func defaultsToControlCommandShiftE() {
        let defaults = suite()
        #expect(CaptureEditManager.savedShortcut(defaults) == CaptureEditManager.defaultShortcut)
        #expect(CaptureEditManager.defaultShortcut.display == "⌃⇧⌘E")
    }

    @Test func storedWins() throws {
        let defaults = suite()
        let mine = Shortcut(keyCode: 46, modifiers: NSEvent.ModifierFlags([.control, .option]).rawValue, displayKey: "M")
        defaults.set(try JSONEncoder().encode(mine), forKey: CaptureEditManager.shortcutKey)
        #expect(CaptureEditManager.savedShortcut(defaults) == mine)
    }

    /// 지운 단축키가 다음 실행에 기본값으로 되살아나면 안 된다.
    @Test func clearedStaysCleared() {
        let defaults = suite()
        defaults.set(true, forKey: CaptureEditManager.shortcutClearedKey)
        #expect(CaptureEditManager.savedShortcut(defaults) == nil)
    }
}
