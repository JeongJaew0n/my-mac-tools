# checklist — color-tokens

- [x] 팔레트 확정, 파생값 명암비 실측 — 창 바탕은 `NSColor.windowBackgroundColor` 로 직접 읽음
- [x] `build-tokens.py` 색 지원 (라이트/다크, 알파, 시스템 색) — 잘못된 알파·시스템 색·참조 거절 확인
- [x] `tokens.json` 에 `primitive.color` · `semantic.color`, 버튼 여백 `inset.buttonX/Y`
- [x] 생성물 `Design.swift` · `tokens.css` 갱신, `--check` 통과, `--theme normalized` 도 생성됨
- [x] 숫자 토큰 출력이 바뀌지 않았는지 — 차이는 import·머리 주석뿐
- [x] `ContentView` · `SettingsView` 적용, 루트 `.tint(accent)`
- [x] 기본 동작 버튼 `PrimaryButtonStyle`
- [x] 메뉴바 점 `AppKitColor.statusRunning`
- [x] 빌드·서명·설치
- [x] 라이트·다크 렌더로 확인 — 잠자기 방지·로컬호스트 탭 (화면 밖 렌더, `probes/`)
- [x] 문서: `design-tokens.md` · `DESIGN.md` §4 · `CLAUDE.md`
- [ ] 덮어도 작업 · 화면 가리기 탭, 설정 창 — 렌더로 보지 않음
- [ ] 실제 다크 모드에서 사람 눈으로 확인
