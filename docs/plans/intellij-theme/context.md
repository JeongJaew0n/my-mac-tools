# context — intellij-theme

## 원 요청 (2026-11-06)

사용자가 IntelliJ 에 적용된 skin 색을 뽑아 달라고 한 뒤 이어서 요청했다.

> 이거 색을 내가 조절해서 찍고 싶거던? 그래서 새 기능으로 인텔리제이 색 조정기능을 만들어주라.
>
> 1단계: 기능 화면에서 가장 많이 쓰이는거 배경색, 함수색, 타입색 이런거 쭉 나열하고, 길어지면
> 별도 상세 화면이나 더보기 화면 나오도록. 그리고 그거 색을 팔레트 눌러서 선택할 수 있게.
> 그리고 그거 '저장' 으로 하면 내부 저장소에 저장해두기. 그리고 그거 불러올 수 있게 하기.
>
> 2단계: 그거 '적용' 버튼 누르면 인텔리제이에 적용되게.
>
> 설계 구현 ㄱㄱ

## 실측 (이 맥, 2026-11-06)

- 깔린 IntelliJ: `/Applications/IntelliJ IDEA.app`, bundle id `com.jetbrains.intellij`,
  `product-info.json` 의 `version` 2025.2.6.3, `dataDirectoryName` `IntelliJIdea2025.2`.
- 설정 폴더 `~/Library/Application Support/JetBrains/IntelliJIdea2025.2/`
  - `options/laf.xml` → `<laf themeId="cmux-warm-light" />`
  - `options/colors.scheme.xml` → `<global_color_scheme name="cmux Warm Light" />`
  - `colors/` 폴더 없음 — 사용자가 IDE 안에서 고친 스킴 복사본이 없다.
- 지금 테마는 사용자가 직접 만든 플러그인 `plugins/cmux-warm-light/lib/cmux-warm-light.jar`.
  안에 `META-INF/plugin.xml`(`themeProvider`) · `theme/cmuxWarmLight.theme.json`(UI) ·
  `theme/cmuxWarmLight.xml`(에디터 스킴, `parent_scheme="Default"`, attribute 83개) 셋이 있다.
  → **jar 를 plugins 폴더에 두고 `laf.xml` 이 그 themeId 를 가리키면 적용된다** 는 경로가 이 맥에서
  이미 쓰이고 있다.
- 원본 테마의 hex 는 43종이고, **hex 하나가 뜻 하나** 다(같은 hex 가 서로 다른 뜻으로 쓰이지 않는다.
  `2B2B2B` 는 UI 글자와 에디터 글자, `E5DDCC` 는 UI 테두리와 에디터 tearline, `FCF7ED` 는 UI 에디터
  배경과 스킴 `TEXT` 배경 — 모두 같은 뜻). 그래서 hex 자리를 역할 이름으로 바꾼 템플릿이 성립한다.
- `~/Library/Application Support/JetBrains/IntelliJIdea2025.3/` 도 있으나 그 버전 앱은 없다(1월 이후 안 바뀜).
  설정 폴더는 폴더 목록이 아니라 **깔린 앱의 `dataDirectoryName`** 으로 고른다.

## 기각한 대안

- **사용자 플러그인(`cmux-warm-light.jar`)을 덮어쓰기** — 남의(사용자가 손으로 만든) 파일을 앱이
  고치게 된다. 되돌리려면 백업이 필수가 되고, 사용자가 그 플러그인을 다시 고치면 서로 덮는다.
  대신 **이 앱 전용 테마 플러그인**을 따로 두고 `laf.xml` 의 가리킴만 바꾼다. 되돌리기는 가리킴을
  원래대로 돌리면 끝이다.
- **`colors/*.icls` 로 에디터 스킴만 쓰기** — 에디터 색은 되지만 패널·트리·탭 같은 UI 색(요청의
  "배경색")은 테마(`*.theme.json`)로만 바꿀 수 있다. 둘 다 바꾸려면 테마 플러그인이 필요하다.
- **IntelliJ 를 켜둔 채 파일만 쓰기** — IntelliJ 는 설정을 메모리에 들고 있다가 종료할 때 다시 쓴다.
  켜둔 채 `laf.xml` 을 바꾸면 종료할 때 원래 값으로 덮일 수 있고, 재시작 전까지 보이지도 않는다.
  그래서 **켜져 있으면 종료 → 쓰기 → 다시 열기** 로 한다.
- **IntelliJ 를 강제 종료** — 저장 안 된 편집·종료 확인 창을 무시하게 된다. 정상 종료(`terminate`)만
  보내고, 정해진 시간 안에 안 꺼지면 쓰지 않고 실패로 알린다.
- **테마 이름을 프리셋 이름으로** — 프리셋을 바꿀 때마다 themeId 가 바뀌어 이전 플러그인이 쌓인다.
  이름은 `MyMacTools` 하나로 고정하고 내용만 바꾼다.
