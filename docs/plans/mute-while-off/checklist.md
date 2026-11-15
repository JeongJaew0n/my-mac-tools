# checklist — mute-while-off

`(실측)` 은 명령·캡처로 확인한 것, `(확인)` 은 사용자가 직접 써보고 확인해준 것이다.

## 1. 구현
- [x] `OutputMute` — 기본 출력 장치 음소거·되돌리기 (CoreAudio)
- [x] `BlackWorkManager.muteWhileOff`, 화면을 처음 끌 때 음소거, `reset()` 에서 되돌림, 앱 종료 때 되돌림
- [x] `ToolDefaults.Sleep` 에 추가 — 옛 저장값 호환
- [x] 설정 블록 토글(keepOff 아닐 때 잠금), 실패 안내, ko/en/ja
- [x] API `sleep.get`/`sleep.start`, `docs/api.md`, README, 용어집

## 2. 검증
- [x] 빌드 경고 0 (실측)
- [x] 옛 저장값(항목 없음)을 읽어도 나머지 값이 살아 있다 — 사용자가 실제로 저장해 둔 `default.sleep`(keepOff·5초)이 그대로 읽힘 (실측)
- [x] 음소거 → 되돌림: 이미 음소거였으면 그대로, 아니었으면 풀림 — MacBook Pro 스피커, 끝에 원래 상태(음소거)로 둠 (실측)
- [x] 화면 캡처 ko 라이트 320 · en 다크 320 · ja 라이트 380 (실측)
- [ ] 세션 전체 흐름(카운트다운 → 화면 꺼짐 → 음소거 → 정지 → 되돌림) — 시험하면 사용자의 화면이 꺼져 셸에서 돌리지 않았다
- [ ] (확인) 사용자가 직접 써보기
