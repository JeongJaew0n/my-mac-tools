# checklist — tabbed-window

> 작업 진행하면서 AI 가 순차적으로 체크. `[x]` 로 표시한 항목은 완료된 것으로 간주.

## 0. 준비
- [ ] spec.md / context.md 다시 읽고 어긋난 곳 없는지 확인
- [ ] 브랜치 생성 없음 — CLAUDE.md 규약대로 main 직접 작업

## 1. 구현
- [ ] `Tab` enum (`screenOff`, `lid`) + `L10n.Key` 탭 이름 2개
- [ ] `ko/en/ja.lproj` 에 탭 이름 추가, 키 집합 일치 검증
- [ ] 탭바 뷰 — 상태 점 + 이름 + 선택 표시. `Circle().fill()` 관용구 재사용
- [ ] `ContentView` 를 탭 컨테이너로 변경. 기존 묶음을 `screenOffTab` / `lidTab` 으로 분리
- [ ] 본문 `Text("MyMacTools")` 제거, 창 타이틀 확인
- [ ] 탭 선택 `UserDefaults` 저장/복원
- [ ] 두 탭 높이를 실측해 고정 높이 결정

## 2. 검증
- [ ] 탭 전환 시 창 크기가 변하지 않는다
- [ ] 상태 점이 각 기능의 실제 동작을 따라간다 (한쪽을 켜고 다른 탭에서 확인)
- [ ] 앱 재실행 시 마지막 탭 복원
- [ ] 창 타이틀바에 "MyMacTools" 표시
- [ ] "끝나면 Mac잠자기 모드" 잠김 + 이유 문구가 A 탭에서 그대로 보인다
- [ ] 기존 두 기능 회귀 없음 (화면 끄기 세션, 덮개 토글·유지 시간·종료 원복)
- [ ] 3개 언어 전환하며 탭 이름 누락 없는지 확인

## 3. 마무리
- [ ] `./scripts/build-app.sh` 빌드, `/Applications` 재설치
- [ ] main 에 직접 커밋 후 즉시 push (CLAUDE.md 규약)
- [ ] README 의 UI 설명이 어긋나면 갱신
- [ ] spec.md / context.md 에 구현 중 바뀐 결정 반영
