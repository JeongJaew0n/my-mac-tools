import AppKit
import Darwin
import Foundation

/// 지금 돌고 있는 프로세스를 커널에서 한 번에 읽어온 스냅숏.
///
/// `ps` 를 띄우지 않고 `sysctl` 을 직접 부른다. 목록을 몇 초마다 훑는 화면이 둘(카페인,
/// 로컬호스트)이라 그때마다 `fork`/`exec` 를 하는 것은 낭비다. `LidWorkManager` 가
/// `ioreg` 대신 IOKit 을, `BlackWorkManager` 가 `pmset` 대신 `CGDisplayIsAsleep` 을
/// 부르는 것과 같은 판단이다.
enum ProcessSnapshot {

    /// 전체 프로세스. 실패하면 빈 배열.
    static func all() -> [kinfo_proc] {
        var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size = 0
        guard sysctl(&name, 3, nil, &size, nil, 0) == 0, size > 0 else { return [] }

        // 두 호출 사이에 프로세스가 늘어날 수 있다. 여유를 두고 받아, 실제로 채워진
        // 만큼만 쓴다.
        size += MemoryLayout<kinfo_proc>.stride * 16
        var buffer = [kinfo_proc](repeating: kinfo_proc(),
                                  count: size / MemoryLayout<kinfo_proc>.stride)
        guard sysctl(&name, 3, &buffer, &size, nil, 0) == 0 else { return [] }

        return Array(buffer.prefix(size / MemoryLayout<kinfo_proc>.stride))
    }

    /// 커널이 들고 있는 짧은 이름. 16자로 잘려 있다.
    static func shortName(of entry: kinfo_proc) -> String {
        withUnsafeBytes(of: entry.kp_proc.p_comm) { raw in
            guard let base = raw.baseAddress else { return "" }
            return String(cString: base.assumingMemoryBound(to: CChar.self))
        }
    }

    /// 실행 파일의 전체 경로. 다른 사용자 소유거나 커널이 막으면 nil.
    ///
    /// 같은 uid 인데도 실패하는 프로세스가 있다 (실측 — pid 11100). 그래서 이름을 만들
    /// 때는 짧은 이름으로 떨어질 자리를 반드시 남긴다.
    static func executablePath(of pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(cString: buffer)
    }

    /// 프로세스 시작 시각.
    static func startDate(of entry: kinfo_proc) -> Date {
        let time = entry.kp_proc.p_starttime
        return Date(timeIntervalSince1970: Double(time.tv_sec) + Double(time.tv_usec) / 1_000_000)
    }

    /// 사람이 읽을 이름.
    ///
    /// 경로의 마지막 조각을 그대로 쓰면 주인을 알 수 없는 경우가 있다. Claude Code 는
    /// `/Users/…/share/claude/versions/2.1.276` 이라 `2.1.276` 만 보이고, 커널의 짧은
    /// 이름도 똑같이 `2.1.276` 이다. 그래서 세 단계로 찾는다.
    ///
    /// 1. GUI 앱이면 `NSRunningApplication` 의 표시 이름 — 사용자가 Dock 에서 보는 그 이름이다
    /// 2. `.app` 번들 안이면 번들 이름
    /// 3. 그 외에는 경로를 뒤에서부터 훑어, 버전처럼 생긴 조각과 어느 앱에나 있는
    ///    일반적인 폴더 이름을 건너뛴 첫 조각 (`…/claude/versions/2.1.276` → `claude`)
    static func friendlyName(of pid: pid_t, path: String?, shortName: String) -> String {
        if let name = NSRunningApplication(processIdentifier: pid)?.localizedName, !name.isEmpty {
            return name
        }

        guard let path, !path.isEmpty else { return shortName }

        let components = path.split(separator: "/").map(String.init)

        if let index = components.firstIndex(where: { $0.hasSuffix(".app") }) {
            return String(components[index].dropLast(".app".count))
        }

        if let meaningful = components.reversed().first(where: {
            !looksLikeVersion($0) && !genericComponents.contains($0)
        }) {
            return meaningful
        }

        return components.last ?? shortName
    }

    // MARK: - Private

    /// 버전 번호처럼 생긴 경로 조각. `2.1.276`, `1.0`, `276` 같은 것.
    private static func looksLikeVersion(_ component: String) -> Bool {
        !component.isEmpty
            && component.contains(where: \.isNumber)
            && component.allSatisfy { $0.isNumber || $0 == "." || $0 == "-" || $0 == "_" }
    }

    /// 이름 구실을 못 하는 경로 조각. 어느 앱이든 같은 자리에 있는 것들이다.
    private static let genericComponents: Set<String> = [
        "versions", "version", "current", "bin", "sbin", "libexec", "MacOS",
        "Contents", "Resources", "usr", "local", "share", "lib", "opt",
    ]
}
