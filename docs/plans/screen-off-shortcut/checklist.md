# checklist — screen-off-shortcut

`(실측)` 은 명령·캡처로 확인한 것, `(확인)` 은 사용자가 직접 써보고 확인해준 것이다.

## 1. 구현
- [x] `HotKeyCenter` 여러 개 등록(`Slot` → `EventHotKeyID.id`)
- [x] `BlackWorkManager` 단축키 저장(`screenOffShortcut`)·등록, `Actions.toggleScreenOffFromShortcut`
- [x] 잠자기 방지 탭에 녹화 칸, 양쪽 겹침 안내, ko/en/ja (286개 일치)
- [x] README

## 2. 검증
- [x] 빌드 경고 0 (실측)
- [x] 자리별 분배 — 핫키 이벤트를 만들어 보냄: id1→화면 가리기, id2→화면 끈 채로 작업, 남의 서명·모르는 id 무시,
  한 자리를 풀어도 다른 자리 유지 (실측)
- [x] 같은 조합을 다른 자리에 등록하면 Carbon 이 거부한다 → 화면에서 겹침을 막는 근거 (실측)
- [x] 토글 — 창 값(계속 켜두기·3시간)을 기본값으로 되돌리고 keepOff 로 켬, `caffeinate -i -w <pid>`, 카운트다운 5,
  다시 누르면 꺼지고 caffeinate 남지 않음 (실측, 시험 프로그램)
- [x] 화면 캡처 ko 라이트 320 · en 다크 320 · ja 라이트 380 (실측)
- [ ] 진짜 키 입력 — 셸에서 합성한 키(`CGEventPost`)로는 **수정 전 코드의 단축키도** 발동하지 않아 시험 방법으로 못 씀
- [ ] (확인) 사용자가 직접 눌러 보기
