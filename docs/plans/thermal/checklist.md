# checklist — thermal

`(확인)` 은 사용자가 직접 써보고 확인해준 것, `(실측)` 은 명령·캡처로 확인한 것이다.

## 0. 조사
- [x] 공개 API · pmset · IOHID 로 이 맥에서 읽히는 값 확인 (실측)
- [x] spec · context 작성

## 1. 구현
- [x] `ThermalManager` — thermalState 알림 + IOHID 센서(백그라운드) + 묶음
- [x] `Tab.thermal` 과 화면, ko/en/ja 문자열
- [x] API `thermal.info`
- [x] 용어집 · README · api.md · CLAUDE.md 구조

## 2. 검증 (실측)
- [x] API 값과 독립 스크립트 값 비교 — SoC 다이 20개, 최고 39.4 / 39.0°C · 평균 37.9 / 38.0°C (읽은 시점 차이)
- [ ] 탭을 떠나면 읽기가 멈춘다
- [x] 화면 캡처로 배치 확인 — ko 라이트 380pt, en 다크 320pt. 영어 "PMU device sensors" 가 최소 폭에서 꺾여 "PMU sensors" 로 줄임
  (실제 창은 '화면 끔 유지' 세션 중이라 캡처 불가 → 앱 소스로 `ContentView` 를 화면 밖 창에 그려 찍었다)
- [ ] (확인) 사용자가 직접 써보기
