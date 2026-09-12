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
