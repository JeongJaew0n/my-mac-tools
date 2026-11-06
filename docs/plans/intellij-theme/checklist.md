# checklist — intellij-theme

`(확인)` 은 사용자가 직접 써보고 확인해준 것, `(실측)` 은 명령·캡처로 확인한 것이다.

## 0. 조사
- [x] 지금 테마가 어디서 오는지 (laf.xml · colors.scheme.xml · 사용자 플러그인) (실측)
- [x] 원본 hex 와 뜻의 대응 — 43종, 하나에 뜻 하나 (실측)
- [x] spec · context 작성

## 1. 고르기·저장·불러오기
- [x] 용어집 — 팔레트 · 프리셋 · 색 역할
- [x] `IntelliJThemeTemplate` — 원본에서 기계적으로 뽑은 템플릿 + 역할 43개
- [x] `IntelliJThemeManager` — 팔레트 보존, 프리셋 저장·불러오기·삭제
- [x] `Tab.intellijTheme` 과 화면(`IntelliJThemeView`), ko/en/ja 문자열

## 2. 적용
- [x] 대상 찾기 (bundle id → product-info.json)
- [x] jar 만들기, laf.xml · colors.scheme.xml 고치기, 백업, 되돌리기
- [x] 켜져 있으면 종료 → 쓰기 → 다시 열기 (코드만 — 실제 IntelliJ 로는 아직 안 돌림)
- [x] API `intellij.info` (`intellij.apply`·`restore` 는 `needsHuman`), README · api.md · CLAUDE.md

## 3. 검증
- [x] 빌드 (실측)
- [x] 템플릿에 기본값을 채운 결과가 원본 테마와 같다 (실측) — UI 키를 색으로 풀어 비교, 스킴 colors 11 · attributes 83 일치
- [x] 임시 설정 폴더에 적용 → jar 구조 · XML 결과 확인, 되돌리기 확인 (실측) — 실제 설정을 복사한 폴더. 다른 옵션 보존, 되돌린 뒤 값 일치, 파일 없는 폴더도 동작
- [x] 화면 캡처 — ko 라이트 380pt, en 다크 320pt (화면 밖 창에 `IntelliJThemeView` 를 그려 찍음. '더 보기' 펼친 상태는 안 찍음)
- [ ] (확인) 실제 IntelliJ 에 적용하고 다시 켰을 때 색이 바뀐다
