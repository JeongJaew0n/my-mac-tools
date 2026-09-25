# checklist — tool-defaults + 설정 메뉴 분리

`(확인)` 은 사용자가 직접 써보고 확인해준 것, `(실측)` 은 명령·캡처로 확인한 것이다.

## 1. 설정 메뉴 분리
- [x] 메뉴 막대에 `설정` 독립 항목 (실측 — `Apple, MyMacTools, 파일, 편집, 보기, 설정, 언어, 윈도우, 도움말`)
- [x] 앱 메뉴에서 `설정…` 제거 (실측 — 항목 목록에 없음)
- [x] 메뉴 항목으로 열린다 (실측 — 창 `설정` 등장)
- [x] `⌘,` 로 열린다 (실측 — `AXMenuItemCmdChar = ,`, 실제 keystroke 로 창 등장)

### 막혔던 것 — `Settings` 씬을 버린 이유
- [x] `CommandGroup(replacing: .appSettings) { }` 로는 **앱 메뉴 항목이 안 지워진다**
      (실측 — 넣고 빌드해도 `설정…` 이 그대로 남았다). `Settings` 씬이 있는 한 그 항목이
      따라붙는다. 그래서 일반 `Window` 씬으로 바꾸고 여는 것은 `설정` 메뉴가 맡게 했다

## 2. 기본값 저장·되돌리기
- [x] `ToolDefaults` — `Codable` 스냅숏을 `UserDefaults` 에 JSON 으로
- [x] `BlackWorkManager` · `LidWorkManager` 의 `init` 이 저장된 기본값으로 시작
- [x] `saveAsDefault()` · `restoreDefault()` · `matchesDefault`
- [x] 두 탭에 버튼 줄 + 설명 한 줄. 기본값과 같으면 둘 다 잠긴다
- [x] 문구 5개 × 3언어 (실측 — 각 5개)

## 3. 검증
- [x] 저장 전 `matchesDefault = true` (저장된 게 없으면 내장값과 같다)
- [x] 값을 바꾸면 `false`, 저장하면 다시 `true`
- [x] **새 인스턴스가 저장한 값으로 시작** (실측 — 2시 30분·keepOn·10초·잠자기 켬)
- [x] 되돌리기가 저장된 기본값으로 복원
- [x] 덮어도 작업도 같은 흐름 (실측 — 3시 20분 저장·복원)
- [x] **실제 앱**이 저장된 기본값으로 시작 (실측 — `UserDefaults` 에 직접 넣고 재시작,
      API `sleep.get` 이 그 값을 반환)
- [x] 기본값을 지우면 내장값으로 돌아간다 (실측 — 0시 0분·system·5초·끔)
- [ ] 버튼이 화면에 보이고 눌리는 모습 — **눈으로는 미확인.** SwiftUI 뷰가 접근성
      트리에 자식을 노출하지 않아 AX 로 찾을 수 없고, 화면 캡처는 권한이 없다.
      저장·복원 경로는 위에서 끝까지 확인했다
- [ ] 세 언어 문구 (확인 — ko 만 봤다)
