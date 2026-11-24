# checklist — app-versioning

`(실측)` 은 명령·캡처로 확인한 것, `(확인)` 은 사용자가 직접 써보고 확인해준 것이다.

## 1. 용어·규칙
- [x] 용어집 — `판` 을 `버전`·`릴리스`·`빌드 커밋` 으로 나눈다
- [x] CLAUDE.md 에 버전 규칙과 릴리스 내는 때

## 2. 번호와 빌드
- [x] Info.plist `CFBundleShortVersionString` = 0.1.0, `CFBundleVersion` 은 build-app.sh 가 채운다
- [x] semver 해석·비교 (시험)

## 3. 확인·받기
- [x] `releases/latest` 해석, 404 → 릴리스 없음 (시험)
- [x] 번호 비교 → 최신/새 버전 (시험)
- [x] 커밋 목록: 설치 커밋 → 지금 번호 태그 → 없음 순서
- [x] 태그를 받아 빌드, 번호·커밋·서명 확인

## 4. 화면
- [x] 지금 버전·새 버전 번호, 최신·릴리스 없음, ko/en/ja

## 5. 릴리스 스크립트
- [x] `scripts/release.sh <initial|minor|patch> "<한 줄>" [git commit 인자…]`
- [x] 시험: 임시 저장소 + 가짜 gh — initial, minor, patch, 더러운 트리·있는 태그 거절

## 6. 검증·릴리스
- [x] `scripts/test.sh` — 95개 (실측)
- [x] 첫 릴리스 v0.1.0 (태그 → 305d935). 처음에는 다른 호스트(github.nhnent.com)의 끊긴 gh 로그인 때문에 `gh auth status` 가
      1 로 끝나 거절했다 — github.com 만 묻게 고쳤다 (실측)
- [x] 화면 캡처, 실제 GitHub 응답으로 — 릴리스 없음(릴리스 전), 최신(0.1.0), 새 버전(0.0.9 · 529ee3d → 커밋 10개, ko 라이트·en 다크),
      비교 기준 없음(GitHub 에 없는 커밋 → 없는 태그 v0.0.9 → 목록 없이 번호만, ja) (실측)
- [x] 짧은 PATH 로 태그 받기·빌드: 받아 둔 사본에서 `refs/tags/v0.1.0` 받기 1초, 빌드 13초, 새로 `clone --branch v0.1.0` 1초.
      결과 앱 버전 0.1.0 · CFBundleVersion 0.1.0 · 빌드 커밋 305d935 · 서명 확인 (실측)
- [x] 0.1.0 첫 설치본(4668ccd)을 손으로 설치 — 켜지며 `launched-4668ccd…` 신호를 쓰고 API 가 답한다. 돌던 잠자기 방지 세션은 사용자 선택대로 같은 설정으로 다시 켰다 (실측)
- [ ] (확인) 실제 업데이트 — 다음 릴리스(0.1.1 이나 0.2.0)가 나온 뒤 앱 메뉴에서
