# 앱 하나만 다크 모드로 띄워 캡처하려 했는데 라이트로 뜬다

## 환경

- macOS 26 (Darwin 25.6.0), Apple Silicon
- SwiftUI 앱 (`WindowGroup`), ad-hoc 서명

## 증상

색 토큰의 다크 값을 눈으로 확인하려고 앱을 다크로 띄워 캡처하려 했다. 시스템 전체를
다크로 바꾸면 사용자 화면이 통째로 바뀌므로 앱 하나만 바꾸고 싶었다.

```bash
open -a MyMacTools --args -AppleInterfaceStyle Dark
```

창은 뜨지만 **라이트로 그려진다.** 오류도 없다.

## 원인

`AppleInterfaceStyle` 을 실행 인자로 넣어도 이 환경의 앱 appearance 에 반영되지 않았다.
[미정] 정확히 어느 버전부터인지, AppKit 이 이 키를 인자 도메인에서 읽지 않게 된 것인지는
확인하지 않았다.

## 해결

**실제 뷰를 화면 밖에서 그린다.** 창의 `appearance` 를 강제하면 다이내믹 색
(`NSColor(name:dynamicProvider:)`)이 그리는 순간 그 appearance 로 판정되므로, 다크 값까지
그대로 확인된다.

```swift
let host = NSHostingView(rootView: ContentView(...).frame(width: 380, height: 520))
let window = NSWindow(contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: false)
window.appearance = NSAppearance(named: .darkAqua)
window.contentView = host
RunLoop.main.run(until: Date().addingTimeInterval(1.2))   // 비동기로 채워지는 목록 대기
let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
host.cacheDisplay(in: host.bounds, to: rep)
```

- `@main` 이 있는 파일만 빼고 앱 소스 전체를 함께 컴파일한다
- 매니저 초기화가 `@MainActor` 면 `MainActor.assumeIsolated { … }` 로 감싼다
- `cacheDisplay` 는 창 바탕을 안 그린다. `NSColor.windowBackgroundColor` 를 같은 appearance
  로 먼저 칠하고 그 위에 합성해야 실제와 같다

전체 예제: 이 저장소의 `docs/plans/color-tokens/probes/render-content-view.swift`.

통하지 않은 시도 — 실행 인자 `-AppleInterfaceStyle Dark`.

## 재발 방지

없음. 다크 확인이 필요하면 위 방식으로 한다. 시스템 설정을 바꾸는 방법(System Events)은
사용자 화면 전체가 바뀌므로 쓰지 않는다.
