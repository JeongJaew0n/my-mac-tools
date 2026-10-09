# checklist — speed-test

`(확인)` 은 사용자가 직접 써보고 확인해준 것, `(실측)` 은 명령·캡처로 확인한 것이다.

## 0. 조사
- [x] macOS 내장 `networkQuality` 존재·옵션 확인 (실측)
- [x] 1회 실행 시간·데이터 사용량 (실측 — 21초, 받음 57 MB · 보냄 90 MB)
- [x] JSON 키와 단위 (실측 — `dl_throughput` 은 bit/s, 바이트 수로 검산)
- [x] 다른 측정 수단 검토, 기각 이유 기록
- [x] spec · context 작성
- [ ] **열린 결정 7개 확정** (spec.md 표)

## 1. 이후 — 결정이 확정되면 채운다
