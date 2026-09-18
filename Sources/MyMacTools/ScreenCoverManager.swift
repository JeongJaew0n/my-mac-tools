import AppKit
import SwiftUI
import Combine
import IOKit.pwr_mgt

/// 커버 창. borderless 는 기본적으로 key 가 될 수 없어 키 입력을 못 받는다.
/// Enter·Esc 해제가 그 입력에 걸려 있으므로 열어준다.
final class CoverWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// 모든 디스플레이를 사진 한 장으로 덮는다.
///
/// **잠금이 아니다.** 잠깐 자리를 비울 때 모니터 앞에 틀어두는 가림막이다.
/// 인증이 없고 `Cmd-Q`·강제 종료로 뚫린다. 보안이 목적이면 macOS 화면 잠금을 쓴다.
///
/// 덮여 있는 동안 디스플레이가 꺼지지 않게 막는다. 막지 않으면 결국 검은 화면이 되고
/// 그 뒤 화면 잠금까지 걸려 사진을 틀어두는 의미가 사라진다. 다만 그 수단으로
/// `caffeinate` 도 `pmset -a disablesleep` 도 쓰지 않는다 — `IOPMAssertion` 은 sudo 가
/// 필요 없고, **프로세스가 죽으면 커널이 회수**해서 고아 상태가 남지 않는다.
final class ScreenCoverManager: ObservableObject {

    /// 화면 비율이 제각각이라 한쪽만으로는 부족하다.
    enum FillMode: String, CaseIterable, Identifiable {
        /// 화면을 꽉 채운다. 비율이 다르면 잘린다.
        case fill
        /// 사진 전체를 보여준다. 비율이 다르면 여백이 생긴다.
        case fit

        var id: String { rawValue }

        var titleKey: L10n.Key {
            switch self {
            case .fill: return .coverFillModeFill
            case .fit:  return .coverFillModeFit
            }
        }
    }

    /// 두 번 누른 것으로 볼 최대 간격.
    /// 상한이 없으면 몇 시간 전에 눌린 한 번이 살아 있게 된다.
    static let doublePressInterval: TimeInterval = 1.5

    /// 두 번 눌러 해제하는 키. 키패드 `Enter` 는 본 `Enter` 와 같은 것으로 센다.
    private enum DismissKey {
        case enter
        case escape
    }

    private static let imagePathKey = "coverImagePath"
    private static let shortcutKey = "coverShortcut"
    private static let fillModeKey = "coverFillMode"

    @Published private(set) var isCovering = false
    @Published private(set) var imagePath: String?
    @Published private(set) var lastError: String?
    /// 화면을 덮는 전역 단축키. 지정하지 않으면 `nil`.
    @Published private(set) var shortcut: Shortcut?

    @Published var fillMode: FillMode {
        didSet {
            guard fillMode != oldValue else { return }
            UserDefaults.standard.set(fillMode.rawValue, forKey: Self.fillModeKey)
            if isCovering { rebuildWindows() }
        }
    }

    private var windows: [CoverWindow] = []
    private var assertionID: IOPMAssertionID = 0
    private var hasAssertion = false
    private var screenObserver: NSObjectProtocol?
    private var keyMonitor: Any?
    private var lastPressAt: [DismissKey: Date] = [:]
    private var l10n: L10n?

    init() {
        let defaults = UserDefaults.standard
        imagePath = defaults.string(forKey: Self.imagePathKey)
        fillMode = defaults.string(forKey: Self.fillModeKey)
            .flatMap(FillMode.init(rawValue:)) ?? .fill
        shortcut = defaults.data(forKey: Self.shortcutKey)
            .flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) }
        applyShortcut()
    }

    // MARK: - 단축키

    /// `nil` 을 주면 지운다.
    func setShortcut(_ value: Shortcut?) {
        shortcut = value
        let defaults = UserDefaults.standard
        if let value, let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: Self.shortcutKey)
        } else {
            defaults.removeObject(forKey: Self.shortcutKey)
        }
        applyShortcut()
    }

    /// 단축키는 **덮기만** 한다. 해제는 화면에 떠 있는 세 가지로 한다.
    /// 덮고 나서 같은 키를 눌러 풀리게 하면, 커버가 키를 삼키는 동작과 얽혀
    /// 조합에 따라 되기도 안 되기도 하는 동작이 된다.
    private func applyShortcut() {
        guard let shortcut else {
            HotKeyCenter.shared.unregister()
            return
        }
        HotKeyCenter.shared.register(shortcut) { [weak self] in
            guard let self, !self.isCovering else { return }
            self.start()
            // 사진이 없거나 못 읽으면 덮이지 않는다. 그때는 창을 앞으로 내보내
            // 사용자가 이유를 볼 수 있게 한다. 아무 일도 안 일어나면 고장으로 보인다.
            if !self.isCovering {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    /// 커버 화면의 문구를 위해 현재 언어를 넘겨받는다.
    func use(_ l10n: L10n) {
        self.l10n = l10n
    }

    // MARK: - 사진

    /// 고른 사진의 경로를 기억한다. 읽을 수 있는지 이 시점에 확인해 둔다.
    func setImage(path: String) {
        guard NSImage(contentsOfFile: path) != nil else {
            lastError = path
            return
        }
        lastError = nil
        imagePath = path
        UserDefaults.standard.set(path, forKey: Self.imagePathKey)
        if isCovering { rebuildWindows() }
    }

    private func loadImage() -> NSImage? {
        guard let imagePath else { return nil }
        return NSImage(contentsOfFile: imagePath)
    }

    // MARK: - 시작 · 해제

    func toggle() {
        isCovering ? stop() : start()
    }

    /// 사진을 못 읽으면 덮지 않는다. 사진 없이 단색으로 덮어버리면 사용자는 무슨 일이
    /// 일어났는지 알 수 없다.
    func start() {
        guard !isCovering else { return }
        guard let image = loadImage() else {
            lastError = imagePath ?? ""
            return
        }
        lastError = nil

        acquireAssertion()
        buildWindows(with: image)
        observeScreenChanges()
        startKeyMonitor()

        isCovering = true
        // 키 입력을 받으려면 앱이 활성 상태여야 한다.
        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKeyAndOrderFront(nil)
    }

    func stop() {
        guard isCovering else { return }
        stopKeyMonitor()
        stopObservingScreenChanges()
        tearDownWindows()
        releaseAssertion()
        lastPressAt.removeAll()
        isCovering = false
    }

    // MARK: - 창

    private func buildWindows(with image: NSImage) {
        for screen in NSScreen.screens {
            let window = CoverWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen)
            // 화면 보호기(1000)·메뉴 막대(24) 위라 Dock 과 메뉴 막대를 덮는다.
            window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            window.backgroundColor = .black
            window.isOpaque = true
            window.hasShadow = false
            window.ignoresMouseEvents = false

            let view = CoverView(
                image: image,
                fillMode: fillMode,
                dismissTitle: text(.coverDismiss),
                hint: text(.coverHint),
                onDismiss: { [weak self] in self?.stop() })
            window.contentView = NSHostingView(rootView: view)
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
            windows.append(window)
        }
    }

    private func tearDownWindows() {
        for window in windows {
            window.orderOut(nil)
            window.contentView = nil
        }
        windows.removeAll()
    }

    /// 커버 중에 모니터를 뽑거나 꽂으면 창을 다시 깐다.
    private func rebuildWindows() {
        guard isCovering, let image = loadImage() else { return }
        tearDownWindows()
        buildWindows(with: image)
        windows.first?.makeKeyAndOrderFront(nil)
    }

    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main) { [weak self] _ in
                self?.rebuildWindows()
            }
    }

    private func stopObservingScreenChanges() {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        screenObserver = nil
    }

    // MARK: - 키로 해제

    /// `Enter` 두 번과 `Esc` 두 번. 셋(버튼 포함) 다 같은 `stop()` 으로 모인다.
    private func startKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self, self.isCovering else { return event }
            return self.handle(event) ? nil : event
        }
    }

    private func stopKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
    }

    /// 처리했으면 `true`. 커버 중 키가 뒤의 앱으로 새지 않게 삼킨다.
    private func handle(_ event: NSEvent) -> Bool {
        let enter: UInt16 = 36
        let keypadEnter: UInt16 = 76
        let escape: UInt16 = 53

        // `Cmd` 조합은 그냥 흘려보낸다. 여기서 삼키면 `Cmd-Q` 까지 막히는데,
        // 해제 경로가 고장났을 때 앱을 끄는 것이 마지막 탈출구다. 커버는 앱과 수명을
        // 같이하므로 앱이 꺼지면 커버도 사라진다.
        if event.modifierFlags.contains(.command) { return false }

        switch (event.type, event.keyCode) {
        case (.keyDown, enter), (.keyDown, keypadEnter):
            // 누르고 있으면 keyDown 이 반복해서 온다. 반복은 두 번째로 치지 않는다.
            guard !event.isARepeat else { return true }
            registerPress(.enter)
            return true

        case (.keyDown, escape):
            guard !event.isARepeat else { return true }
            registerPress(.escape)
            return true

        default:
            // 그 밖의 키는 삼키기만 한다. 덮여 있는데 뒤의 앱이 입력을 받으면 곤란하다.
            return event.type == .keyDown
        }
    }

    /// 같은 키를 간격 안에 두 번 누르면 해제한다. 키마다 따로 센다.
    private func registerPress(_ key: DismissKey) {
        let now = Date()
        if let last = lastPressAt[key], now.timeIntervalSince(last) <= Self.doublePressInterval {
            stop()
        } else {
            lastPressAt[key] = now
        }
    }


    // MARK: - 디스플레이 슬립 차단

    private func acquireAssertion() {
        guard !hasAssertion else { return }
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "MyMacTools screen cover" as CFString,
            &id)
        guard result == kIOReturnSuccess else { return }
        assertionID = id
        hasAssertion = true
    }

    private func releaseAssertion() {
        guard hasAssertion else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        hasAssertion = false
    }

    private func text(_ key: L10n.Key) -> String {
        l10n?(key) ?? key.rawValue
    }
}
