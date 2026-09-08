# my-mac-tools

macOS 유틸리티 앱 (MyMacTools) — SwiftPM 기반 executable + 수동 `.app` 번들링.

## 작업 워크플로우

**이 프로젝트의 모든 작업은 별도 브랜치 없이 `main`에 바로 커밋하고 즉시 푸시한다.**

- 브랜치를 새로 만들지 않는다. `main`에서 직접 작업한다.
- 작업 단위가 끝나면 바로 `git commit` → `git push origin main`.
- 커밋/푸시 전에 사용자에게 따로 확인받지 않는다. (2026-09-09 사용자 지시)
- PR 은 만들지 않는다.

## 빌드 & 설치

```bash
./scripts/build-app.sh              # .build/MyMacTools.app 생성 (swift build -c release + 번들 조립)
cp -R .build/MyMacTools.app /Applications/
```

`scripts/build-app.sh` 의 `APP_NAME`, `Resources/Info.plist` 의 `CFBundleExecutable`/`CFBundleName`,
그리고 Package.swift 의 타깃명이 서로 맞아야 번들이 실행된다. 앱 이름을 바꿀 때 세 곳을 함께 수정한다.

서명은 ad-hoc(linker-signed) 이다. 로컬 실행에는 문제없지만 다른 맥으로 배포하면 Gatekeeper 경고가 뜬다.
