# spec — intellij-theme

## 목표

여덟째 Tool **IntelliJ 색**. IntelliJ 의 UI·에디터 색을 이 앱에서 골라 저장하고, 누르면 IntelliJ 에
적용한다.

1. **고르기·저장·불러오기 (1단계)** — 자주 쓰는 색을 먼저 나열하고 나머지는 '더 보기' 에 둔다.
   색 견본을 누르면 macOS 색 패널이 열린다. 이름을 붙여 **프리셋** 으로 저장하고, 불러온다.
2. **적용 (2단계)** — 지금 팔레트로 테마 플러그인을 만들어 IntelliJ 설정 폴더에 넣고 그 테마를
   고른다. IntelliJ 가 켜져 있으면 종료하고 쓴 뒤 다시 연다.

## 확정한 결정

| 결정 축 | 확정 내용 | 근거 |
|---|---|---|
| 배치 | **새 Tool** `intellijTheme` (여덟째 탭), `IntelliJThemeManager` | 기존 Tool 어디에도 속하지 않는다 |
| 색의 단위 | **색 역할** 43개. 각 역할이 테마 JSON·스킴 XML 의 여러 자리에 들어간다(`키워드` → `DEFAULT_KEYWORD` · `KOTLIN_KEYWORD` …) | 원본 테마에서 hex 하나 = 뜻 하나였다(context.md). 사용자가 83개 attribute 를 하나씩 고를 일은 없다 |
| 기본값 | 지금 쓰는 **cmux Warm Light** 의 값 | 사용자가 "이거 색을 조절해서" 라고 했다 — 출발점이 지금 테마다 |
| 자주 쓰는 색 (화면에 바로) | 에디터 배경 · 패널 배경 · 글자 · 강조색 · 키워드 · 함수 · 타입 · 문자열 · 숫자·상수 · 주석 (10) | 요청에 든 "배경색·함수색·타입색" + 코드에서 눈에 가장 많이 보이는 것 |
| 나머지 | **더 보기** 를 펼치면 화면 · 에디터 · 코드 · Kotlin 네 묶음으로 33개 | 320pt 창에 43줄은 길다. 다른 Tool 의 "센서 전체" 와 같은 펼침 |
| 색 고르기 | 줄마다 SwiftUI `ColorPicker`(불투명) — 누르면 macOS 색 패널 | 요청의 "팔레트 눌러서 선택". hex 는 옆에 글자로 보인다 |
| 색 공간 | sRGB 로 바꿔 `RRGGBB` 로 저장 | IntelliJ 테마·스킴이 sRGB hex 다 |
| 편집 중 값 | **팔레트** — 바꿀 때마다 `UserDefaults` 에 저장. 앱을 껐다 켜도 남는다 | 저장 버튼을 안 눌렀다고 고른 색이 사라지면 안 된다 |
| 저장 | **프리셋** = 이름 + 팔레트. `UserDefaults` 에 JSON. 같은 이름이면 버튼이 '덮어쓰기' 로 바뀐다 | 요청의 "내부 저장소". 덮어쓰는지를 누르기 전에 알 수 있어야 한다 |
| 불러오기 | 메뉴: `기본값 (cmux Warm Light)` + 저장한 프리셋들, 그리고 '삭제' 하위 메뉴 | 지운 것을 되살릴 길은 없지만 프리셋은 이 앱 안의 값이라 확인 창까지 두지 않는다 |
| 적용 대상 | `NSWorkspace` 로 `com.jetbrains.intellij` → 없으면 `com.jetbrains.intellij.ce`. 설정 폴더는 앱의 `product-info.json` `dataDirectoryName` | 설정 폴더가 여러 버전 남아 있다(context.md). 실제 앱 기준이어야 한다 |
| 적용 방식 | 이 앱 전용 플러그인 `plugins/mymactools-theme/lib/mymactools-theme.jar` 를 만들고 `laf.xml` themeId · `colors.scheme.xml` 스킴 이름을 `MyMacTools` 로 바꾼다 | 사용자 플러그인을 건드리지 않는다(context.md 기각 대안) |
| jar 만들기 | 임시 폴더에 파일을 쓰고 `/usr/bin/zip` | Foundation 에 zip API 가 없다. `zip` 은 macOS 기본 |
| 라이트·다크 | 에디터 배경의 밝기(상대 휘도 < 0.5)로 `dark` 와 스킴 부모(`Default`/`Darcula`)를 고른다 | 어두운 배경을 골랐는데 IntelliJ 기본 바탕이 라이트로 남으면 안 고른 색이 튄다 **[가정 — 다크 팔레트로 실제 확인 안 함]** |
| IntelliJ 가 켜져 있을 때 | 확인 창 → 정상 종료(`terminate`) → 꺼질 때까지 최대 60초 → 쓰기 → 다시 열기. 안 꺼지면 **아무것도 쓰지 않고** 실패 | 켜둔 채 쓰면 종료할 때 덮인다(context.md). 강제 종료하지 않는다 |
| 꺼져 있을 때 | 쓰기만 하고 열지 않는다 | 사용자가 띄우지 않은 앱을 띄우지 않는다 |
| 백업 | 처음 적용할 때 `laf.xml` · `colors.scheme.xml` 을 `~/Library/Application Support/MyMacTools/intellij-backup/<dataDir>/<시각>/` 에 복사 | 남의 설정 파일을 고치기 전에 원본을 남긴다 |
| 되돌리기 | 적용 전 themeId·스킴 이름을 기억해 두고 **원래 테마로 되돌리기** 가 그 둘을 다시 쓴다(같은 종료·재실행 흐름). 플러그인은 지우지 않는다 | 가리킴만 돌리면 원래 상태다. 남은 플러그인은 고르지 않으면 아무 일도 안 한다 |
| XML 고치기 | `XMLDocument` 로 해당 요소의 속성만 바꾼다. 없으면 만든다 | 그 파일에 다른 옵션이 있어도 보존한다 |
| API | `intellij.info` (읽기) — 대상·지금 테마·팔레트·프리셋 이름 | 다른 Tool 과 같은 원칙. **적용은 API 로 열지 않는다** — 다른 앱을 끄는 일이라 사람이 눌러야 한다 |
| 탭 점 | 없음 (`isRunning` false) | 계속 도는 것이 없다 |

## 화면 (초안)

```
 대상  IntelliJ IDEA 2025.2.6.3
       지금 테마: cmux-warm-light

 자주 쓰는 색
 에디터 배경     #FCF7ED  [■]
 패널 배경       #F8F2E8  [■]
 …
 ▸ 더 보기 (33)
     화면 / 에디터 / 코드 / Kotlin

 프리셋
 [이름          ] [저장]  [불러오기 ▾]

 [ IntelliJ 에 적용 ]
 IntelliJ 가 켜져 있으면 종료하고 적용한 뒤 다시 엽니다.
 원래 테마로 되돌리기
```

## 완료 조건

- 색을 바꾸면 hex 가 바뀌고, 앱을 다시 켜도 남는다
- 프리셋 저장 → 다른 색으로 바꿈 → 불러오기 하면 저장한 값으로 돌아온다
- 적용하면 플러그인 jar 가 생기고 `laf.xml` · `colors.scheme.xml` 이 `MyMacTools` 를 가리킨다.
  jar 안의 JSON·XML 이 IntelliJ 가 읽는 형식이다(원본 플러그인과 같은 구조)
- 되돌리기 하면 두 파일이 원래 값으로 돌아간다
- IntelliJ 를 다시 켰을 때 색이 바뀌어 있다 — **사용자 확인 필요** (작업 중인 IntelliJ 를 이 세션이
  임의로 끄지 않는다)
- ko/en/ja 문자열, README · api.md · 용어집 · CLAUDE.md 구조 갱신
