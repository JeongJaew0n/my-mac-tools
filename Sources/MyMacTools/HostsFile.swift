import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// 로컬호스트 Tool 안의 `/etc/hosts` — 읽어서 보여주고, 고른 편집기로 연다.
///
/// **앱은 이 파일을 쓰지 않는다.** `root:wheel 644` 라 저장하려면 관리자 권한이 필요하고,
/// 잘못 쓰면 이름 해석이 깨진다. 저장은 편집기에 맡긴다 — VS Code 는 관리자 인증으로
/// 저장하고, TextEdit 는 저장하지 못한다. 근거는 `docs/plans/hosts-file/spec.md`.
@MainActor
final class HostsFile: ObservableObject {
    static let url = URL(fileURLWithPath: "/etc/hosts")
    private static let editorKey = "hostsEditorPath"

    /// 주석·빈 줄을 뺀 항목 줄. 공백은 하나로 줄였다.
    @Published private(set) var entries: [String] = []
    /// 파일을 읽지 못했다. 항목이 없는 것과 다른 상태다.
    @Published private(set) var readFailed = false
    /// 사용자가 고른 편집기. 없으면 시스템 기본으로 연다.
    @Published private(set) var chosenEditor: URL?
    /// 열기에 실패한 이유. 다시 열면 비운다.
    @Published private(set) var openProblem: OpenProblem?
    /// macOS 가 이 파일에 주는 기본 앱. hosts 는 확장자가 없는 `public.data` 라 대개 TextEdit 다.
    ///
    /// `reload()` 때 한 번 묻고 기억한다. 계산 속성으로 두면 화면을 그릴 때마다 여러 번 묻는다.
    @Published private(set) var defaultEditor: URL?

    enum OpenProblem: Equatable {
        /// 열 앱이 없다 — 기본 앱도 없고 고른 것도 없다.
        case noApp
        /// macOS 가 돌려준 이유. 이미 사용자 언어로 되어 있다.
        case failed(String)
    }

    init() {
        chosenEditor = Self.restoreEditor()
        defaultEditor = NSWorkspace.shared.urlForApplication(toOpen: Self.url)
    }

    /// 버튼이 실제로 열 앱.
    var editor: URL? { chosenEditor ?? defaultEditor }

    /// 탭을 열 때와 앱이 다시 앞으로 올 때 부른다. 편집기에서 고치고 돌아오면 바로 보이게.
    ///
    /// 읽기와 나누기는 메인 스레드 밖에서 한다. 광고 차단용 hosts 는 수만 줄이라, 앱으로
    /// 돌아올 때마다 메인에서 읽으면 창이 멈춘다.
    func reload() {
        defaultEditor = NSWorkspace.shared.urlForApplication(toOpen: Self.url)
        let url = Self.url
        Task {
            let parsed = await Task.detached(priority: .userInitiated) { Self.parse(url) }.value
            readFailed = parsed == nil
            entries = parsed ?? []
        }
    }

    /// 주석·빈 줄을 뺀 항목 줄. 못 읽으면 `nil`.
    nonisolated private static func parse(_ url: URL) -> [String]? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return text
            .split(whereSeparator: \.isNewline)
            .map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }

    func open() {
        openProblem = nil
        guard let app = editor else {
            openProblem = .noApp
            return
        }
        NSWorkspace.shared.open([Self.url], withApplicationAt: app,
                                configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
            guard let error else { return }
            let reason = error.localizedDescription
            Task { @MainActor in self?.openProblem = .failed(reason) }
        }
    }

    /// `/etc` 는 Finder 에서 숨겨진 폴더라 찾아가기 번거롭다. 고른 채로 연다.
    func reveal() {
        NSWorkspace.shared.activateFileViewerSelecting([Self.url.resolvingSymlinksInPath()])
    }

    func choose(_ app: URL) {
        chosenEditor = app
        UserDefaults.standard.set(app.path, forKey: Self.editorKey)
    }

    func chooseDefault() {
        chosenEditor = nil
        UserDefaults.standard.removeObject(forKey: Self.editorKey)
    }

    /// 앱을 골라 바로 연다. Finder 의 "다른 앱으로 열기" 와 같다.
    ///
    /// 편집기 목록을 만들어 보여주지 않는다. LaunchServices 에 물으면 hosts 기준으로는 VS Code 가
    /// 빠지고, 텍스트 기준으로는 브라우저·Excel·캐시 속 사본까지 나온다(`context.md`).
    func chooseOther(prompt: String) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = prompt
        guard panel.runModal() == .OK, let app = panel.url else { return }
        choose(app)
        open()
    }

    /// 번들 파일 이름. `displayName` 은 **시스템** 언어를 따라, 앱 언어를 영어로 둬도
    /// "Open with 텍스트 편집기" 가 나왔다(렌더링 캡처). 파일 이름은 언어와 무관하다.
    static func name(of app: URL) -> String {
        app.deletingPathExtension().lastPathComponent
    }

    /// 고른 앱이 지워졌으면 기록을 지우고 시스템 기본으로 돌아간다.
    private static func restoreEditor() -> URL? {
        guard let path = UserDefaults.standard.string(forKey: editorKey) else { return nil }
        guard FileManager.default.fileExists(atPath: path) else {
            UserDefaults.standard.removeObject(forKey: editorKey)
            return nil
        }
        return URL(fileURLWithPath: path)
    }
}

/// 로컬호스트 탭 아래에 붙는 hosts 블록.
struct HostsFileSection: View {
    @ObservedObject var hosts: HostsFile
    @ObservedObject var l10n: L10n

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Space.listItem) {
            VStack(alignment: .leading, spacing: Design.Space.rowTight) {
                Text(l10n(.hostsTitle))
                    .font(.headline)
                Text(HostsFile.url.path)
                    .font(.caption)
                    .foregroundStyle(Design.Color.textSecondary)
            }

            if hosts.readFailed {
                Text(l10n(.hostsReadFailed))
                    .font(.caption)
                    .foregroundStyle(Design.Color.statusError)
            } else if hosts.entries.isEmpty {
                Text(l10n(.hostsEmpty))
                    .font(.caption)
                    .foregroundStyle(Design.Color.textSecondary)
            } else {
                // 보이는 줄만 만든다. 탭 전체가 스크롤 뷰 안이라 줄이 수만 개여도 한꺼번에 그리지 않는다.
                LazyVStack(alignment: .leading, spacing: Design.Space.rowTight) {
                    ForEach(Array(hosts.entries.enumerated()), id: \.offset) { _, line in
                        Text(verbatim: line)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                }
            }

            // 앱 이름이 길면("Visual Studio Code") 최소 폭에서 옆 버튼이 잘렸다(렌더링 캡처). 안 들어가면 두 줄로.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Design.Space.inline) {
                    editorMenu
                    revealButton
                }
                VStack(alignment: .leading, spacing: Design.Space.rowTight) {
                    editorMenu
                    revealButton
                }
            }
            .controlSize(.small)

            // 저장은 편집기가 한다. TextEdit 로 열면 고쳐도 저장되지 않아 헤맨다 — 미리 알린다.
            Text(l10n(.hostsSaveNote))
                .font(.caption)
                .foregroundStyle(Design.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let problem = hosts.openProblem {
                Group {
                    switch problem {
                    case .noApp: Text(l10n(.hostsNoApp))
                    case .failed(let reason): Text(l10n(.hostsOpenFailed, reason))
                    }
                }
                .font(.caption)
                .foregroundStyle(Design.Color.statusError)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { hosts.reload() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hosts.reload()
        }
    }

    private var revealButton: some View {
        Button(l10n(.hostsReveal)) { hosts.reveal() }
            .fixedSize()
    }

    /// 누르면 고른 앱으로 열고, 화살표로 앱을 바꾼다.
    private var editorMenu: some View {
        Menu {
            if let chosen = hosts.chosenEditor {
                Button {
                    hosts.open()
                } label: {
                    Label(HostsFile.name(of: chosen), systemImage: "checkmark")
                }
            }
            if let fallback = hosts.defaultEditor {
                Button {
                    hosts.chooseDefault()
                    hosts.open()
                } label: {
                    let title = l10n(.hostsDefaultApp, HostsFile.name(of: fallback))
                    if hosts.chosenEditor == nil {
                        Label(title, systemImage: "checkmark")
                    } else {
                        Text(title)
                    }
                }
            }
            Divider()
            Button(l10n(.hostsChooseOther)) {
                hosts.chooseOther(prompt: l10n(.hostsChoosePrompt))
            }
        } label: {
            Text(hosts.editor.map { l10n(.hostsOpenWith, HostsFile.name(of: $0)) } ?? l10n(.hostsOpen))
        } primaryAction: {
            hosts.open()
        }
        .fixedSize()
    }
}
