import AppKit

// 캡처 편집의 모델 — 그림, 그 위에 그린 것, 내보내기. 창과 상관없이 시험할 수 있게 화면 코드와 나눈다.
// 결정과 근거는 docs/plans/capture-edit/spec.md.

/// 그리는 도구.
enum CaptureTool: String, CaseIterable, Identifiable {
    case pen
    case rectangle
    case arrow
    case text

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .pen: return "pencil.tip"
        case .rectangle: return "rectangle"
        case .arrow: return "arrow.up.right"
        case .text: return "textformat"
        }
    }

    var titleKey: L10n.Key {
        switch self {
        case .pen: return .captureToolPen
        case .rectangle: return .captureToolRectangle
        case .arrow: return .captureToolArrow
        case .text: return .captureToolText
        }
    }
}

/// 펜 색. 라이트·다크와 상관없이 같은 값이다 — 결과 그림이 화면 모양을 따라 바뀌면 안 된다.
enum PenColor: String, CaseIterable, Identifiable {
    case red
    case yellow
    case blue
    case black
    case white

    var id: String { rawValue }

    var nsColor: NSColor {
        switch self {
        case .red: return Design.AppKitColor.penRed
        case .yellow: return Design.AppKitColor.penYellow
        case .blue: return Design.AppKitColor.penBlue
        case .black: return Design.AppKitColor.penBlack
        case .white: return Design.AppKitColor.penWhite
        }
    }

    var titleKey: L10n.Key {
        switch self {
        case .red: return .capturePenRed
        case .yellow: return .capturePenYellow
        case .blue: return .capturePenBlue
        case .black: return .capturePenBlack
        case .white: return .capturePenWhite
        }
    }
}

/// 굵기. 화면 포인트 단위다. 레티나 캡처에는 그림 픽셀로 2배가 된다.
enum PenWidth: String, CaseIterable, Identifiable {
    case thin
    case regular
    case thick

    var id: String { rawValue }

    var points: CGFloat {
        switch self {
        case .thin: return Design.Capture.strokeThin
        case .regular: return Design.Capture.strokeRegular
        case .thick: return Design.Capture.strokeThick
        }
    }

    /// 글자 크기. 새 수치를 짓지 않고 시스템 글자 단계를 쓴다.
    var textStyle: NSFont.TextStyle {
        switch self {
        case .thin: return .title3
        case .regular: return .title1
        case .thick: return .largeTitle
        }
    }

    var font: NSFont {
        NSFont.boldSystemFont(ofSize: NSFont.preferredFont(forTextStyle: textStyle).pointSize)
    }

    var titleKey: L10n.Key {
        switch self {
        case .thin: return .captureWidthThin
        case .regular: return .captureWidthRegular
        case .thick: return .captureWidthThick
        }
    }
}

/// 그림 위에 얹은 것 하나. 좌표는 **그림의 포인트 좌표**(왼쪽 위가 원점)다 — 창을 줄여 보여도 그린 자리가 그림에 붙어 있다.
struct Mark: Equatable {
    enum Shape: Equatable {
        case stroke([CGPoint])
        case rectangle(from: CGPoint, to: CGPoint)
        case arrow(from: CGPoint, to: CGPoint)
        /// `at` 은 글자 상자의 왼쪽 위.
        case text(String, at: CGPoint)
    }

    var shape: Shape
    var color: PenColor
    var width: PenWidth
}

/// 클립보드에서 읽은 그림.
struct CaptureImage {
    let cgImage: CGImage
    /// 포인트 크기. 레티나 캡처는 픽셀의 절반이다(그림에 적힌 해상도 정보에서 온다).
    let pointSize: CGSize

    var pixelSize: CGSize { CGSize(width: cgImage.width, height: cgImage.height) }
    /// 포인트 하나에 픽셀 몇 개. 레티나 캡처면 2.
    var scale: CGFloat { pointSize.width > 0 ? pixelSize.width / pointSize.width : 1 }

    /// 클립보드의 그림. 없으면 `nil`.
    ///
    /// ⌃⌘⇧3 은 PNG·TIFF 로 넣는다. 둘 다 없으면 NSImage 가 읽을 수 있는 다른 꼴(PDF 등)을 픽셀로 바꿔 쓴다.
    static func read(from pasteboard: NSPasteboard) -> CaptureImage? {
        for type in [NSPasteboard.PasteboardType.png, .tiff] {
            if let data = pasteboard.data(forType: type),
               let rep = NSBitmapImageRep(data: data),
               let image = rep.cgImage {
                return CaptureImage(cgImage: image, pointSize: rep.size)
            }
        }
        guard let image = NSImage(pasteboard: pasteboard), image.size.width > 0, image.size.height > 0 else { return nil }
        var rect = CGRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return nil }
        return CaptureImage(cgImage: cgImage, pointSize: image.size)
    }
}

/// 편집 중인 캡처 하나.
final class CaptureDocument: ObservableObject {
    let image: CaptureImage
    @Published private(set) var marks: [Mark] = []

    init(image: CaptureImage) {
        self.image = image
    }

    var canUndo: Bool { !marks.isEmpty }

    func add(_ mark: Mark) {
        // 빈 글자·점 하나도 안 되는 선은 넣지 않는다. 되돌리기 한 번이 아무것도 안 지우는 것처럼 보인다.
        switch mark.shape {
        case .text(let string, _) where string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty: return
        case .stroke(let points) where points.isEmpty: return
        default: marks.append(mark)
        }
    }

    func undo() {
        guard !marks.isEmpty else { return }
        marks.removeLast()
    }

    /// 원본 픽셀 크기의 PNG. 해상도 정보를 남겨 붙여넣을 때 원래 크기로 보인다.
    ///
    /// 그림의 색 공간 그대로 그린다. sRGB 로 다시 그리면 P3 화면에서 찍은 원본 픽셀이 바뀐다.
    func pngData() -> Data? {
        let width = image.cgImage.width
        let height = image.cgImage.height
        let space = image.cgImage.colorSpace.flatMap { $0.model == .rgb ? $0 : nil }
            ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }

        context.draw(image.cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        // 위에서 아래로, 포인트 단위로 그리게 바꾼다. 화면에 그릴 때와 같은 좌표다.
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: image.scale, y: -image.scale)
        MarkRenderer.draw(marks, in: context)

        guard let result = context.makeImage() else { return nil }
        let rep = NSBitmapImageRep(cgImage: result)
        rep.size = image.pointSize
        return rep.representation(using: .png, properties: [:])
    }

    /// 결과를 클립보드에 넣는다. 다른 꼴은 지운다 — 원본 TIFF 가 남으면 붙여넣는 앱이 그것을 고를 수 있다.
    @discardableResult
    func write(to pasteboard: NSPasteboard) -> Bool {
        guard let data = pngData() else { return false }
        pasteboard.clearContents()
        return pasteboard.setData(data, forType: .png)
    }

    /// 창이 처음 열릴 크기. 그림 비율을 지키며 `bounds` 의 `fraction` 안에 들어가게 줄인다. 키우지는 않는다.
    static func fittedSize(_ size: CGSize, in bounds: CGSize, fraction: CGFloat) -> CGSize {
        guard size.width > 0, size.height > 0 else { return size }
        let limit = min(bounds.width * fraction / size.width, bounds.height * fraction / size.height, 1)
        // 내림 — 반올림하면 한도를 0.5pt 넘을 수 있다.
        return CGSize(width: (size.width * limit).rounded(.down), height: (size.height * limit).rounded(.down))
    }
}

/// 그린 것을 CoreGraphics 로 그린다. 화면과 내보내기가 같은 코드를 쓴다 — 보이는 것과 붙여넣은 것이 다르면 안 된다.
///
/// `context` 는 그림의 포인트 좌표이고 왼쪽 위가 원점(아래로 갈수록 y 가 큼)이어야 한다.
enum MarkRenderer {
    static func draw(_ marks: [Mark], in context: CGContext) {
        for mark in marks { draw(mark, in: context) }
    }

    static func draw(_ mark: Mark, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        let color = mark.color.nsColor.cgColor
        context.setStrokeColor(color)
        context.setFillColor(color)
        context.setLineWidth(mark.width.points)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        switch mark.shape {
        case .stroke(let points):
            guard let first = points.first else { return }
            context.move(to: first)
            // 점 하나여도 둥근 끝으로 점이 찍힌다.
            for point in points.dropFirst() { context.addLine(to: point) }
            if points.count == 1 { context.addLine(to: first) }
            context.strokePath()

        case .rectangle(let from, let to):
            context.stroke(rect(from, to))

        case .arrow(let from, let to):
            context.move(to: from)
            context.addLine(to: to)
            context.strokePath()
            let (left, right) = arrowHead(from: from, to: to, width: mark.width.points)
            context.move(to: left)
            context.addLine(to: to)
            context.addLine(to: right)
            context.strokePath()

        case .text(let string, let origin):
            let graphics = NSGraphicsContext(cgContext: context, flipped: true)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = graphics
            NSAttributedString(string: string, attributes: textAttributes(mark)).draw(at: origin)
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    static func textAttributes(_ mark: Mark) -> [NSAttributedString.Key: Any] {
        [.font: mark.width.font, .foregroundColor: mark.color.nsColor]
    }

    static func rect(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    /// 화살표 머리의 두 끝. 머리 길이는 굵기에 비례하고 하한이 있다(`Design.Capture`).
    static func arrowHead(from: CGPoint, to: CGPoint, width: CGFloat) -> (CGPoint, CGPoint) {
        let length = max(width * Design.Capture.arrowHeadRatio, Design.Capture.arrowHeadMin)
        let angle = atan2(to.y - from.y, to.x - from.x)
        let spread = Design.Capture.arrowHeadAngle * .pi / 180
        func end(_ offset: CGFloat) -> CGPoint {
            CGPoint(x: to.x - length * cos(angle + offset), y: to.y - length * sin(angle + offset))
        }
        return (end(spread), end(-spread))
    }
}
