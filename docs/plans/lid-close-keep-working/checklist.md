# checklist — lid-close-keep-working

> 작업 진행하면서 AI 가 순차적으로 체크. `[x]` 로 표시한 항목은 완료된 것으로 간주.
> 새 항목이 발견되면 적절한 단계에 추가하고 체크리스트를 유지한다.

## 0. 준비
- [x] spec.md / context.md 확인
- [x] 임시 LaunchDaemon 제거 완료 (사용자가 직접 실행)
      ```
      sudo launchctl bootout system/local.clamshell-awake
      sudo rm -f /Library/LaunchDaemons/local.clamshell-awake.plist \
                 /usr/local/bin/clamshell-awake.sh /var/log/clamshell-awake.err
      sudo pmset -a disablesleep 0
      ```
- [x] 제거 확인 — `SleepDisabled = No`
- [x] 상충 지점 식별 및 테스트 계획 작성 → `test-plan.md`
- [x] **Phase 1 실행** — 앱 코드 전에 시스템 사실 확정 (사용자가 sudo 로 실행)
      ```
      sudo bash docs/plans/lid-close-keep-working/probe-conflicts.sh
      ```
      - [x] T1 대조군 통과 — PASS
      - [x] T2 (C1) — PASS. 화면 꺼짐. 동시 실행 유효
      - [x] T3 (C3) — PASS. 화면 그대로 꺼져 있음
      - [x] T4 (C2) — PASS. error 0xe00002e2 로 실패. 잠들지 않음
- [x] Phase 1 결과를 spec.md 에 반영. 전 항목 통과, Scope 결정 유지

## 1. 구현
- [x] `Sources/MyMacTools/LidWorkManager.swift` 신규 — 상태 조회는 `ioreg` 프로세스 대신 IOKit 직접 읽기로. `NSAppleScript` 로 인증 실행
- [x] 인증 취소·실패 시 상태를 바꾸지 않는 경로 — `apply()` 가 항상 커널 값을 다시 읽어 확정. `ToggleOutcome` 으로 취소/실패 구분
- [x] `L10n.Key` 에 신규 키 15개 추가 (버튼은 기존 `button.start`/`button.stop` 재사용)
- [x] `Resources/ko.lproj/Localizable.strings` 갱신
- [x] `Resources/en.lproj/Localizable.strings` 갱신
- [x] `Resources/ja.lproj/Localizable.strings` 갱신
- [x] `ContentView` 에 구분선 + 신규 섹션(상태 · 주의사항 4줄 · 버튼) 추가
- [x] B 가 ON 이면 A 의 "끝나면 잠자기" 토글 비활성화 + caption 으로 이유 표시 (C2 대응)
- [x] `MyMacToolsApp` 에 `AppDelegate.applicationShouldTerminate` 로 종료 경고 연결 (중지하고 종료 / 그대로 종료 / 취소)
- [x] 앱 실행 시 + `didBecomeActive` 마다 `refreshFromSystem()` 으로 커널 값 동기화

## 2. 검증
- [x] 시작 → 인증 → `SleepDisabled=Yes` 확인 (19:05:41, 19:06:52)
- [x] 중지 → 인증 → `SleepDisabled=No` 확인 (19:06:02, 19:07:21)
- [x] 인증 취소 시 상태 유지 — 취소 시 관측 로그에 항목이 생기지 않음으로 확인
- [x] 켜진 상태로 종료 시도 → 경고 다이얼로그 확인
- [x] 강제 종료 후 재실행 → ON 복원 확인. `kill -9` 후에도 `SleepDisabled=Yes` 잔류(19:12:28), 재실행 후 유지(19:12:41)
- [x] Phase 2 상태 조합 + 순서 의존성 — 사용자 확인
- [x] C4 — 인증 다이얼로그가 블랭킹되지 않음. 인증 중 메인 스레드가 막혀 A 의 티커도 멈추는 것이 효과를 낸 것으로 보임
- [x] C5 — 사용자 확인
- [x] 3개 언어 36개 키 전부 해석됨 — 설치된 번들을 L10n 과 동일한 방식으로 읽어 검증
- [x] 실제 덮개 닫기 테스트 통과. 20:47:29 에 `com.apple.powermanagement.lidopen` assertion 생성(= 그 전까지 닫혀 있었음), 해당 구간에 `Entering Sleep` 없음, `Clamshell Sleep` 총 7건 그대로

## 3. 마무리
- [x] `./scripts/build-app.sh` 로 빌드, `/Applications` 에 재설치
- [x] main 에 직접 커밋 후 즉시 push (CLAUDE.md 규약)
- [x] 미체크 항목 없음
- [x] spec.md 에 Phase 1 결과 반영. README 에 기능 문서 추가

---

## 완료 (2026-09-12)

전 항목 통과. 구현·검증·문서화 끝.
임시 LaunchDaemon `local.clamshell-awake` 는 제거됐고, 기능은 앱 안으로 완전히 이관됐다.

## 4. 후속 — 암호 없이 동작 (2026-09-12)

- [x] `scripts/install-sudoers.sh` 작성 (설치/제거, `visudo -c` 3중 검증, 실패 시 롤백)
- [x] 규칙 범위 실측 — 자격 캐시를 비우고 확인. 허용 2개, 그 외 전부 거부
- [x] `LidWorkManager` 에 `sudo -n` 경로 + 인증 창 폴백
- [x] `sudo -n -l` 기반 판정 제거 — `-l` 은 "허용 여부"만 보고 자격 캐시로 거짓 양성이 난다.
      현재 값을 그대로 다시 쓰는 무해한 실제 명령으로 판정하도록 교체
- [x] 종료 시 자동 원복 (`canRevertSilently` 성공 시). 실패하면 기존 경고창으로 폴백
- [x] 종료 자동 원복 end-to-end 검증 — 앱 실행(Yes 복원) → `osascript` 로 quit →
      경고창 없이 종료 → `SleepDisabled=No` 자동 복귀
- [x] spec.md / context.md / README 갱신
- [ ] 규칙이 없는 환경에서의 폴백 재확인 — 규칙 설치 전 탐지가 실패함은 확인했고,
      인증 창 경로 자체는 이전 검증에서 통과했다. 둘을 한 번에 잇는 확인은 규칙을
      지웠다 다시 깔아야 해서 생략함

## 5. 코드 리뷰 반영 (2026-09-12)

- [x] `install-sudoers.sh` 검증문이 항상 통과하던 문제 — `sudo -n -l` 은 관리자 계정이면
      규칙과 무관하게 통과한다(캐시 없이 `sudo -n -l /bin/ls` 가 0 을 반환함을 실측).
      현재 값을 그대로 다시 쓰는 실제 실행으로 교체
- [x] 검증 실패 시 규칙 파일을 지우지 않고 "적용 안 됨"만 출력하던 문제 — 롤백 추가
- [x] `canRevertSilently` 가 캐시된 값을 써서 원복 직전에 오히려 켜버릴 수 있던 문제 —
      프로브 자체를 없애고 원복만 시도하는 `revertWithoutPrompting()` 으로 교체
- [x] 종료 판단이 갱신 없는 `isRunning` 을 보던 문제 — 판단 직전 `refreshFromSystem()`
- [x] 남이 켜둔 설정을 종료하며 말없이 끄던 문제 — `turnedOnByThisProcess` 소유권 가드
- [x] 덮개 기능을 켜도 `sleepWhenDone` 값이 남아 만료 시 조용히 실패하던 문제 —
      켜는 데 성공하면 같이 끈다
- [x] `lid.isRunning` 인데 `sleepWhenDone` 이 꺼져 있으면 "평소 절전으로 돌아갑니다"라는
      거짓 문구가 나오던 문제 — 조건을 `lid.isRunning` 단독으로
- [x] 창을 닫았다 열면 `didBecomeActive` 를 놓쳐 상태가 낡던 문제 — `.onAppear` 추가
- [x] `pmset` 직후 즉시 읽어 성공을 실패로 오판할 수 있던 문제 — 최대 0.5초 폴링
- [x] `sudo` 실패 사유(stderr)를 버리던 문제 — 인증 창까지 실패하면 함께 표시
- [x] 소유권 가드 검증 — 밖에서 켠 뒤 앱 종료 요청 시 경고창이 뜨고 값이 유지됨
- [x] 이 앱이 켠 뒤 종료 시 자동 원복 재확인 (2026-09-13) — 소유권 가드 추가 후에도
      정상 경로 유지. 종료 후 앱은 사라지고 `SleepDisabled=No`, 경고창 없음
- [x] `install-sudoers.sh` 새 검증문 동작 확인 (2026-09-13) — 재설치 시
      "현재 값 0 을 그대로 다시 썼습니다" 출력. 실제 실행으로 판정함이 확인됐고
      `SleepDisabled` 는 `No` 그대로여서 프로브가 무해함도 확인됨.
      규칙 범위 재확인: `disablesleep 0` ALLOW, `hibernatemode 0` / `sh -c id` DENY

## 6. 유지 시간 (2026-09-13)

요청: "몇 시간뒤에 클렘셸 다시 켜기 이런거 가능?" → 논의 결과 **예약 켜기가 아니라
N시간 뒤 자동 끄기**로 확정. 예약 켜기는 그 시각에 맥이 자고 있으면 타이머가 못 돌고,
깨우려면 `pmset schedule wake` 가 필요한데 이는 현재 sudoers 규칙 밖이다.

- [x] `LidWorkManager` 에 `hours`/`minutes`/`remaining`/`durationSeconds` 추가
- [x] 시작 성공 시 1초 티커, 만료 시 `revertWithoutPrompting()` 으로 자동 해제
- [x] 만료 시 인증 창을 띄우지 않는다 — 자리를 비운 상황이 전형이라 아무도 암호를 못 친다.
      조용히 끌 수 없으면 `autoStopFailed` 로 알리기만 하고 켜진 상태를 유지
- [x] UI: 유지 시간 피커(실행 중 잠김), 남은 시간 표시, 자동 해제 실패 문구
- [x] `lid.autoStopFailed` 3개 언어 추가 — 나머지는 기존 키 재사용
- [x] 만료 자동 해제 실제 동작 확인 (2026-09-13) — `0h 10m` 으로 시작,
      12:12:45 `SleepDisabled=Yes` → 12:22:16 `No` 로 자동 해제. 앱은 계속 실행 중이었고
      기능만 꺼졌다. 인증 창은 뜨지 않았다

## 7. 버그 수정 — 카운트다운이 실제 상태와 분리돼 있었음 (2026-09-13)

사용자 보고: "니가 종료시켰는데 시간이 돌고있다."
앱 밖에서 `pmset -a disablesleep 0` 을 돌렸더니 상태는 꺼졌는데 남은 시간은 계속 줄어들었다.

원인: `refreshFromSystem()` 이 `isRunning` 만 갱신하고 티커·`endDate`·`remaining` 은
건드리지 않았다. 이 기능 전체가 "로컬 기억을 믿지 말고 커널을 읽는다"는 원칙 위에 서 있는데
타이머만 그 원칙 밖에 있었다.

- [x] `refreshFromSystem()` 이 커널상 꺼져 있으면 카운트다운도 정리하고 소유권도 놓게 함
- [x] 티커를 유지 시간이 없을 때도 돌린다 — 카운트다운용만이 아니라 매 초 커널을 읽어
      표시를 현실과 맞추는 역할을 겸한다
- [x] `tick()` 이 먼저 `refreshFromSystem()` 으로 현실을 확인하고 진행
- [x] `docs/TROUBLESHOOTING.md` 에 기록
- [ ] 실제 재현 확인 — 유지 시간을 걸고 시작한 뒤 밖에서 끄면 1초 안에 멈추는지 (사용자 확인 대기)
