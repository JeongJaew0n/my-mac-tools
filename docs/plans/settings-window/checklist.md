# checklist — settings-window

`(확인)` 은 사용자가 직접 써보고 확인해준 것, `(실측)` 은 명령·캡처로 확인한 것이다.

## 1. 저장 계층
- [x] `Preferences` — **숨긴 것**을 `UserDefaults` 의 `hiddenTabs` 에 저장
- [x] `visibleTabs` 는 `Tab.allCases` 순서를 따른다
- [x] 마지막 하나는 끌 수 없다 (`canHide`)
- [x] 단위 검증 (실측 — 끄기·되돌리기·저장·복원·마지막 하나 보호 전부 통과)

## 2. 설정 창
- [x] SwiftUI `Settings` 씬 — 앱 메뉴 `설정…` 과 `⌘,` 가 자동으로 붙는다
- [x] Tool 마다 아이콘 + 이름 + 스위치
- [x] 마지막 하나는 토글이 잠기고 툴팁으로 이유를 알린다
- [x] 숨겨도 메뉴바에서는 쓸 수 있다는 안내 한 줄

## 3. 본창 반영
- [x] 탭바가 `preferences.visibleTabs` 만 그린다
- [x] `activeTab` — 고른 탭이 숨겨지면 남은 첫 번째를 그린다
- [x] `onChange` 로 저장된 `selectedTab` 도 고친다

## 4. 문자열·토큰
- [x] `L10n.Key` 3개, ko · en · ja (실측 — 각 3개)
- [x] `settingsWidth` 토큰을 `design/tokens.json` 에 추가

## 5. 검증 — 실제 앱에서
- [x] 앱 메뉴에 `설정…` 이 있다 (실측 — AX 로 메뉴 항목 확인)
- [x] `⌘,` 로 열린다 (실측 — keystroke 후 `MyMacTools 설정` 창 등장)
- [x] 설정 창 내용 (실측 — AX 트리에 제목·Tool 4개·체크박스 4개·안내 문구)
- [x] 토글을 끄면 `hiddenTabs` 에 저장된다 (실측 — `(cover)`)
- [x] 셋을 끄면 남은 하나의 체크박스가 **비활성**된다 (실측 — `enabled = false`)
- [x] 그 하나를 클릭해도 꺼지지 않는다 (실측 — 값이 1 로 유지)
- [x] 보던 탭을 숨기면 `selectedTab` 이 옮겨간다 (실측 — `lid` → `screenOff`)
- [x] 메뉴바는 영향받지 않는다 (`StatusItemController` 가 `Preferences` 를 참조하지 않는다)
- [x] 새 Tool 은 설정을 건드리지 않아도 보인다 (숨긴 것만 저장하므로)
- [ ] 탭이 실제로 사라지는 모습 — **눈으로는 미확인.** SwiftUI 로 직접 그린 탭바라
      접근성 트리에 자식이 노출되지 않아 AX 로 셀 수 없었다. `hiddenTabs` 저장과
      `selectedTab` 이동으로 간접 확인했다
- [ ] 세 언어 문구 (확인 — ko 만 눈으로 봤다)
