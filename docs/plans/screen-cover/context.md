# context — screen-cover

## 원 요청 (2026-09-16)

> 이건 잠금화면은 아니고, 화면을 특정 사진을 띄워서 가리는데, 내부에선 잠자기가 아니라 다
> 돌아가고 있는 상태. 모든 모니터에 해당 사진이 뜨면 돼.

해제 조건은 처음에 "버튼 클릭 or 비밀번호 입력" 으로 제시됐다가, 용도를 확인한 뒤
**버튼만** 으로 정리됐다.

> 이건 잠금화면이 아니라 잠깐 쉴때 모니터 앞에서 틀어두는 용도임. 이 기능의 readme에
> 명시해. 그래서 별도 잠금이 사실 필요가 없음. 그냥 버튼만 누르면돼.

## 결정 이유

### 인증을 넣지 않는다

용도가 "자리를 비우는 동안의 보안" 이 아니라 "잠깐 쉴 때 틀어두는 가림막" 이다. 인증이
있으면 보안 기능처럼 보이는데, 실제로는 `Cmd-Q` 하나로 뚫리므로 **있지도 않은 보호를
있다고 믿게 만든다.** 그 오해가 인증이 없는 것보다 위험하다.

그래서 README 에 "잠금이 아니다" 를 명시하는 것이 이 기능의 요구사항 중 하나다.

### 기각 — 계정 비밀번호를 앱이 직접 검증

검토 단계에서 `OpenDirectory` 의 `ODRecord.verifyPassword(_:)` 로 기술적으로 가능한 것은
확인했다. 쓰지 않기로 했다. 잠금처럼 보이는 화면이 실제 계정 암호를 묻는 것은 피싱과 구조가
같다. 그 조작에 익숙해지는 것 자체가 위험하고, 회사 장비면 더 그렇다.

### 기각 — `LocalAuthentication` (Touch ID / 기기 암호)

실측으로 이 맥에서 쓸 수 있는 것은 확인했다 (`canEvaluatePolicy(.deviceOwnerAuthentication)`
= `true`, `biometryType` = Touch ID). 시스템 프롬프트가 처리하므로 앱이 암호를 보지 않아
위 문제도 없다.

그럼에도 넣지 않는다. **용도상 필요가 없다.** 인증을 붙이는 순간 위의 "보안 기능처럼
보이는" 문제가 그대로 돌아온다. 나중에 정말 잠금이 필요해지면 그때 별개 기능으로 만든다.

### 기각 — 슬립 차단에 `caffeinate -d` 나 `pmset -a disablesleep`

`IOPMAssertionCreateWithName` 을 인프로세스로 잡는 쪽이 모든 면에서 낫다. sudo 가 필요
없고, 서브프로세스가 없고, 프로세스가 죽으면 커널이 회수한다.

덮개 기능에서 `disablesleep` 이 전역·영구라 겪은 문제들 — 앱이 비정상 종료하면 값이 남고,
sudoers 규칙을 따로 깔아야 하고, `pmset sleepnow` 와 충돌하는 것 — 이 여기엔 하나도 없다.
`docs/troubleshootings/` 의 `pmset-*`, `sudo-*`, `caffeinate-*` 항목이 전부 그 비용이었다.

## 검토 단계에서 실측한 것

```
디스플레이 3대
  LF24T450F            1920x1080  scale 1.0   (주)
  Built-in Retina      1512x982   scale 2.0
  S24E450              1920x1080  scale 1.0

윈도우 레벨
  mainMenu    = 24
  screenSaver = 1000
  CGShieldingWindowLevel() = 2147483628

IOPMAssertionCreateWithName(PreventUserIdleDisplaySleep) -> 성공, sudo 불필요
  pmset -g assertions 에 이름으로 노출됨
  Release 성공, 프로세스 종료 후 잔존 0건
```

해상도와 배율이 제각각인 것이 "화면별로 따로 스케일링" 결정의 근거다.

## 참고

- `docs/plans/tabbed-window/spec.md` — 탭 추가 방식
- `docs/troubleshootings/reusable/caffeinate-does-not-block-lid-close-sleep.md`
- `docs/troubleshootings/reusable/password-prompt-after-opening-lid-is-screen-lock.md`
  — 디스플레이가 꺼지면 60초 뒤 화면 잠금이 걸린다는 실측. 슬립 차단 결정의 근거다.
