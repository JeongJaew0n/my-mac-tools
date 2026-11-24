import SwiftUI

/// 앱 메뉴 "업데이트…" 로 여는 창. 열 때 GitHub 의 최신 릴리스를 묻는다.
struct UpdateView: View {
    @ObservedObject var update: UpdateManager
    @ObservedObject var sleep: BlackWorkManager
    @ObservedObject var lid: LidWorkManager
    @ObservedObject var cover: ScreenCoverManager
    @ObservedObject var speedTest: SpeedTestManager
    @ObservedObject var capture: CaptureEditManager
    @ObservedObject var l10n: L10n
    let close: () -> Void

    /// 앱이 다시 켜지면 끊기는 것. 하나라도 있으면 업데이트를 막는다.
    private var blockers: [L10n.Key] {
        UpdateManager.blockers(sleep: sleep.isRunning, lid: lid.isRunning, cover: cover.isCovering,
                               speedTest: speedTest.isRunning, capture: capture.isEditing)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Space.block) {
            installedLine

            if update.rolledBack {
                Text(l10n(.updateRolledBack))
                    .font(.callout)
                    .foregroundStyle(Design.Color.statusWarning)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
        }
        .padding(Design.Inset.screen)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            if update.phase == .idle { await update.check() }
        }
    }

    /// `지금 버전: 0.1.0 · abc1234`. 빌드 커밋은 같은 버전의 로컬 빌드를 구별하려고 함께 보인다.
    private var installedLine: some View {
        let installed = update.installed
        var parts = [installed.version.map(String.init(describing:)) ?? l10n(.updateVersionUnknown)]
        if let commit = installed.commit { parts.append(String(commit.prefix(7))) }
        if installed.dirty { parts.append(l10n(.updateLocalChanges)) }
        return Text(l10n(.updateInstalled, parts.joined(separator: " · ")))
            .font(.callout.monospacedDigit())
            .foregroundStyle(Design.Color.textSecondary)
            .textSelection(.enabled)
    }

    @ViewBuilder
    private var content: some View {
        switch update.phase {
        case .idle, .checking:
            progress(l10n(.updateChecking))

        case .upToDate(let latest):
            Text(l10n(.updateUpToDate, latest.description))
                .fixedSize(horizontal: false, vertical: true)
            buttons(primary: nil)

        case .noRelease:
            Text(l10n(.updateNoRelease))
                .fixedSize(horizontal: false, vertical: true)
            buttons(primary: nil)

        case .available(let available):
            Text(l10n(.updateAvailable, available.release.version.description))
                .font(.headline)
                .textSelection(.enabled)
            if available.commits.isEmpty {
                Text(l10n(.updateUnknownNote))
                    .font(.caption)
                    .foregroundStyle(Design.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(l10n(.updateCommits, available.commits.count))
                    .font(.callout)
                    .foregroundStyle(Design.Color.textSecondary)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Design.Space.listRow) {
                    // 새것부터 보인다.
                    ForEach(available.commits.reversed()) { commit in
                        HStack(alignment: .firstTextBaseline, spacing: Design.Space.inline) {
                            Text(verbatim: String(commit.sha.prefix(7)))
                                .font(.caption.monospaced())
                                .foregroundStyle(Design.Color.textSecondary)
                            Text(verbatim: commit.title)
                                .font(.callout)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            }
            if !blockers.isEmpty {
                Text(l10n(.updateBlocked, blockers.map { l10n($0) }.joined(separator: ", ")))
                    .font(.callout)
                    .foregroundStyle(Design.Color.statusWarning)
                    .fixedSize(horizontal: false, vertical: true)
            }
            buttons(primary: blockers.isEmpty ? l10n(.updateButton) : nil)

        case .working(let step):
            switch step {
            case .fetching: progress(l10n(.updateFetching))
            case .building: progress(l10n(.updateBuilding))
            case .verifying: progress(l10n(.updateVerifying))
            }

        case .restarting:
            progress(l10n(.updateRestarting))

        case .failed(let failure):
            failureText(failure)
            if case .command(let log) = failure, !log.isEmpty {
                ScrollView {
                    Text(verbatim: log)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text(verbatim: UpdateManager.paths.log.path)
                    .font(.caption2)
                    .foregroundStyle(Design.Color.textSecondary)
                    .textSelection(.enabled)
            }
            HStack {
                Spacer()
                Button(l10n(.updateRecheck)) { Task { await update.check() } }
            }
        }
    }

    private func progress(_ text: String) -> some View {
        HStack(spacing: Design.Space.inline) {
            ProgressView().controlSize(.small)
            Text(text)
        }
    }

    private func failureText(_ failure: UpdateManager.Failure) -> some View {
        let text: String
        switch failure {
        case .network(let reason): text = l10n(.updateFailedNetwork, reason)
        case .noTools: text = l10n(.updateFailedNoTools)
        case .command: text = l10n(.updateFailedCommand)
        case .verify(let reason): text = l10n(.updateFailedVerify, reason)
        case .notWritable(let path): text = l10n(.updateFailedNotWritable, path)
        }
        return Text(text)
            .foregroundStyle(Design.Color.statusError)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// 나중에(창 닫기) + 주 동작. 주 동작이 없으면 닫기만.
    private func buttons(primary: String?) -> some View {
        HStack(spacing: Design.Space.inline) {
            Spacer()
            Button(l10n(.updateLater), action: close)
                .keyboardShortcut(.cancelAction)
            if let primary {
                Button(primary) { Task { await update.update() } }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}
