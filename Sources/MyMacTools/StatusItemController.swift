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
            Design.AppKitColor.statusRunning.setFill()
            NSBezierPath(ovalIn: bounds).fill()
        }
    }

    /// 글리프 높이. 메뉴바가 22pt 라 그보다 작아야 위아래가 안 잘린다.
    /// `SymbolConfiguration` 의 `pointSize` 만으로는 실제 크기가 예측되지 않아
    /// (16pt 로 잡았더니 22pt 짜리가 나왔다) 결과 이미지 크기를 직접 못 박는다.
    private static let glyphHeight: CGFloat = 20
    private static let dotSize: CGFloat = 5
    /// 앱 로고에서 구운 template 이미지. `scripts/make-menubar-icon.swift` 산출물.
    private static let glyphResource = "MenuBarIcon"

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

        // `NSImage(named:)` 가 화면 배율에 맞춰 @2x 를 고른다.
        guard let glyph = NSImage(named: Self.glyphResource) else { return }
        // 가로세로 비를 지키며 높이를 맞춘다.
        let ratio = glyph.size.width / glyph.size.height
        glyph.size = NSSize(width: Self.glyphHeight * ratio, height: Self.glyphHeight)
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

        // 이름 옆에 시간을 붙인다. 꺼져 있으면 **켤 때 쓰일 시간**(저장된 기본값),
        // 켜져 있으면 **남은 시간**. 메뉴에는 시간을 고르는 자리가 없어서, 켜기 전에
        // 몇 시간짜리로 켜지는지 알 방법이 이것뿐이다.
        add(menu, title: titled(.tabScreenOff, running: manager.isRunning,
                                remaining: manager.remaining,
                                defaultSeconds: manager.defaultDurationSeconds),
            on: manager.isRunning, action: #selector(toggleScreenOff))
        add(menu, title: titled(.tabLid, running: lid.isRunning,
                                remaining: lid.remaining,
                                defaultSeconds: lid.defaultDurationSeconds),
            on: lid.isRunning, action: #selector(toggleLid))
        // 사진이 없으면 덮을 것이 없다. 고르는 것은 창에서 한다.
        add(menu, title: l10n(.tabCover), on: cover.isCovering,
            action: #selector(toggleCover),
            enabled: cover.imagePath != nil || cover.isCovering)

        menu.addItem(.separator())
        add(menu, title: l10n(.menuOpenWindow), on: false, action: #selector(showWindow))
        add(menu, title: l10n(.menuQuit), on: false, action: #selector(quit))
    }

    /// `잠자기 방지 — 2시간 30분` · `잠자기 방지 — 1:23:45 남음` · `… — 시간 제한 없음`.
    ///
    /// 메뉴는 열 때마다 다시 만들어지므로(`menuNeedsUpdate`) 남은 시간은 연 순간의 값이다.
    private func titled(_ name: L10n.Key, running: Bool,
                        remaining: TimeInterval?, defaultSeconds: Int?) -> String {
        let detail: String
        if running {
            detail = remaining.map { l10n(.progressRemaining, Self.clock($0)) } ?? l10n(.progressNoLimit)
        } else {
            detail = defaultSeconds.map(duration) ?? l10n(.progressNoLimit)
        }
        return "\(l10n(name)) — \(detail)"
    }

    /// `2시간 30분`, `2시간`, `30분`. 단위는 창의 선택기 옆 글자와 같은 문구를 쓴다.
    private func duration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = seconds % 3600 / 60
        var parts: [String] = []
        if hours > 0 { parts.append("\(hours)\(l10n(.unitHour))") }
        if minutes > 0 { parts.append("\(minutes)\(l10n(.unitMinute))") }
        return parts.joined(separator: " ")
    }

    /// 남은 시간을 창과 같은 `H:MM:SS` 로.
    private static func clock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
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
        Actions.toggleScreenOffFromMenu(manager, lid: lid)
        refreshDot()
    }

    @objc private func toggleLid() {
        Actions.toggleLidFromMenu(lid, manager)
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
