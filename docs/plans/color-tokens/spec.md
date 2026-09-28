# spec — color-tokens

## 목표
색을 디자인 토큰으로 옮긴다. 팔레트는 Figma 색 조합 **"폭풍우가 몰아치는 아침"(Stormy
morning)** 이다. 지금까지 코드는 `.secondary` · `.quaternary` · `Color.primary.opacity(…)`
같은 시스템 색을 직접 썼고, 색은 토큰 밖에 있었다 (`docs/design-tokens.md`).

## 팔레트

Figma 원본 네 색 — 팔레트 이미지에 적힌 표기값이다 (픽셀을 읽으면 색공간 변환 탓에 값이 달라진다).

| 원시 이름 | 값 | 출처 |
|---|---|---|
| `slate700` | `#384959` | Figma 원본 |
| `slate500` | `#6A89A7` | Figma 원본 |
| `sky400` | `#88BDF2` | Figma 원본 |
| `sky200` | `#BDDDFC` | Figma 원본 |
| `slate600` | `#54728F` | **파생.** `slate500` 과 같은 색상각, 명도만 낮춤 |
| `slate400` | `#809AB4` | **파생.** `slate500` 과 같은 색상각, 명도만 높임 |
| `white` | `#FFFFFF` | |
| `charcoal` | `#1E1E1E` | 다크 창 바탕과 같은 값 |

## 역할

| 역할 | 라이트 | 다크 | 어디에 |
|---|---|---|---|
| `textSecondary` | `slate600` | `slate400` | 캡션·단위·설명·쉬는 탭 아이콘 (`.secondary` 대체) |
| `accent` | `slate700` | `sky400` | 기본 동작 버튼, 토글, 초점 |
| `onAccent` | `white` | `charcoal` | 강조색 위 글자 |
| `selection` | `sky200` | `slate700` | 선택된 탭 바탕, 칩 바탕 (`.quaternary`, `primary 10%` 대체) |
| `onSelection` | `slate700` | `sky200` | 선택된 탭 글자 |
| `surface` | `sky200` 32% | `slate700` 45% | 목록 항목·카드 면 (`primary 5%` 대체) |
| `statusRunning` | 시스템 green | 시스템 green | 돌고 있음 |
| `statusIdle` | 시스템 gray | 시스템 gray | 꺼짐 |
| `statusWarning` | 시스템 orange | 시스템 orange | 카운트다운·주의 |
| `statusError` | 시스템 red | 시스템 red | 실패·오류 |

**상태색은 팔레트에 넣지 않는다.** 색 자체가 뜻이라 팔레트를 바꿔도 달라지면 안 된다.
토큰에는 넣되 값은 시스템 색을 가리킨다 — 모든 색이 한 이름 체계를 지나게 하려는 것이다.

## 파생값을 만든 이유 — 실측

제안 단계에서는 `#6A89A7` 을 다크 보조 글자로 그대로 쓰려 했다. 목록 **면** 위에서 재니
기준에 못 미쳤다.

```
창 바탕 (NSColor.windowBackgroundColor 실측)  light #FFFFFF  dark #1E1E1E
surface  = sky200 32% on #FFFFFF → #EAF4FE / slate700 45% on #1E1E1E → #2A3139

#6A89A7 on 다크 면 #2A3139   3.60  미달
#597897 on 라이트 면 #EAF4FE 4.14  미달   (제안 문서의 라이트 파생값)

→ #54728F  바탕 5.02 / 면 4.51
→ #809AB4  바탕 5.72 / 면 4.51
```

## 명암비 (WCAG, 기준: 글자 4.5 · 모양 3)

| 쌍 | 라이트 | 다크 |
|---|---|---|
| 보조 글자 / 바탕 | 5.02 | 5.72 |
| 보조 글자 / 면 | 4.51 | 4.51 |
| 강조색 위 글자 / 강조색 | 9.27 | 8.42 |
| 선택 글자 / 선택 바탕 | 6.58 | 6.58 |
| 기본 글자 / 칩 | 14.91 | 9.27 |
| 강조색 / 바탕 (모양) | 9.27 | 8.42 |

**보조 글자를 칩 위에 쓰지 않는다.** 칩 위에서는 3.57 / 3.18 이다. 지금 코드에서 칩 글자는
기본 글자색이라 해당하지 않는다.

## 생성기

`scripts/build-tokens.py` 가 색을 알게 한다.

- 색 토큰 값: `"#RRGGBB"`(원시) / `{"light": …, "dark": …}` / `{"system": "green"}`
- 한쪽 값은 참조 `"{primitive.color.x}"` 또는 `{"ref": "{…}", "alpha": 0.32}`
- Swift: `Design.Color.x` (SwiftUI) 와 `Design.AppKitColor.x` (NSColor) — **이름은 토큰과
  같다.** 메뉴바처럼 AppKit 으로 그리는 곳 때문에 둘 다 낸다
- 라이트·다크는 `NSColor(name:dynamicProvider:)` 로 **그리는 순간의 appearance** 를 따른다
- CSS: `:root` 에 라이트, `prefers-color-scheme: dark` 에 다크. 시스템 색은 실측 근사값

## 적용 범위

- `ContentView` · `SettingsView` 의 시스템 색 직접 사용을 역할로 바꾼다
- 기본 동작 버튼은 전용 스타일로 `accent`·`onAccent` 를 쓴다. macOS 기본 버튼은 강조색 위에
  흰 글자를 그려서, 다크의 밝은 강조색(`sky400`) 위에서 1.98 로 읽히지 않는다
- 루트에 `.tint(accent)` — 토글·초점 링
- 메뉴바 초록 점 → `AppKitColor.statusRunning`

## 범위 밖

- **화면 가리기 오버레이(`CoverView`)** — 사진 위 `regularMaterial` 판이다. 고정색보다 시스템
  보조색의 투명도 적응이 낫고, 앱 창의 일부가 아니다
- 시스템 경고창(`NSAlert`) · 메뉴(`NSMenu`) — 시스템이 그린다
- 글자 크기·굵기 토큰

## 잃는 것

- 시스템 설정의 **대비 증가**와 **강조 색상**을 더는 따르지 않는다
