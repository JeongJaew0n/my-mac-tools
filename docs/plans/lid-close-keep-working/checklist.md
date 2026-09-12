# checklist — lid-close-keep-working

> 작업 진행하면서 AI 가 순차적으로 체크. `[x]` 로 표시한 항목은 완료된 것으로 간주.
> 새 항목이 발견되면 적절한 단계에 추가하고 체크리스트를 유지한다.

## 0. 준비
- [ ] spec.md / context.md 다시 읽고 어긋난 곳 없는지 확인
- [ ] 임시 LaunchDaemon 제거 (사용자가 일반 터미널에서 직접 실행 — sudo 필요)
      ```
      sudo launchctl bootout system/local.clamshell-awake
      sudo rm -f /Library/LaunchDaemons/local.clamshell-awake.plist \
                 /usr/local/bin/clamshell-awake.sh /var/log/clamshell-awake.err
      sudo pmset -a disablesleep 0
      ```
- [ ] 제거 확인: `ioreg -n IOPMrootDomain -r -d 1 | grep SleepDisabled` → `No`
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
- [ ] `Sources/MyMacTools/LidWorkManager.swift` 신규 — 상태 조회(`ioreg`) + 인증 실행(`NSAppleScript`)
- [ ] 인증 취소·실패 시 상태를 바꾸지 않는 경로 확인 (낙관적 갱신 금지)
- [ ] `L10n.Key` 에 신규 키 추가 (섹션 제목, 상태 2종, 버튼 2종, 주의사항 4줄, 종료 경고)
- [ ] `Resources/ko.lproj/Localizable.strings` 갱신
- [ ] `Resources/en.lproj/Localizable.strings` 갱신
- [ ] `Resources/ja.lproj/Localizable.strings` 갱신
- [ ] `ContentView` 에 구분선 + 신규 섹션(상태 · 주의사항 · 버튼) 추가
- [ ] B 가 ON 이면 A 의 "끝나면 잠자기" 토글 비활성화 (C2 대응)
- [ ] `MyMacToolsApp` 에 종료 경고 다이얼로그 연결
- [ ] 앱 실행 시 `refreshFromSystem()` 으로 버튼 상태 복원

## 2. 검증
- [ ] 시작 → 인증 → `SleepDisabled=Yes` 확인
- [ ] 중지 → 인증 → `SleepDisabled=No` 확인
- [ ] 인증 취소 시 버튼 상태 유지되는지 확인
- [ ] 켜진 상태로 종료 시도 → 경고 다이얼로그 확인
- [ ] 강제 종료 후 재실행 → 버튼 ON 복원 확인
- [ ] Phase 2 상태 조합 매트릭스 4종 + 순서 의존성 (test-plan.md 2-1)
- [ ] C4 — A 가 화면을 끈 상태에서 B 의 인증 다이얼로그가 블랭킹되지 않는지 (test-plan.md 2-2)
- [ ] C5 — A 만 중지했을 때 B 가 남는 것이 UI 에서 명확한지 (test-plan.md 2-3)
- [ ] 3개 언어 전환하며 신규 문자열 누락 없는지 확인
- [ ] 실제 덮개 닫기 테스트 — AC 연결, 30초, `pmset -g log` 에 `Clamshell Sleep` 신규 항목 없음

## 3. 마무리
- [ ] `./scripts/build-app.sh` 로 빌드, `/Applications` 에 재설치
- [ ] main 에 직접 커밋 후 즉시 `git push origin main` (CLAUDE.md 규약)
- [ ] checklist 의 미체크 항목이 남았으면 사유 메모
- [ ] spec.md / context.md 에 구현 중 바뀐 결정 반영
