import AppKit
import SwiftUI

/// 편집 중인 도구·색·굵기와 그리는 중인 것.
final class CaptureEditorState: ObservableObject {
    @Published var tool: CaptureTool = .pen
    @Published var color: PenColor = .red
    @Published var width: PenWidth = .regular
    /// 끌고 있는 동안의 모양. 손을 떼면 문서로 들어간다.
    @Published var draft: Mark?
    /// 글자를 입력하는 중이면 그 자리(그림 포인트 좌표)와 글.
    @Published var textEntry: TextEntry?

    struct TextEntry: Equatable {
        var origin: CGPoint
        var text: String
    }
}

/// 캡처 편집 창 하나. 닫히면 `onFinish` 로 결과를 알린다.
///
/// 키는 창 단위로 받는다(`NSEvent` 로컬 모니터 — 이 앱 안의 키만 보므로 권한이 필요 없다).
/// SwiftUI 의 키 처리는 초점이 있는 뷰에만 가서, 그림을 누른 뒤에는 Enter 가 오지 않을 수 있다.
final class CaptureEditorWindow: NSObject, NSWindowDelegate {
    enum Outcome {
        case copied
        case copyFailed
        case cancelled
    }

    let document: CaptureDocument
    let state = CaptureEditorState()
    private let window: NSWindow
    private let onFinish: (Outcome) -> Void
    private var monitor: Any?
    private var outcome: Outcome = .cancelled

    init(document: CaptureDocument, l10n: L10n, onFinish: @escaping (Outcome) -> Void) {
        self.document = document
        self.onFinish = onFinish
        window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        super.init()

        let screen = NSScreen.main?.visibleFrame.size ?? document.image.pointSize
        let fitted = CaptureDocument.fittedSize(document.image.pointSize, in: screen,
                                                fraction: Design.Capture.windowFraction)
        func view(_ imageSize: CGSize) -> CaptureEditorView {
            CaptureEditorView(document: document, state: state, l10n: l10n, initialImageSize: imageSize,
                              copy: { [weak self] in self?.copyAndClose() })
        }
        let hosting = NSHostingView(rootView: view(fitted))
        window.contentView = hosting
        window.setContentSize(hosting.fittingSize)
        // 그림 자리가 0 인 크기 = 도구 막대와 안내 줄만. 이보다 줄이면 도구가 잘린다.
        window.contentMinSize = NSHostingView(rootView: view(.zero)).fittingSize
        window.title = l10n(.tabCaptureEdit)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.window else { return event }
            return self.handle(event) ? nil : event
        }
    }

    func bringToFront() {
        NSApp.activate(ignoringOtherApps: true)
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
    }

    /// 처리했으면 `true`. 글자를 입력하는 중에는 Esc 만 가로챈다 — Enter 는 입력 칸이 글자를 넣고,
    /// ⌘C·⌘Z 는 입력 칸 안에서의 복사·되돌리기다.
    private func handle(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let command = flags.contains(.command)
        let key = event.charactersIgnoringModifiers?.lowercased()
        let escape: UInt16 = 53, returnKey: UInt16 = 36, keypadEnter: UInt16 = 76

        if state.textEntry != nil {
            guard event.keyCode == escape else { return false }
            state.textEntry = nil
            return true
        }
        switch (event.keyCode, command, key) {
        case (escape, _, _):
            window.close()
        case (returnKey, false, _), (keypadEnter, false, _), (_, true, "c"):
            copyAndClose()
        case (_, true, "z"):
            document.undo()
        default:
            return false
        }
        return true
    }

    private func copyAndClose() {
        commitText()
        outcome = document.write(to: .general) ? .copied : .copyFailed
        window.close()
    }

    /// 입력 중이던 글자가 있으면 넣는다. 복사 버튼을 눌렀는데 방금 쓴 글자가 빠지면 안 된다.
    private func commitText() {
        guard let entry = state.textEntry else { return }
        document.add(Mark(shape: .text(entry.text, at: entry.origin), color: state.color, width: state.width))
        state.textEntry = nil
    }

    func windowWillClose(_ notification: Notification) {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        onFinish(outcome)
    }
}

/// 편집 창의 내용 — 도구 막대, 그림, 키 안내.
struct CaptureEditorView: View {
    @ObservedObject var document: CaptureDocument
    @ObservedObject var state: CaptureEditorState
    @ObservedObject var l10n: L10n
    /// 처음 열릴 때 그림이 차지할 크기(포인트). 창 크기를 정하는 데만 쓴다.
    let initialImageSize: CGSize
    let copy: () -> Void

    @FocusState private var textFocused: Bool

    var body: some View {
        VStack(spacing: Design.Space.none) {
            toolbar
                .padding(.horizontal, Design.Inset.card)
                .padding(.vertical, Design.Space.listRow)
            Divider()
            canvas
                .frame(idealWidth: initialImageSize.width, idealHeight: initialImageSize.height)
            Divider()
            Text(l10n(.captureKeys))
                .font(.caption)
                .foregroundStyle(Design.Color.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Design.Space.listRow)
        }
    }

    // MARK: - 도구 막대

    private var toolbar: some View {
        HStack(spacing: Design.Space.inline) {
            Picker("", selection: $state.tool) {
                ForEach(CaptureTool.allCases) { tool in
                    Image(systemName: tool.symbol)
                        .help(l10n(tool.titleKey))
                        .accessibilityLabel(l10n(tool.titleKey))
                        .tag(tool)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            HStack(spacing: Design.Space.chipGap) {
                ForEach(PenColor.allCases) { color in
                    Button { state.color = color } label: {
                        Circle()
                            .fill(Color(nsColor: color.nsColor))
                            .overlay(Circle().stroke(Design.Color.textSecondary, lineWidth: 1))
                            .frame(width: Design.Size.indicator * 1.6, height: Design.Size.indicator * 1.6)
                            .padding(Design.Space.rowTight)
                            .background(Circle().stroke(state.color == color ? Design.Color.accent : .clear,
                                                        lineWidth: 2))
                            .frame(minWidth: Design.Size.hitMin, minHeight: Design.Size.hitMin)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(l10n(color.titleKey))
                    .accessibilityLabel(l10n(color.titleKey))
                    .accessibilityAddTraits(state.color == color ? .isSelected : [])
                }
            }

            Picker("", selection: $state.width) {
                ForEach(PenWidth.allCases) { width in
                    Text(l10n(width.titleKey)).tag(width)
                }
            }
            .labelsHidden()
            .fixedSize()

            Spacer(minLength: Design.Space.inline)

            Button { document.undo() } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!document.canUndo)
            .help(l10n(.captureUndo))
            .accessibilityLabel(l10n(.captureUndo))

            Button(l10n(.captureCopy), action: copy)
                .buttonStyle(PrimaryButtonStyle())
                // 두 줄로 감기면 도구 막대 높이가 언어마다 달라진다(영어에서 확인). 한 줄로 두고 창이 넓어진다.
                .fixedSize()
        }
    }

    // MARK: - 그림

    private var canvas: some View {
        GeometryReader { geometry in
            let image = document.image
            let fit = min(geometry.size.width / image.pointSize.width,
                          geometry.size.height / image.pointSize.height)
            let shown = CGSize(width: image.pointSize.width * fit, height: image.pointSize.height * fit)
            // 창을 끝까지 줄이면 0 이 된다. 0 으로 나누면 그린 자리가 무한대로 간다.
            let drawable = fit > 0

            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    context.draw(Image(decorative: image.cgImage, scale: 1),
                                 in: CGRect(origin: .zero, size: size))
                    context.withCGContext { cg in
                        cg.scaleBy(x: fit, y: fit)
                        MarkRenderer.draw(document.marks + [state.draft].compactMap { $0 }, in: cg)
                    }
                }
                .gesture(drawing(fit: fit), including: drawable ? .all : .none)

                if let entry = state.textEntry {
                    textField(entry, fit: fit)
                }
            }
            .frame(width: shown.width, height: shown.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func textField(_ entry: CaptureEditorState.TextEntry, fit: CGFloat) -> some View {
        let font = state.width.font
        return TextField(l10n(.captureTextPrompt), text: Binding(
            get: { state.textEntry?.text ?? "" },
            set: { state.textEntry?.text = $0 }))
            .textFieldStyle(.plain)
            .font(Font(font))
            .scaleEffect(fit, anchor: .topLeading)
            .foregroundStyle(Color(nsColor: state.color.nsColor))
            .fixedSize()
            .focused($textFocused)
            .onSubmit(commitText)
            .offset(x: entry.origin.x * fit, y: entry.origin.y * fit)
            .onAppear { textFocused = true }
    }

    /// 화면 좌표를 그림 포인트 좌표로 바꿔 그린다.
    private func drawing(fit: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let start = CGPoint(x: value.startLocation.x / fit, y: value.startLocation.y / fit)
                let point = CGPoint(x: value.location.x / fit, y: value.location.y / fit)
                switch state.tool {
                case .pen:
                    if case .stroke(let points) = state.draft?.shape {
                        state.draft?.shape = .stroke(points + [point])
                    } else {
                        state.draft = mark(.stroke([start, point]))
                    }
                case .rectangle:
                    state.draft = mark(.rectangle(from: start, to: point))
                case .arrow:
                    state.draft = mark(.arrow(from: start, to: point))
                case .text:
                    break
                }
            }
            .onEnded { value in
                if state.tool == .text {
                    commitText()
                    state.textEntry = .init(origin: CGPoint(x: value.location.x / fit, y: value.location.y / fit),
                                            text: "")
                    return
                }
                if let draft = state.draft { document.add(draft) }
                state.draft = nil
            }
    }

    private func mark(_ shape: Mark.Shape) -> Mark {
        Mark(shape: shape, color: state.color, width: state.width)
    }

    private func commitText() {
        guard let entry = state.textEntry else { return }
        document.add(mark(.text(entry.text, at: entry.origin)))
        state.textEntry = nil
    }
}
