# Xcode 없이 `swift test` 를 돌리면 `Testing`·`XCTest` 모듈을 못 찾는다

## 환경

- macOS 26 (Darwin 25.3.0), Apple Silicon
- **Xcode 없음.** `xcode-select -p` → `/Library/Developer/CommandLineTools`
- Swift 6.2.3 (명령줄 도구판), SwiftPM 패키지에 `.testTarget`

## 증상

두 단계로 막힌다. 둘 다 오류는 컴파일 단계에서 난다.

1. `import XCTest` → `error: no such module 'XCTest'`.
   `import Testing` → `error: no such module 'Testing'`.
2. 프레임워크 경로를 넘겨 `Testing` 을 찾게 한 뒤, 시험 파일에 `import Foundation` 이 함께 있으면
   → `error: no such module '_Testing_Foundation'`.

## 원인

1. 명령줄 도구판에는 **XCTest 가 아예 없다.** swift-testing 은 들어 있지만
   `CommandLineTools/Library/Developer/Frameworks/Testing.framework` 에 있어 SwiftPM 의 기본 검색 경로 밖이다.
2. `Testing.framework/Modules/` 에 `Testing.swiftcrossimport` 가 있어서 `Foundation` 과 함께 쓰면
   교차 모듈 `_Testing_Foundation` 을 찾으러 간다. 그런데 그 모듈은 명령줄 도구판에 들어 있지 않다.

## 해결

경로를 넘기고, 교차 모듈을 찾지 않게 한다.

```bash
F="$(xcode-select -p)/Library/Developer/Frameworks"
swift test -Xswiftc -F"$F" \
           -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays \
           -Xlinker -F"$F" -Xlinker -rpath -Xlinker "$F"
```

- `-rpath` 는 시험 실행 파일이 그 폴더에서 프레임워크를 찾게 한다. 빼고 돌려 보지는 않았다.
- 교차 모듈을 꺼도 `#expect`·`#require`·`@Test(arguments:)` 는 그대로 썼다(확인한 것은 이 셋이다).
- 경로를 `Package.swift` 의 `unsafeFlags` 에 박지 않는다. Xcode 가 있는 맥에서는 틀린 경로가 된다.
- 통하지 않은 것: 경로만 넘기기(2의 오류), XCTest 로 바꾸기(1의 오류 — 명령줄 도구판에 없다).

빈 패키지에 시험 하나를 두고 `XCTest` · `Testing` 각각 돌려 1의 오류를 봤다. 경로를 넘긴 뒤
`import Foundation` 이 있는 시험에서 2의 오류가 났고, 옵션을 더해 통과했다(2026-11-18).

## 재발 방지

`xcode-select -p` 가 `CommandLineTools` 일 때만 위 옵션을 붙이는 시험 스크립트를 두고, 문서에는
`swift test` 대신 그 스크립트를 적는다.
