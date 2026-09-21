import Foundation

/// 여러 기능에 걸친 규칙. 창과 메뉴 양쪽에서 같은 조작을 할 수 있게 되면서
/// 규칙이 두 곳으로 갈라지지 않도록 여기 모은다.
///
/// 상태를 세우는 곳과 내리는 곳이 갈라져서 난 버그가 이미 두 번 있었다 —
/// `docs/troubleshootings/project-specific/` 의 카운트다운·안내 문구 항목.
enum Actions {

    /// 덮개 기능을 토글한다. **켜는 데 성공하면 "끝나면 Mac잠자기 모드" 를 함께 내린다.**
    ///
    /// `disablesleep=1` 이면 `pmset sleepnow` 가 `kIOReturnNotPermitted` 로 거부된다.
    /// 값을 남겨두면 만료 시각에 아무 일도 일어나지 않는 것처럼 보인다.
    static func toggleLid(_ lid: LidWorkManager, _ manager: BlackWorkManager) {
        if case .changed(true) = lid.toggle() {
            manager.sleepWhenDone = false
        }
    }
}
