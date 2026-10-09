import Foundation

/// 측정한 속도로 무엇을 할 수 있는가.
///
/// **기준값은 전부 각 서비스의 공식 문서에서 가져왔다.** 지어낸 기준은 숫자보다 나쁘다 —
/// 응답성 등급을 붙이지 않은 것과 같은 이유다. 출처와 확인한 날짜는
/// `docs/plans/speed-test/context.md` 의 *편의 기능 — 기준값 출처* 절.
///
/// 두 서비스의 값이 다르면 **더 엄격한 쪽**을 쓴다. 한쪽에서 버벅일 속도를 "된다" 고 하면 안 된다.
///
/// 게임은 넣지 않았다. 게임은 대역폭보다 지연이 갈리는데, 그 기준을 공식 문서에서
/// 확인하지 못했다(Xbox 페이지는 본문이 스크립트로 그려져 수치가 없었고 PlayStation 은 404).
enum SpeedUsage: String, CaseIterable, Identifiable {
    case video4K
    case video1080p
    case video720p
    case call1080p
    case callGroup720p

    var id: String { rawValue }

    /// 필요한 다운로드(Mbps).
    var downloadMbps: Double {
        switch self {
        case .video4K: return 20        // YouTube 20 · Netflix 15 → 엄격한 쪽
        case .video1080p: return 5      // YouTube 5 · Netflix 5
        case .video720p: return 3       // Netflix 3 · YouTube 2.5 → 엄격한 쪽
        case .call1080p: return 3.0     // Zoom 1:1 1080p 받기
        case .callGroup720p: return 1.8 // Zoom 그룹 720p 받기
        }
    }

    /// 필요한 업로드(Mbps). 보내는 쪽이 없는 활동은 nil.
    var uploadMbps: Double? {
        switch self {
        case .call1080p: return 3.8     // Zoom 1:1 1080p 보내기
        case .callGroup720p: return 2.6 // Zoom 그룹 720p 보내기
        default: return nil
        }
    }

    /// 툴팁에 붙일 출처. 서비스 이름과 그 서비스가 밝힌 값.
    var source: String {
        switch self {
        case .video4K: return "YouTube 20 Mbps · Netflix 15 Mbps"
        case .video1080p: return "YouTube 5 Mbps · Netflix 5 Mbps"
        case .video720p: return "Netflix 3 Mbps · YouTube 2.5 Mbps"
        case .call1080p: return "Zoom 1:1 1080p — ↑3.8 / ↓3.0 Mbps"
        case .callGroup720p: return "Zoom group 720p — ↑2.6 / ↓1.8 Mbps"
        }
    }

    var titleKey: L10n.Key {
        switch self {
        case .video4K: return .usageVideo4K
        case .video1080p: return .usageVideo1080p
        case .video720p: return .usageVideo720p
        case .call1080p: return .usageCall1080p
        case .callGroup720p: return .usageCallGroup720p
        }
    }

    func isSatisfied(by result: SpeedResult) -> Bool {
        let down = result.downloadBitsPerSecond / 1_000_000
        let up = result.uploadBitsPerSecond / 1_000_000
        return down >= downloadMbps && up >= (uploadMbps ?? 0)
    }

    /// 1 GB(10⁹ 바이트)를 옮기는 데 걸리는 이론상 초. 서버·혼잡에 따라 실제는 더 걸린다.
    static func secondsPerGigabyte(bitsPerSecond: Double) -> Double? {
        guard bitsPerSecond > 0 else { return nil }
        return 8_000_000_000 / bitsPerSecond
    }
}
