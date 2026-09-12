# spec — lid-close-keep-working

## 목표
MyMacTools 앱에서 버튼 하나(시작/중지)로 "맥북 덮개를 닫아도 모든 앱이 계속 동작하는 상태"를
켜고 끌 수 있게 한다. 외장 디스플레이 없이 덮개만 닫는 시나리오가 대상이다.

## 배경 기술
- 덮개 닫기 잠자기는 **유휴 잠자기가 아니라 강제 잠자기 경로**라 `caffeinate` 의 assertion
  (`-d/-i/-m/-s/-u`)으로는 막을 수 없다. 실측으로 확인했다 — caffeinate 가 떠 있는 상태에서도
  `pmset -g log` 에 `Clamshell Sleep` 이 기록됐다.
- kext 기반 도구(InsomniaX, NoSleep)는 Apple Silicon 에서 동작하지 않는다.
- 유일한 1st-party 수단은 `pmset -a disablesleep 1` 이다. 커널 `IOPMrootDomain` 의
  `SleepDisabled` 값을 뒤집으며, 이 플래그가 덮개 닫기 잠자기를 결정한다.
  단 `man pmset` 에 문서화되어 있지 않은 비공식 플래그다.
- `disablesleep` 은 **시스템 잠자기 전체**를 끈다. 덮개 닫기만 막는 것이 아니라, 켜져 있는
  동안에는 덮개를 열어두어도 맥이 잠들지 않는다. 화면 슬립은 별개라 그대로 동작한다.

## 범위
- 포함:
  - `LidWorkManager`(가칭) 신규 클래스 — `disablesleep` 토글과 실제 상태 조회
  - `ContentView` 하단에 구분선 + 별도 섹션(상태 표시 · 주의사항 텍스트 · 버튼 1개)
  - 관리자 인증 다이얼로그를 통한 root 권한 획득
  - 앱 종료 시 경고 다이얼로그, 앱 실행 시 실제 상태 읽어 버튼 복원
  - `L10n.Key` 신규 키 + `ko/en/ja.lproj` 3개 파일 동시 갱신
- 제외:
  - 전원 소스(AC/배터리) 감시 및 자동 차단 — 의도적으로 하지 않는다. 판단은 사용자 몫.
  - 발열 감시, 배터리 잔량 감시
  - 기존 `BlackWorkManager` 세션 로직 변경 (완전 독립)
  - LaunchDaemon 방식 (아래 context.md 의 기각 사유 참고)

## 확정된 결정

| 결정 축 | 확정 내용 | 근거 |
|---|---|---|
| Security | `NSAppleScript` 로 `do shell script "..." with administrator privileges` 실행 | 앱이 ad-hoc 서명이라 `SMJobBless` 기반 권한 헬퍼를 쓸 수 없다. 설치 과정 없이 동작하는 유일한 수단 |
| Failure-mode | 켜진 상태로 종료 시도 시 경고 다이얼로그(중지하고 종료 / 그대로 종료). 앱 실행 시 `ioreg` 의 `SleepDisabled` 실제 값을 읽어 버튼 상태를 복원 | 종료 중에는 인증 다이얼로그가 뜨지 않거나 사용자가 취소할 수 있어 자동 원복이 신뢰 불가. 기존 `CGDisplayIsAsleep` 로 실제 상태를 확인하는 패턴과 동일한 철학 |
| Scope | 기존 "화면 끄고 작업" 세션과 완전 독립. 구분선 아래 별도 섹션, 동시 실행 허용 | 시간 제한이 있는 세션 vs 상시 토글로 성격이 다르다 |
| UX | 버튼 위에 항상 보이는 정적 주의사항 텍스트. 전원 상태 감시·차단 없음 | 사용자 요구: "프로그램이 아니라 사용자가 지켜야 할 것" |

## 주의사항 문구 (UI 에 항상 표시)
1. AC 전원을 연결하세요. 배터리로 덮개를 닫으면 방전되어 강제 종료됩니다.
2. 닫은 채 장시간 무거운 작업은 피하세요. 키보드 상판이 주 방열면입니다.
3. 침대·쿠션 위에 두지 마세요.
4. 다 쓰면 반드시 중지하세요. 켜진 동안엔 덮개를 열어두어도 맥이 잠들지 않습니다.

## 인터페이스

```swift
final class LidWorkManager: ObservableObject {
    @Published private(set) var isRunning: Bool

    /// ioreg 에서 SleepDisabled 실제 값을 읽는다. 앱 상태를 믿지 않는다.
    var systemSleepDisabled: Bool { get }

    func start()   // 인증 다이얼로그 → pmset -a disablesleep 1
    func stop()    // 인증 다이얼로그 → pmset -a disablesleep 0
    func toggle()
    func refreshFromSystem()   // 실행 시 / 창 활성화 시 실제 상태 동기화
}
```

상태 조회는 권한이 필요 없다:
```
ioreg -n IOPMrootDomain -r -d 1 | grep SleepDisabled   →  "SleepDisabled" = Yes | No
```

## 완료 조건 (Definition of Done)
- [ ] 버튼을 누르면 인증 다이얼로그가 뜨고, 암호 입력 후 `SleepDisabled` 가 `Yes` 로 바뀐다
- [ ] 다시 누르면 `No` 로 돌아간다
- [ ] 인증을 취소하면 버튼 상태가 바뀌지 않는다 (낙관적 갱신 금지)
- [ ] 켜진 상태로 앱을 종료하려 하면 경고 다이얼로그가 뜬다
- [ ] 켜진 상태에서 앱을 강제 종료한 뒤 다시 실행하면 버튼이 ON 으로 보인다
- [ ] 기존 "화면 끄고 작업" 기능이 그대로 동작하고, 두 기능을 동시에 켤 수 있다
- [ ] 주의사항 4개가 ko/en/ja 3개 언어로 모두 표시된다
- [ ] 덮개를 실제로 닫았다 열었을 때 `pmset -g log` 에 `Clamshell Sleep` 이 새로 남지 않는다

## 의존성
- 외부 라이브러리 없음. `Foundation`, `SwiftUI`, `AppKit`(NSAppleScript/NSAlert) 만 사용
- 사전 작업: LaunchDaemon `local.clamshell-awake` 제거 (아래 checklist 0단계)

## 비고 / 알려진 제약
- `do shell script ... with administrator privileges` 는 같은 프로세스 안에서 약 5분간
  자격을 캐시한다. 그 이후 중지하려면 암호를 다시 묻는다.
- **확인 완료 (2026-09-12, `probe-conflicts.sh`)**: `disablesleep=1` 상태에서도
  `pmset displaysleepnow` 가 정상 동작한다. 화면 슬립과 시스템 슬립은 독립이다.
  화면이 꺼진 상태에서 `disablesleep` 플래그를 0→1 로 바꿔도 화면이 깨어나지 않는다.
  → 동시 실행 설계(Scope 결정)가 유효함이 확인됐다.
- **남은 미확인**: `disablesleep=1` 에서 `pmset sleepnow`(기능 A 의 "끝나면 잠자기")가
  무력화되는지. 무력화된다면 B 가 켜진 동안 해당 토글을 비활성화하거나 경고해야 한다.
- ad-hoc 서명이라 다른 맥으로 옮기면 Gatekeeper 경고가 뜬다. 이 기능과 무관한 기존 제약이다.
