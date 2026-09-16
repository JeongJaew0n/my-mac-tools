# checklist — screen-cover

## 0. 검토
- [x] 모든 디스플레이 열거·배율 확인 (3대, 배율 상이)
- [x] 창 레벨로 메뉴 막대·Dock 을 덮을 수 있는지 확인 (`CGShieldingWindowLevel()`)
- [x] 인프로세스 디스플레이 슬립 차단 확인 (`IOPMAssertionCreateWithName`)
- [x] 인증 수단 조사 후 **넣지 않기로** 결정
- [x] spec · context 작성

## 1. 커버
- [ ] `ScreenCoverManager` — 화면별 창 생성·해제
- [ ] `CGShieldingWindowLevel()`, `canJoinAllSpaces`, `stationary`, `fullScreenAuxiliary`
- [ ] borderless 창이 key 가 되도록 `canBecomeKey` 열기
- [ ] 이미지 로드 실패 시 커버를 띄우지 않고 사유를 표시

## 2. 이미지
- [ ] 파일 선택(`NSOpenPanel`) · 경로를 `UserDefaults` 에 저장
- [ ] 꽉 채우기 / 맞추기 선택, 기본값 꽉 채우기
- [ ] 배율이 다른 화면에서 각각 의도대로 보이는지 확인

## 3. 해제
- [ ] 해제 버튼 — **모든 화면에** 표시
- [ ] `Enter` 2번 (간격 상한 둘 것)
- [ ] `Esc` 3초 꾹 — 누르는 동안 진행 표시
- [ ] 셋 다 동일 경로로 해제되도록 한곳에 모으기

## 4. 슬립 차단
- [ ] 커버 시작 시 assertion 획득, 해제 시 반납
- [ ] `pmset -g assertions` 로 획득·반납 확인
- [ ] 앱 강제 종료 후 잔존 0건 확인

## 5. 모니터 착탈
- [ ] `didChangeScreenParametersNotification` 구독
- [ ] 커버 중 모니터를 뽑으면 창이 사라지는지
- [ ] 커버 중 모니터를 꽂으면 창이 붙는지

## 6. 마무리
- [ ] 세 번째 탭으로 편입, 탭 라벨 상태 점
- [ ] 문자열 3언어(ko/en/ja), 키 집합 대조
- [ ] README — **"잠금이 아니다"** 명시
- [ ] `Cmd-Tab` · 강제 종료 창이 커버 위로 오는지 확인 후 기록
