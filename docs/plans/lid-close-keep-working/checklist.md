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
- [ ] **미확인 사항 검증**: `disablesleep=1` 상태에서 `pmset displaysleepnow` 가 동작하는지.
      동작하지 않으면 spec.md 의 Scope 결정을 재검토하고 사용자에게 보고한다.

## 1. 구현
- [ ] `Sources/MyMacTools/LidWorkManager.swift` 신규 — 상태 조회(`ioreg`) + 인증 실행(`NSAppleScript`)
- [ ] 인증 취소·실패 시 상태를 바꾸지 않는 경로 확인 (낙관적 갱신 금지)
- [ ] `L10n.Key` 에 신규 키 추가 (섹션 제목, 상태 2종, 버튼 2종, 주의사항 4줄, 종료 경고)
- [ ] `Resources/ko.lproj/Localizable.strings` 갱신
- [ ] `Resources/en.lproj/Localizable.strings` 갱신
- [ ] `Resources/ja.lproj/Localizable.strings` 갱신
- [ ] `ContentView` 에 구분선 + 신규 섹션(상태 · 주의사항 · 버튼) 추가
- [ ] `MyMacToolsApp` 에 종료 경고 다이얼로그 연결
- [ ] 앱 실행 시 `refreshFromSystem()` 으로 버튼 상태 복원

## 2. 검증
- [ ] 시작 → 인증 → `SleepDisabled=Yes` 확인
- [ ] 중지 → 인증 → `SleepDisabled=No` 확인
- [ ] 인증 취소 시 버튼 상태 유지되는지 확인
- [ ] 켜진 상태로 종료 시도 → 경고 다이얼로그 확인
- [ ] 강제 종료 후 재실행 → 버튼 ON 복원 확인
- [ ] 기존 "화면 끄고 작업" 회귀 확인 + 두 기능 동시 실행 확인
- [ ] 3개 언어 전환하며 신규 문자열 누락 없는지 확인
- [ ] 실제 덮개 닫기 테스트 — AC 연결, 30초, `pmset -g log` 에 `Clamshell Sleep` 신규 항목 없음

## 3. 마무리
- [ ] `./scripts/build-app.sh` 로 빌드, `/Applications` 에 재설치
- [ ] main 에 직접 커밋 후 즉시 `git push origin main` (CLAUDE.md 규약)
- [ ] checklist 의 미체크 항목이 남았으면 사유 메모
- [ ] spec.md / context.md 에 구현 중 바뀐 결정 반영
