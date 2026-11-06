import AppKit
import Combine
import Foundation

/// IntelliJ 의 색을 고르고, 저장하고, IntelliJ 에 적용한다.
///
/// - **팔레트**: 지금 편집 중인 색. 바꿀 때마다 보존한다.
/// - **프리셋**: 이름을 붙여 저장한 팔레트.
/// - **적용**: 팔레트로 이 앱 전용 테마 플러그인을 만들어 IntelliJ 설정 폴더에 넣고, 그 테마를 고른다.
///
/// 사용자가 손으로 만든 테마 플러그인은 건드리지 않는다. `laf.xml` 의 가리킴만 바꾸고, 되돌리기는
/// 그 가리킴을 원래대로 돌린다. 근거는 `docs/plans/intellij-theme/`.
@MainActor
final class IntelliJThemeManager: ObservableObject {

    typealias Role = IntelliJThemeTemplate.Role
    typealias Palette = IntelliJThemeTemplate.Palette

    struct Preset: Codable, Equatable, Identifiable {
        var name: String
        /// 역할 rawValue → `RRGGBB`. 역할이 나중에 늘어도 읽히도록 문자열 키로 둔다.
        var colors: [String: String]
        var id: String { name }
    }

    /// 색을 넣을 IntelliJ.
    struct Target: Equatable {
        var appURL: URL
        var bundleID: String
        var displayName: String
        var version: String
        /// `~/Library/Application Support/JetBrains/<dataDirectoryName>`
        var configDir: URL
        var dataDirectoryName: String { configDir.lastPathComponent }
    }

    /// 적용하기 전에 IntelliJ 가 쓰던 것. 되돌리기가 이것을 다시 쓴다. `nil` 은 "설정에 없었다" 이다.
    struct Previous: Codable, Equatable {
        var themeID: String?
        var schemeName: String?
        /// `LafManager` 의 '시스템 설정과 동기화'. 켜져 있으면 고른 테마를 무시하므로 적용할 때 끈다.
        var autodetect: String?
    }

    enum Step: Equatable { case quitting, writing, relaunching }

    enum Failure: Error, Equatable {
        case notInstalled
        case noConfigDir(String)
        case didNotQuit
        case nothingToRestore
        case writeFailed(String)
    }

    enum Status: Equatable {
        case working(Step)
        case applied(relaunched: Bool)
        case restored(relaunched: Bool)
        case presetSaved(String)
        case presetLoaded(String)
        case failed(Failure)
    }

    @Published private(set) var palette: Palette
    @Published private(set) var presets: [Preset]
    @Published private(set) var target: Target?
    /// 지금 `laf.xml` 이 가리키는 테마. 파일·항목이 없으면 `nil`.
    @Published private(set) var currentThemeID: String?
    @Published private(set) var previous: Previous?
    @Published private(set) var status: Status?

    var isBusy: Bool {
        if case .working = status { return true }
        return false
    }

    var isApplied: Bool { currentThemeID == IntelliJThemeTemplate.themeID }

    private static let paletteKey = "intellijTheme.palette"
    private static let presetsKey = "intellijTheme.presets"
    private static func previousKey(_ target: Target) -> String {
        "intellijTheme.previous." + target.dataDirectoryName
    }

    /// 순서대로 찾는다. 둘 다 있으면 Ultimate 를 쓴다.
    private nonisolated static let bundleIDs = ["com.jetbrains.intellij", "com.jetbrains.intellij.ce"]
    /// 종료 확인 창을 사람이 누를 시간까지 친다.
    private static let quitTimeout: TimeInterval = 60

    init() {
        let saved = ToolDefaults.load(Self.paletteKey, fallback: [String: String]())
        palette = Self.palette(from: saved)
        presets = ToolDefaults.load(Self.presetsKey, fallback: [Preset]())
    }

    // MARK: - 팔레트

    func hex(_ role: Role) -> String {
        palette[role] ?? role.defaultHex
    }

    func setHex(_ hex: String, for role: Role) {
        guard let hex = IntelliJThemeTemplate.normalized(hex), palette[role] != hex else { return }
        palette[role] = hex
        persistPalette()
    }

    // MARK: - 프리셋

    func hasPreset(named name: String) -> Bool {
        presets.contains { $0.name == Self.trimmed(name) }
    }

    /// 같은 이름이 있으면 덮어쓴다. 화면이 누르기 전에 '덮어쓰기' 로 알린다.
    func savePreset(named name: String) {
        let name = Self.trimmed(name)
        guard !name.isEmpty else { return }
        let preset = Preset(name: name, colors: Self.strings(from: palette))
        if let index = presets.firstIndex(where: { $0.name == name }) {
            presets[index] = preset
        } else {
            presets.append(preset)
        }
        ToolDefaults.save(presets, key: Self.presetsKey)
        status = .presetSaved(name)
    }

    func loadPreset(_ preset: Preset) {
        palette = Self.palette(from: preset.colors)
        persistPalette()
        status = .presetLoaded(preset.name)
    }

    /// cmux Warm Light — 이 Tool 을 만들 때 쓰던 테마.
    func loadDefault() {
        palette = IntelliJThemeTemplate.defaultPalette
        persistPalette()
        status = .presetLoaded(IntelliJThemeTemplate.defaultName)
    }

    func deletePreset(_ preset: Preset) {
        presets.removeAll { $0.name == preset.name }
        ToolDefaults.save(presets, key: Self.presetsKey)
    }

    // MARK: - 대상

    /// 깔린 IntelliJ 와 그 설정 폴더, 지금 고른 테마를 다시 읽는다.
    func refresh() {
        target = Self.findTarget()
        guard let target else {
            currentThemeID = nil
            previous = nil
            return
        }
        currentThemeID = (try? Self.readLaf(target.configDir))?.themeID
        previous = Self.loadPrevious(Self.previousKey(target))
    }

    var isIntelliJRunning: Bool {
        guard let target else { return false }
        return !NSRunningApplication.runningApplications(withBundleIdentifier: target.bundleID).isEmpty
    }

    // MARK: - 적용 · 되돌리기

    /// 팔레트를 IntelliJ 에 적용한다.
    ///
    /// IntelliJ 는 설정을 메모리에 들고 있다가 종료할 때 다시 쓴다. 켜둔 채 파일을 바꾸면 종료할 때
    /// 덮이므로, 켜져 있으면 **종료 → 쓰기 → 다시 열기** 로 한다. 안 꺼지면 아무것도 쓰지 않는다.
    func apply() async {
        let rendered = IntelliJThemeTemplate.render(palette)
        await runWithIntelliJClosed(done: { .applied(relaunched: $0) }) { target in
            let key = Self.previousKey(target)
            let wasOurs = (try? Self.readLaf(target.configDir))?.themeID == IntelliJThemeTemplate.themeID
            try await Task.detached {
                // 다른 테마에서 처음 넘어올 때만 원래 것을 기억하고 원본 파일을 남긴다.
                // 이미 우리 테마면 기억한 값을 그대로 둔다 — 덮으면 되돌릴 곳이 우리 자신이 된다.
                if !wasOurs {
                    try Self.backup(target.configDir)
                }
                try Self.installPlugin(rendered, configDir: target.configDir)
            }.value
            if !wasOurs {
                let before = try Self.readCurrent(target.configDir)
                ToolDefaults.save(before, key: key)
            }
            try Self.select(Previous(themeID: IntelliJThemeTemplate.themeID,
                                     schemeName: IntelliJThemeTemplate.themeName,
                                     autodetect: "false"),
                            configDir: target.configDir)
        }
    }

    /// 적용하기 전의 테마로 돌린다. 만든 플러그인은 지우지 않는다 — 고르지 않으면 아무 일도 안 한다.
    func restore() async {
        guard let previous else {
            status = .failed(.nothingToRestore)
            return
        }
        await runWithIntelliJClosed(done: { .restored(relaunched: $0) }) { target in
            try Self.select(previous, configDir: target.configDir)
            UserDefaults.standard.removeObject(forKey: Self.previousKey(target))
        }
    }

    /// 켜져 있으면 끄고, `write` 를 하고, 원래 켜져 있었으면 다시 연다.
    private func runWithIntelliJClosed(done: (Bool) -> Status,
                                       write: (Target) async throws -> Void) async {
        guard !isBusy else { return }
        refresh()
        guard let target else {
            status = .failed(.notInstalled)
            return
        }
        guard FileManager.default.fileExists(atPath: target.configDir.path) else {
            status = .failed(.noConfigDir(target.configDir.path))
            return
        }

        let running = NSRunningApplication.runningApplications(withBundleIdentifier: target.bundleID)
        if !running.isEmpty {
            status = .working(.quitting)
            // 강제 종료하지 않는다. 저장 안 된 편집과 종료 확인 창을 IntelliJ 가 처리하게 둔다.
            running.forEach { $0.terminate() }
            guard await Self.waitUntilQuit(target.bundleID, timeout: Self.quitTimeout) else {
                status = .failed(.didNotQuit)
                return
            }
        }

        status = .working(.writing)
        do {
            try await write(target)
        } catch let failure as Failure {
            status = .failed(failure)
            refresh()
            return
        } catch {
            status = .failed(.writeFailed(error.localizedDescription))
            refresh()
            return
        }
        refresh()

        // 사용자가 띄우지 않은 IntelliJ 는 띄우지 않는다.
        if !running.isEmpty {
            status = .working(.relaunching)
            _ = try? await NSWorkspace.shared.openApplication(at: target.appURL,
                                                              configuration: NSWorkspace.OpenConfiguration())
        }
        status = done(!running.isEmpty)
    }

    private static func waitUntilQuit(_ bundleID: String, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty {
                return true
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    // MARK: - 저장

    private func persistPalette() {
        ToolDefaults.save(Self.strings(from: palette), key: Self.paletteKey)
    }

    private static func strings(from palette: Palette) -> [String: String] {
        Dictionary(uniqueKeysWithValues: palette.map { ($0.key.rawValue, $0.value) })
    }

    /// 모르는 키는 버리고, 없는 역할은 기본값으로 채운다.
    private static func palette(from strings: [String: String]) -> Palette {
        var palette = IntelliJThemeTemplate.defaultPalette
        for (key, value) in strings {
            guard let role = Role(rawValue: key), let hex = IntelliJThemeTemplate.normalized(value) else { continue }
            palette[role] = hex
        }
        return palette
    }

    private static func loadPrevious(_ key: String) -> Previous? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Previous.self, from: data)
    }

    private static func trimmed(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - IntelliJ 파일 (메인 스레드 밖에서도 부른다)

    /// 깔린 앱의 `product-info.json` 으로 설정 폴더를 정한다.
    ///
    /// 설정 폴더는 버전마다 남는다(이 맥에도 2025.2 · 2025.3 이 함께 있다). 폴더 목록이 아니라
    /// 실제 앱이 쓰는 이름을 따라야 엉뚱한 버전에 쓰지 않는다.
    nonisolated static func findTarget() -> Target? {
        for bundleID in bundleIDs {
            for appURL in NSWorkspace.shared.urlsForApplications(withBundleIdentifier: bundleID) {
                let info = appURL.appendingPathComponent("Contents/Resources/product-info.json")
                guard let data = try? Data(contentsOf: info),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let dataDir = json["dataDirectoryName"] as? String else { continue }
                let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                return Target(appURL: appURL,
                              bundleID: bundleID,
                              displayName: (json["name"] as? String) ?? appURL.deletingPathExtension().lastPathComponent,
                              version: (json["version"] as? String) ?? "",
                              configDir: support.appendingPathComponent("JetBrains/" + dataDir))
            }
        }
        return nil
    }

    private nonisolated static func lafURL(_ configDir: URL) -> URL {
        configDir.appendingPathComponent("options/laf.xml")
    }

    private nonisolated static func schemeURL(_ configDir: URL) -> URL {
        configDir.appendingPathComponent("options/colors.scheme.xml")
    }

    /// `laf.xml` 의 themeId 와 autodetect.
    nonisolated static func readLaf(_ configDir: URL) throws -> (themeID: String?, autodetect: String?) {
        guard let doc = try loadXML(lafURL(configDir)) else { return (nil, nil) }
        let component = try doc.nodes(forXPath: "/application/component[@name='LafManager']").first as? XMLElement
        let laf = component?.elements(forName: "laf").first
        return (laf?.attribute(forName: "themeId")?.stringValue,
                component?.attribute(forName: "autodetect")?.stringValue)
    }

    nonisolated static func readCurrent(_ configDir: URL) throws -> Previous {
        let laf = try readLaf(configDir)
        var scheme: String?
        if let doc = try loadXML(schemeURL(configDir)) {
            let node = try doc.nodes(forXPath: "/application/component[@name='EditorColorsManagerImpl']/global_color_scheme").first
            scheme = (node as? XMLElement)?.attribute(forName: "name")?.stringValue
        }
        return Previous(themeID: laf.themeID, schemeName: scheme, autodetect: laf.autodetect)
    }

    /// 두 파일에서 **해당 속성만** 바꾼다. 그 파일의 다른 내용은 그대로 둔다. `nil` 이면 그 항목을 지운다.
    nonisolated static func select(_ choice: Previous, configDir: URL) throws {
        let laf = try loadXML(lafURL(configDir)) ?? emptyApplication()
        let lafComponent = component(named: "LafManager", in: laf)
        let lafElement = child("laf", of: lafComponent, create: choice.themeID != nil)
        if let themeID = choice.themeID {
            lafElement.map { setAttribute("themeId", themeID, on: $0) }
            // 예전 형식의 `class-name` 이 남아 있으면 그것이 이길 수 있다.
            lafElement?.removeAttribute(forName: "class-name")
        } else if let lafElement {
            lafComponent.removeChild(at: lafElement.index)
        }
        if let autodetect = choice.autodetect {
            setAttribute("autodetect", autodetect, on: lafComponent)
        } else {
            lafComponent.removeAttribute(forName: "autodetect")
        }
        try write(laf, to: lafURL(configDir))

        let scheme = try loadXML(schemeURL(configDir)) ?? emptyApplication()
        let schemeComponent = component(named: "EditorColorsManagerImpl", in: scheme)
        let schemeElement = child("global_color_scheme", of: schemeComponent, create: choice.schemeName != nil)
        if let name = choice.schemeName {
            schemeElement.map { setAttribute("name", name, on: $0) }
        } else if let schemeElement {
            schemeComponent.removeChild(at: schemeElement.index)
        }
        try write(scheme, to: schemeURL(configDir))
    }

    /// `plugins/mymactools-theme/lib/mymactools-theme.jar` 를 새로 만든다.
    nonisolated static func installPlugin(_ rendered: IntelliJThemeTemplate.Rendered, configDir: URL) throws {
        let fm = FileManager.default
        let staging = fm.temporaryDirectory.appendingPathComponent("mymactools-theme-" + UUID().uuidString)
        defer { try? fm.removeItem(at: staging) }

        let files: [(String, String)] = [
            ("META-INF/plugin.xml", rendered.pluginXML),
            ("theme/" + IntelliJThemeTemplate.themeFile, rendered.themeJSON),
            ("theme/" + IntelliJThemeTemplate.schemeFile, rendered.schemeXML),
        ]
        for (path, content) in files {
            let url = staging.appendingPathComponent(path)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try content.write(to: url, atomically: true, encoding: .utf8)
        }

        let jarName = IntelliJThemeTemplate.pluginFolder + ".jar"
        let built = staging.appendingPathComponent(jarName)
        // Foundation 에 zip API 가 없다. jar 는 zip 이고 `/usr/bin/zip` 은 macOS 기본이다.
        let zip = Process()
        zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        zip.arguments = ["-q", "-X", "-r", jarName, "META-INF", "theme"]
        zip.currentDirectoryURL = staging
        let errors = Pipe()
        zip.standardError = errors
        try zip.run()
        zip.waitUntilExit()
        guard zip.terminationStatus == 0 else {
            let message = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw Failure.writeFailed("zip \(zip.terminationStatus) \(message)")
        }

        let lib = configDir.appendingPathComponent("plugins/\(IntelliJThemeTemplate.pluginFolder)/lib")
        try fm.createDirectory(at: lib, withIntermediateDirectories: true)
        let destination = lib.appendingPathComponent(jarName)
        if fm.fileExists(atPath: destination.path) {
            _ = try fm.replaceItemAt(destination, withItemAt: built)
        } else {
            try fm.moveItem(at: built, to: destination)
        }
    }

    /// 고치기 전의 `laf.xml` · `colors.scheme.xml` 을 남긴다.
    nonisolated static func backup(_ configDir: URL) throws {
        let fm = FileManager.default
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let folder = support.appendingPathComponent(
            "MyMacTools/intellij-backup/\(configDir.lastPathComponent)/\(stamp)")
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        for source in [lafURL(configDir), schemeURL(configDir)] where fm.fileExists(atPath: source.path) {
            try fm.copyItem(at: source, to: folder.appendingPathComponent(source.lastPathComponent))
        }
    }

    // MARK: - XML

    private nonisolated static func loadXML(_ url: URL) throws -> XMLDocument? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try XMLDocument(contentsOf: url, options: [])
    }

    private nonisolated static func emptyApplication() -> XMLDocument {
        let doc = XMLDocument(rootElement: XMLElement(name: "application"))
        doc.characterEncoding = "UTF-8"
        return doc
    }

    private nonisolated static func component(named name: String, in doc: XMLDocument) -> XMLElement {
        let root = doc.rootElement() ?? {
            let root = XMLElement(name: "application")
            doc.setRootElement(root)
            return root
        }()
        if let found = root.elements(forName: "component").first(where: {
            $0.attribute(forName: "name")?.stringValue == name
        }) {
            return found
        }
        let created = XMLElement(name: "component")
        setAttribute("name", name, on: created)
        root.addChild(created)
        return created
    }

    /// 같은 이름의 속성이 있으면 값만 바꾼다. 다른 속성은 건드리지 않는다.
    private nonisolated static func setAttribute(_ name: String, _ value: String, on element: XMLElement) {
        if let existing = element.attribute(forName: name) {
            existing.stringValue = value
        } else if let attribute = XMLNode.attribute(withName: name, stringValue: value) as? XMLNode {
            element.addAttribute(attribute)
        }
    }

    private nonisolated static func child(_ name: String, of parent: XMLElement, create: Bool) -> XMLElement? {
        if let found = parent.elements(forName: name).first { return found }
        guard create else { return nil }
        let created = XMLElement(name: name)
        parent.addChild(created)
        return created
    }

    private nonisolated static func write(_ doc: XMLDocument, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // IntelliJ 가 쓰는 꼴처럼 XML 선언 없이 쓴다.
        let text = doc.rootElement()?.xmlString(options: [.nodePrettyPrint, .nodeCompactEmptyElement]) ?? "<application />"
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
}
