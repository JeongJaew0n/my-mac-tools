# context — tabbed-window

## 사용자의 원 요청
> "기능을 분리하고 상단탭으로 선택할 수 있게 하는 거 설계 해줘."

## 왜 이걸 지금 하는가
2026-09-12~13 에 "덮개 닫아도 작업 진행" 기능이 추가되면서 창이 한 화면에 두 기능을
세로로 쌓게 됐다. 덮개 기능은 상태 표시 · 유지 시간 · 주의사항 4줄 · 버튼 · 남은 시간까지
차지해 창이 320x569 까지 길어졌다. 기능이 더 늘면 계속 길어지는 구조다.

## 결정된 방향
상단 탭으로 한 번에 한 기능만 보이게 한다. 단, 두 기능 모두 시스템 상태를 바꾸므로
**동작 여부만은 어느 탭에 있든 보이게** 한다.

## 기각된 대안
- **SwiftUI `TabView` 사용** — macOS 기본 탭 모양을 얻지만 `.tabItem` 이 이미지를
  template 으로 렌더링해 상태 점의 녹색이 죽을 수 있다. 상태 가시성을 먼저 확정했으므로
  그것을 지키지 못하는 수단은 쓸 수 없다.
- **탭 위에 상시 요약 줄** — 정보는 가장 많지만 탭 안의 상태 표시와 중복되고 세로 공간을
  더 쓴다. 창 길이를 줄이려는 목적과 어긋난다.
- **상태 표시 없음** — 가장 깔끔하지만, 덮개 기능을 켜둔 채 다른 탭에 머물면
  "맥이 잠들지 않는다"는 사실이 화면 어디에도 없게 된다.
- **탭마다 창 크기 자동 조절** — `.windowResizability(.contentSize)` 그대로 두면
  전환할 때마다 창이 튄다.
- **실행 중인 기능의 탭을 열기** — 강제 종료 후 재실행 시 유용하지만 열 때마다 다른 탭이
  나와 예측성이 떨어진다.

## 제약 / 합의 사항
- 매니저 로직은 건드리지 않는다. 이번 작업은 순수 UI 재배치다.
- 기존 상태 표시 관용구(`Circle().fill(isRunning ? .green : .gray)`)를 탭 라벨에서 재사용한다.
- 탭 선택 저장은 `L10n` 의 `UserDefaults` 선례를 따른다.

## 관련 자료
- `Sources/MyMacTools/ContentView.swift` — 현재 한 `VStack` 에 두 기능이 들어 있다.
  `statusRow`, `settings`, `progress`, `lidSection`, `cautions` 로 이미 계산 프로퍼티가
  나뉘어 있어 탭 하위 뷰로 옮기기 쉽다.
- `Sources/MyMacTools/MyMacToolsApp.swift` — `WindowGroup`, `.windowResizability(.contentSize)`,
  언어 `CommandMenu`, 종료 가로채기 `AppDelegate`.
- `Sources/MyMacTools/Localization.swift` — `UserDefaults` 저장 선례(`appLanguage`)와
  `L10n.Key` 추가 방식.
- `docs/TROUBLESHOOTING.md` — "화면에 보이는 모든 값은 커널에서 파생돼야 한다" 원칙.
  탭 라벨의 상태 점도 매니저의 `isRunning` 을 그대로 따라가야 하며 별도로 기억하지 않는다.
