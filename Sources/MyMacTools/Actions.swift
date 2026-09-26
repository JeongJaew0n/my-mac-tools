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

    /// 상태 막대에서 **켤 때**는 저장된 기본값으로 되돌린 뒤 시작한다.
    ///
    /// 메뉴에는 값을 고르는 자리가 없다. 창에서 값을 만지다 저장하지 않고 닫아두면,
    /// 메뉴에서 켠 세션이 **사용자가 기억하지 못하는 값**으로 돈다. 기본값으로 맞추면
    /// 메뉴에서 켠 것이 언제나 같은 값으로 돈다.
    ///
    /// 되돌린 값은 창에도 그대로 보인다. 화면이 실제 상태와 다른 말을 하지 않게
    /// 하는 것이 이 앱의 규칙이다 (`docs/DESIGN.md`).
    ///
    /// **끄는 것은 그냥 끈다.** 끌 때 값을 건드리면 사용자가 창에서 고르던 중인 값을
    /// 메뉴가 지워버린다.
    static func toggleScreenOffFromMenu(_ manager: BlackWorkManager) {
        if !manager.isRunning { manager.restoreDefault() }
        manager.toggle()
    }

    /// 덮개 기능도 같은 규칙이다.
    static func toggleLidFromMenu(_ lid: LidWorkManager, _ manager: BlackWorkManager) {
        if !lid.isRunning { lid.restoreDefault() }
        toggleLid(lid, manager)
    }
}
