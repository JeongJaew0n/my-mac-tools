import AppKit
import Combine

/// 상태 막대 아이콘과 메뉴.
///
/// SwiftUI 의 `MenuBarExtra` 를 쓰지 않는다. 그쪽은 `NSStatusItem` 의 버튼을 내주지 않아
/// **글리프는 template 으로 두면서 초록 점만 색을 살리는** 구성을 만들 수 없다.
/// 실제로 재봤을 때 이랬다.
///
/// - SwiftUI `ZStack` 에 얹은 `Circle().fill(.green)` → 메뉴바가 template 으로 렌더링해 색이 죽는다
/// - `isTemplate = false` 로 합성한 `NSImage` → 초록은 살지만 **글리프 색이 굳는다.**
///   메뉴바는 배경에 따라 밝기를 바꾸므로 다른 아이콘은 흰데 혼자 검게 남는다
/// - `NSStatusItem` 직접 + template 글리프 + 점은 별도 뷰 → 둘 다 성립한다
final class StatusItemController: NSObject, NSMenuDelegate {

    /// 돌고 있음을 알리는 초록 점. 버튼 위에 얹어 색을 유지한다.
    private final class RunningDot: NSView {
        override func draw(_ dirtyRect: NSRect) {
            NSColor.systemGreen.setFill()
            NSBezierPath(ovalIn: bounds).fill()
        }
    }

    private static let dotSize: CGFloat = 6
    private static let glyphName = "wrench.and.screwdriver"

    private let manager: BlackWorkManager
    private let lid: LidWorkManager
    private let cover: ScreenCoverManager
    private let l10n: L10n
    private let openWindow: () -> Void

    private var statusItem: NSStatusItem?
    private var dot: RunningDot?
    private var cancellables: Set<AnyCancellable> = []

    init(manager: BlackWorkManager,
         lid: LidWorkManager,
         cover: ScreenCoverManager,
         l10n: L10n,
         openWindow: @escaping () -> Void) {
        self.manager = manager
        self.lid = lid
        self.cover = cover
        self.l10n = l10n
        self.openWindow = openWindow
        super.init()
        install()
        observe()
    }

    private var anyRunning: Bool {
        manager.isRunning || lid.isRunning || cover.isCovering
    }

    // MARK: - 설치

    private func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        guard let button = item.button else { return }

        let configuration = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        guard let glyph = NSImage(systemSymbolName: Self.glyphName, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) else { return }
        // template 이어야 메뉴바가 배경에 맞춰 밝기를 잡아준다.
        glyph.isTemplate = true
        button.image = glyph
        button.imagePosition = .imageOnly

        // 버튼(32.5pt)이 메뉴바(22pt)보다 높다. 버튼 바닥에 붙이면 잘리므로
        // **글리프 사각형** 기준으로 우측 하단에 놓는다.
        let size = Self.dotSize
        let bounds = button.bounds
        let glyphSize = glyph.size
        let originX = (bounds.width - glyphSize.width) / 2 + glyphSize.width - size
        let originY = (bounds.height - glyphSize.height) / 2 + glyphSize.height - size
        let dot = RunningDot(frame: NSRect(x: originX, y: originY, width: size, height: size))
        dot.autoresizingMask = button.isFlipped ? [.minXMargin, .minYMargin] : [.minXMargin, .maxYMargin]
        dot.isHidden = true
        button.addSubview(dot)
        self.dot = dot

        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu

        refreshDot()
    }

    /// 세 기능과 언어 중 무엇이 바뀌든 점을 다시 본다.
    /// `objectWillChange` 는 **바뀌기 직전**에 오므로 한 틱 미뤄 읽는다.
    private func observe() {
        let publishers: [AnyPublisher<Void, Never>] = [
            manager.objectWillChange.eraseToAnyPublisher(),
            lid.objectWillChange.eraseToAnyPublisher(),
            cover.objectWillChange.eraseToAnyPublisher(),
            l10n.objectWillChange.eraseToAnyPublisher(),
        ]
        for publisher in publishers {
            publisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] in self?.refreshDot() }
                .store(in: &cancellables)
        }
    }

    private func refreshDot() {
        dot?.isHidden = !anyRunning
    }

    // MARK: - 메뉴

    /// 열릴 때마다 새로 짠다. 항목을 들고 있다가 따로 갱신하면 동기화가 어긋난다.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        add(menu, title: l10n(.tabScreenOff), on: manager.isRunning,
            action: #selector(toggleScreenOff))
        add(menu, title: l10n(.tabLid), on: lid.isRunning,
            action: #selector(toggleLid))
        // 사진이 없으면 덮을 것이 없다. 고르는 것은 창에서 한다.
        add(menu, title: l10n(.tabCover), on: cover.isCovering,
            action: #selector(toggleCover),
            enabled: cover.imagePath != nil || cover.isCovering)

        menu.addItem(.separator())
        add(menu, title: l10n(.menuOpenWindow), on: false, action: #selector(showWindow))
        add(menu, title: l10n(.menuQuit), on: false, action: #selector(quit))
    }

    private func add(_ menu: NSMenu,
                     title: String,
                     on: Bool,
                     action: Selector,
                     enabled: Bool = true) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = on ? .on : .off
        item.isEnabled = enabled
        menu.addItem(item)
    }

    // MARK: - 동작

    @objc private func toggleScreenOff() {
        manager.toggle()
        refreshDot()
    }

    @objc private func toggleLid() {
        Actions.toggleLid(lid, manager)
        refreshDot()
    }

    @objc private func toggleCover() {
        cover.toggle()
        refreshDot()
    }

    @objc private func showWindow() {
        openWindow()
        // 창만 띄우면 다른 앱 뒤에 열릴 수 있다.
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        // terminate 로 보내야 덮개가 켜진 채 종료되는 것을 막는 경고를 거친다.
        NSApp.terminate(nil)
    }
}
