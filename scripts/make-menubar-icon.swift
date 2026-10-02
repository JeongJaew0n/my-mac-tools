#!/usr/bin/env swift
import AppKit

// 메뉴바용 template 이미지를 굽는다.
//
// 메뉴바 아이콘은 template 이어야 배경 밝기에 맞춰 색이 잡힌다. template 은 **알파만**
// 보므로 흰 배경을 투명으로 바꾸고 그림만 불투명하게 남긴다.
//
// 임계값은 **최종 표시 픽셀 크기에서** 적용한다. 큰 마스크를 만들어 줄이면 가장자리가
// 전부 반투명 회색이 되고, 메뉴바의 반투명 틴트와 곱해져 글리프가 흐릿하게 뜬다.
//
// 원본은 `Resources/MenuBarIconSource.png` — 앱 아이콘의 글리프만 흰 바탕 검은 그림으로
// 따낸 것이다. 앱 아이콘은 어두운 바탕 위 밝은 그림이라 이 스크립트에 그대로 넣을 수
// 없다. 글리프 둘레를 꽉 맞춰 잘라 두었으므로 inset 은 0 이다. 아이콘을 교체할 때는
// 반드시 이 스크립트를 돌려 결과를 눈으로 본다 — 가는 틈은 20pt 에서 메워질 수 있다.
//
//   swift scripts/make-menubar-icon.swift Resources/MenuBarIconSource.png Resources/MenuBarIcon.png

let base = 20         // 메뉴바 표시 높이(pt). 메뉴바는 22pt 라 여백이 위아래 1pt 씩 남는다.
let threshold = 0.60  // 이보다 어두우면 그림으로 본다
let inset = 0.0       // 원본 여백만큼 키워 그린다 (비율)
let supersample = 8

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write("usage: make-menubar-icon.swift <source.png> <out.png>\n".data(using: .utf8)!)
    exit(2)
}
guard let source = NSImage(contentsOfFile: args[1]) else {
    FileHandle.standardError.write("원본을 읽지 못했습니다: \(args[1])\n".data(using: .utf8)!)
    exit(1)
}

func mask(side: Int) -> Data? {
    let work = side * supersample
    guard let big = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: work, pixelsHigh: work,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: work * 4, bitsPerPixel: 32) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: big)
    NSGraphicsContext.current?.imageInterpolation = .high
    // 원본에 알파가 있을 수 있으므로 흰 바탕 위에 합성한다.
    NSColor.white.setFill()
    NSRect(x: 0, y: 0, width: work, height: work).fill()
    let margin = inset * CGFloat(work)
    source.draw(in: NSRect(x: -margin, y: -margin,
                           width: CGFloat(work) + margin * 2, height: CGFloat(work) + margin * 2))
    NSGraphicsContext.restoreGraphicsState()
    guard let bigData = big.bitmapData else { return nil }

    var solid = [Bool](repeating: false, count: work * work)
    for p in 0..<(work * work) {
        let i = p * 4
        let luminance = (0.299 * Double(bigData[i]) + 0.587 * Double(bigData[i + 1])
                         + 0.114 * Double(bigData[i + 2])) / 255
        solid[p] = luminance < threshold
    }

    guard let out = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: side * 4, bitsPerPixel: 32) else { return nil }
    guard let outData = out.bitmapData else { return nil }
    let cell = supersample * supersample
    for y in 0..<side {
        for x in 0..<side {
            var hits = 0
            for sy in 0..<supersample {
                for sx in 0..<supersample
                where solid[(y * supersample + sy) * work + (x * supersample + sx)] { hits += 1 }
            }
            let i = (y * side + x) * 4
            outData[i] = 0; outData[i + 1] = 0; outData[i + 2] = 0
            // 반투명을 남기지 않는다.
            outData[i + 3] = Double(hits) / Double(cell) >= 0.5 ? 255 : 0
        }
    }
    return out.representation(using: .png, properties: [:])
}

let out = URL(fileURLWithPath: args[2])
let retinaName = out.deletingPathExtension().lastPathComponent + "@2x." + out.pathExtension
let retinaURL = out.deletingLastPathComponent().appendingPathComponent(retinaName)

guard let one = mask(side: base), let two = mask(side: base * 2) else { exit(1) }
try one.write(to: out)
try two.write(to: retinaURL)
print("\(out.lastPathComponent) \(base)x\(base) / \(retinaName) \(base*2)x\(base*2)  threshold=\(threshold) inset=\(inset)")
