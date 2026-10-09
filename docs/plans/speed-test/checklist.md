# checklist — speed-test

`(확인)` 은 사용자가 직접 써보고 확인해준 것, `(실측)` 은 명령·캡처로 확인한 것이다.

## 0. 조사
- [x] macOS 내장 `networkQuality` 존재·옵션 확인 (실측)
- [x] 1회 실행 시간·데이터 사용량 (실측 — 21초, 받음 57 MB · 보냄 90 MB)
- [x] JSON 키와 단위 (실측 — `dl_throughput` 은 bit/s, 바이트 수로 검산)
- [x] 다른 측정 수단 검토, 기각 이유 기록
- [x] spec · context 작성
- [x] 결정 7개 — 추천대로 확정 (2026-10-09)

## 1. 구현
- [x] `SpeedTestManager` — `networkQuality -c -M 30` 을 `Process` 로. 결과는 JSON 파싱
- [x] stdout·stderr 를 **따로** 읽는다 (한쪽이 먼저 차면 서로 멈춘다)
- [x] 취소 — `terminate`. 취소한 종료는 실패로 그리지 않는다
- [x] 실패는 0 Mbps 가 아니라 이유를 보여준다
- [x] 최근 10회를 `UserDefaults` 에 저장
- [x] 비싼 회선 — `NWPathMonitor` 의 `isExpensive` · `isConstrained` 를 이벤트로 받는다(폴링 없음)
- [x] 다섯째 탭 `속도 측정`. 메뉴바에는 넣지 않았다
- [x] 응답성 **등급은 붙이지 않았다** — `networkQuality` 바이너리에 경계값이 문자열로
      없어서(`strings` 로 확인) 지어내지 않고 RPM 숫자만 보인다
- [x] API `speedtest.start` · `speedtest.status` · `speedtest.cancel`, `status` 에도 포함.
      비싼 회선이면 `start` 는 `needsHuman`
- [x] 문구 18개 × 3언어 (실측 — 각 18개)

## 2. 검증
- [x] 파서 — 실제 JSON 으로 값 일치, 빈·깨진·키 없는 입력은 nil (실측)
- [x] 저장·복원 왕복 (실측)
- [x] **실제 앱**에서 API 로 측정 — 시작이 0초에 돌아오고, 15초쯤 끝나 결과가 들어왔다
      (실측 — 다운 7 Mbps · 업 59.1 Mbps · 55 RPM · 19 ms)
- [x] 취소 — `networkQuality` 프로세스가 사라지고 `error` 없이 대기 상태로 (실측)
- [x] 재시작 후 기록 유지 (실측)
- [x] 새 탭이 설정을 건드리지 않아도 보인다 — 숨김 목록에 없다 (실측). 설정 창 토글이
      4개 → 5개 (실측, AX)
- [ ] 비싼 회선에서 확인창 — **실물로 못 만들었다.** 핫스팟·셀룰러가 없다
- [ ] 탭 화면 모양·진행 표시 — 눈으로는 미확인 (SwiftUI 자식이 AX 에 안 보인다)
- [ ] 세 언어 문구 (확인)

## 3. 편의 기능 — 이 속도로 무엇을 할 수 있나 (2026-10-09)
- [x] 기준값을 공식 문서에서 확인 — Netflix · YouTube · Zoom (실측 — 각 페이지에서 원문 인용)
- [x] 게임은 기준을 못 찾아 제외 (Xbox 본문 없음, PlayStation 404) — 이유 기록
- [x] `SpeedUsage` — 활동 5개, 두 출처가 다르면 엄격한 쪽
- [x] 1 GB 받기·보내기 이론 시간
- [x] 화면 — 체크/엑스, 필요 속도, 마우스를 올리면 출처. "기기 한 대 기준" 안내
- [x] API `speedtest.status` 의 `latest.usage` · `secondsPerGigabyteDown/Up`
- [x] 문구 11개 × 3언어
- [x] 경계 — 20.0 은 4K 가능·19.9 불가, 업 3.7 은 1080p 통화 불가·3.8 가능 (실측)
- [x] 업로드만 모자라면 통화만 불가 (실측 — ↓100 ↑2.5)
- [x] 1 GB 계산 — 8 Mbps → 1000초, 0 bps → 없음 (실측)
- [x] 실제 앱에서 판정 (실측 — ↓40.4 ↑57.8 → 다섯 개 모두 가능, 1 GB 198초·138초)
- [ ] 화면 모양 — 눈으로는 미확인
