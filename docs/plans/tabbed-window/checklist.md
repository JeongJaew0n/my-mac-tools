# checklist — tabbed-window

> 작업 진행하면서 AI 가 순차적으로 체크. `[x]` 로 표시한 항목은 완료된 것으로 간주.

## 0. 준비
- [x] spec.md / context.md 확인
- [x] 브랜치 생성 없음 — CLAUDE.md 규약대로 main 직접 작업

## 1. 구현
- [x] `Tab` enum + `L10n.Key` 탭 이름 2개. 중복이 된 `lid.title` 은 제거
- [x] `ko/en/ja.lproj` 탭 이름 추가, 키 집합 38개 일치 검증
- [x] 탭바 뷰 — `Circle().fill()` 관용구 재사용, 선택 배경 직접 그림
- [x] `ContentView` 탭 컨테이너화, `screenOffTab` / `lidTab` 분리
- [x] 본문 제목 제거. 타이틀바에 `MyMacTools` 나오는 것 확인
- [x] `@AppStorage("selectedTab")` 로 저장/복원
- [x] 실측 325 / 368 → 창 높이 380 고정 + `ScrollView`

## 2. 검증
- [x] 탭 전환 시 창 크기 동일 — 두 탭 모두 320x412 실측
- [ ] 상태 점이 각 기능의 실제 동작을 따라간다 (한쪽을 켜고 다른 탭에서 확인)
- [ ] 앱 재실행 시 마지막 탭 복원
- [x] 창 타이틀바에 `MyMacTools` 표시 확인
- [ ] "끝나면 Mac잠자기 모드" 잠김 + 이유 문구가 A 탭에서 그대로 보인다
- [ ] 기존 두 기능 회귀 없음 (화면 끄기 세션, 덮개 토글·유지 시간·종료 원복)
- [x] 설치된 번들에서 3개 언어 탭 이름 해석 확인, `lid.title` 완전 제거 확인

## 3. 마무리
- [ ] `./scripts/build-app.sh` 빌드, `/Applications` 재설치
- [ ] main 에 직접 커밋 후 즉시 push (CLAUDE.md 규약)
- [ ] README 의 UI 설명이 어긋나면 갱신
- [ ] spec.md / context.md 에 구현 중 바뀐 결정 반영
