# my-mac-tools

macOS 유틸리티 앱 (MyMacTools) — SwiftPM 기반 executable + 수동 `.app` 번들링.

## 구조

```
Sources/MyMacTools/
├── MyMacToolsApp.swift      앱 진입점
├── ContentView.swift        탭 전환 + 각 Tool 의 화면. `enum Tab` 이 Tool 의 UI 표현이다
├── BlackWorkManager.swift   Tool: 잠자기 방지 (caffeinate, ScreenMode/ScreenPhase)
├── LidWorkManager.swift     Tool: 덮개 닫아도 작업 (pmset disablesleep)
├── ScreenCoverManager.swift Tool: 화면 가리기 (+ CoverView, Shortcut, ShortcutRecorder)
├── LocalhostManager.swift   Tool: 로컬호스트 (libproc 으로 LISTEN 소켓)
├── CaffeinateScanner.swift  잠자기 방지 안의 카페인 목록
├── ProcessSnapshot.swift    프로세스 열거·이름 해석 (위 둘이 함께 쓴다)
├── APIServer.swift          에이전트용 유닉스 소켓 서버
├── APIHandler.swift         API 메서드 처리 (docs/api.md 와 함께 고친다)
├── StatusItemController.swift  메뉴바 항목
├── Actions.swift            메뉴바와 창이 함께 쓰는 동작
├── SettingsView.swift       설정 창 (SwiftUI `Settings` 씬 → `⌘,`)
├── Preferences.swift        어떤 Tool 을 탭으로 보일지 (숨긴 것만 저장)
├── Localization.swift       L10n.Key 와 언어 전환
└── Design.swift             디자인 토큰 — **생성물이다. 직접 고치지 않는다**
Resources/                   Info.plist, 아이콘, ko/en/ja lproj
design/                      디자인 토큰 출처 (tokens.json, themes/)
scripts/                     build-app.sh, install-sudoers.sh, build-tokens.py,
                             mymactools (API 클라이언트)
docs/                        계획·용어·트러블슈팅 (아래 docs 규칙 참고)
```

Tool 을 추가하면 `enum Tab` 에 case 를 넣고 전용 Manager 를 만든다.
관리자 타입은 `<Tool>Manager` 로 이름을 맞춘다. 가장 오래된 둘만 `<Tool>WorkManager`
인데, 그것을 규칙으로 적어두면 코드와 어긋난다 — `ScreenCoverManager` ·
`LocalhostManager` 가 이미 `Work` 를 쓰지 않는다.

## 프로젝트 규칙 (my-app-init, 2026-09-15 확정)

### git
- author: `HeLLo2 <popt0@naver.com>` — `git config --local` 로 설정돼 있다. 커밋 전 `git config user.email` 로 확인한다.
- 커밋·푸시: **전자동**. 작업 단위가 끝나면 사용자에게 확인받지 않고 `git commit` → `git push origin main` 한다.
  (2026-09-09 사용자 지시, 2026-09-15 재확인 — 사용자가 준 지속적 승인이다)
- 브랜치: **main 고정**. 브랜치를 새로 만들지 않고 `main` 에서 직접 작업한다. PR 은 만들지 않는다.
- **예외 — 리뷰는 자동 커밋·푸시하지 않는다.** 코드리뷰·리뷰 문서, 그리고 리뷰에서
  나온 수정은 위 정책이 '전자동'이어도 사람이 읽고 판단한 뒤에 커밋한다.
  리뷰는 사실이 아니라 의견이고, 틀린 의견이 먼저 기록에 박히면 되돌리기 어렵다.

### docs
- 여러 단계짜리 작업은 코드를 건드리기 전에 `docs/plans/<slug>/` 에 계획을 먼저 쓴다.
- 원인 찾는 데 시간이 걸린 오류는 `docs/troubleshootings/` 에 남긴다.
  원인이 라이브러리·런타임·OS 에 있으면 `reusable/`, 이 프로젝트의 코드·설정에
  있으면 `project-specific/`.
- 도메인 용어를 새로 만들거나 이름을 바꾸면 `docs/glossary/README.md` 를 먼저 고치고
  코드를 그 이름에 맞춘다. 코드만 바꾸면 용어집이 거짓말이 된다.

### 디자인 수치
- `Sources/MyMacTools/Design.swift` 는 **생성물**이다. 고치면 다음 생성에서 사라진다.
  값을 바꾸려면 `design/tokens.json` 을 고치고 `scripts/build-tokens.py` 를 돌린다.
- 새 수치가 필요하면 **역할 이름**을 먼저 정한다 (`listItem`, `labelGap`). 제품 이름
  (`caffeine`, `port`)을 `semantic` 층에 넣지 않는다 — 그건 역할 이름을 잘못 고른 것이다.
- 자세한 것은 `docs/design-tokens.md`.

### 설계
- 기능 묶음 단위는 **Tool** 이다. 새 기능은 기존 Tool 에 넣을지 새 Tool 을 만들지
  먼저 정하고 시작한다. 코드의 디렉터리·타입 이름도 이 말을 쓴다.

## 빌드 & 설치

```bash
./scripts/build-app.sh              # .build/MyMacTools.app 생성 (swift build -c release + 번들 조립)
cp -R .build/MyMacTools.app /Applications/
```

`scripts/build-app.sh` 의 `APP_NAME`, `Resources/Info.plist` 의 `CFBundleExecutable`/`CFBundleName`,
그리고 Package.swift 의 타깃명이 서로 맞아야 번들이 실행된다. 앱 이름을 바꿀 때 세 곳을 함께 수정한다.

서명은 ad-hoc(linker-signed) 이다. 로컬 실행에는 문제없지만 다른 맥으로 배포하면 Gatekeeper 경고가 뜬다.
