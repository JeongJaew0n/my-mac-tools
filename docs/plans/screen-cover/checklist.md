# checklist — screen-cover

`(확인)` 은 사용자가 직접 써보고 확인해준 것, `(하네스)` 는 코드를 돌려 확인한 것이다.

## 0. 검토
- [x] 모든 디스플레이 열거·배율 확인 (3대, 배율 상이)
- [x] 창 레벨로 메뉴 막대·Dock 을 덮을 수 있는지 확인 (`CGShieldingWindowLevel()`)
- [x] 인프로세스 디스플레이 슬립 차단 확인 (`IOPMAssertionCreateWithName`)
- [x] 인증 수단 조사 후 **넣지 않기로** 결정
- [x] spec · context 작성

## 1. 커버
- [x] `ScreenCoverManager` — 화면별 창 생성·해제
- [x] `CGShieldingWindowLevel()`, `canJoinAllSpaces`, `stationary`, `fullScreenAuxiliary`
- [x] borderless 창이 key 가 되도록 `canBecomeKey` 열기
- [x] 이미지 로드 실패 시 커버를 띄우지 않고 사유를 표시 (하네스)
- [x] 화면이 덮인다 (확인)
- [ ] 메뉴 막대·Dock 이 가려지는지
- [ ] 화면 3대가 **모두** 덮이는지

## 2. 이미지
- [x] 파일 선택(`NSOpenPanel`) · 경로를 `UserDefaults` 에 저장
- [x] 꽉 채우기 / 맞추기 선택, 기본값 꽉 채우기 (기본값은 하네스)
- [x] 배율이 다른 화면에서 각각 의도대로 보이는지 (확인, 2026-09-16)

## 3. 해제
- [x] 해제 버튼 — **모든 화면에** 표시
- [x] `Enter` 2번 — 상한 1.5초
- [x] `Esc` 2번 — `Enter` 와 같은 상한 1.5초 (확인, 2026-09-16)
- [x] 셋 다 `stop()` 한곳으로 모음
- [x] `Cmd-Q` 로 빠져나올 수 있다 — 해제가 고장났을 때의 탈출구 (확인, 2026-09-16)
- [ ] `Cmd-Tab` · 강제 종료 창이 커버 위로 오는지 확인 후 기록

## 4. 슬립 차단
- [x] 커버 시작 시 assertion 획득, 해제 시 반납
- [ ] 커버 중 `pmset -g assertions` 에 `MyMacTools screen cover` 가 보이는지
- [ ] 앱 강제 종료 후 잔존 0건 확인

## 5. 모니터 착탈 — **보류** (사용자 요청, 2026-09-16)
- [x] `didChangeScreenParametersNotification` 구독 (코드상)
- [ ] 커버 중 모니터를 뽑으면 창이 사라지는지
- [ ] 커버 중 모니터를 꽂으면 창이 붙는지

## 6. 전역 단축키
- [x] Carbon `RegisterEventHotKey` 채택 — 손쉬운 사용 권한 없이 `noErr` 로 등록됨
- [x] `Shortcut` 모델 — 표시 문자열·Carbon 수정자 변환·저장 (하네스)
- [x] 수정자(`⌘`/`⌥`/`⌃`) 없는 조합 거절 (하네스)
- [x] 기록 UI — `Delete` 로 지움, `Esc` 로 취소
- [x] **덮기만** 한다 (해제는 화면의 세 가지)
- [x] 덮지 못하면 창을 앞으로 내보내 이유를 보여줌
- [x] 실제로 키를 눌러 발동한다 (확인, 2026-09-16)
- [ ] 다른 앱이 떠 있을 때도 발동하는지

시스템이 이미 쓰는 조합(`⌘Space` 등)은 등록이 `noErr` 로 성공해도 시스템이 먼저 가져간다.
앱에서 감지할 방법이 없어 README 에 안내만 남겼다.

## 7. 마무리
- [x] 세 번째 탭으로 편입, 탭 라벨 상태 점
- [x] 문자열 3언어(ko/en/ja), 키 집합 대조 (60개 일치)
- [x] README — **"잠금이 아니다"** 명시
