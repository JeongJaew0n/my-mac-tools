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
- [ ] `scripts/release.sh <initial|minor|patch> "<한 줄>" [git commit 인자…]`
- [ ] 시험: 임시 저장소 + 가짜 gh — initial, minor, patch, 더러운 트리·있는 태그 거절

## 6. 검증·릴리스
- [ ] `scripts/test.sh`
- [ ] 화면 캡처
- [ ] 첫 릴리스 v0.1.0 을 내고 실제 API 로 최신 판단 (실측)
- [ ] (확인) 실제 업데이트
