# checklist — caffeinate-list

`(확인)` 은 사용자가 직접 써보고 확인해준 것, `(실측)` 은 명령·캡처로 확인한 것이다.

## 0. 검토
- [x] `sysctl(KERN_PROC_ALL)` 로 전체 프로세스를 권한 없이 열거할 수 있는지 (실측 — 712개)
- [x] `sysctl(KERN_PROCARGS2)` 로 인자 원문을 읽을 수 있는지 (실측 — `["caffeinate","-dimsu","-t","90"]`)
- [x] root 소유 프로세스의 인자는 못 읽는 것 확인 (실측 — 권한 실패)
- [x] `caffeinate` 플래그 목록 (실측 — `man caffeinate`, 7개)
- [x] `kinfo_proc` 하나에 pid·ppid·uid·이름이 다 있는지 (실측 — 추가 호출 불필요)
- [x] 되살아나던 `caffeinate -i -t 300` 의 정체 (실측 — Claude Code 세션, 앱 아님)
- [x] 범위 / 배지 / 조회 방식 — 사용자에게 물어 확정
- [x] spec · context 작성
- [ ] 목록에서 이 앱 소유를 `kill` 했을 때 `sleepWhenDone` 이 맥을 잠재우는지 재현 (실측 필요)

## 1. 조회 계층 (`CaffeinateScanner`)
- [ ] `sysctl(KERN_PROC_ALL)` 열거 → `p_comm == "caffeinate"` 만 추린다
- [ ] `sysctl(KERN_PROCARGS2, pid)` 로 인자. 실패하면 `argsUnreadable` 로 남긴다
- [ ] 부모 이름은 같은 스냅숏에서 `e_ppid` 로 찾는다 (추가 sysctl 금지)
- [ ] `ppid == getpid()` 면 `이 앱` 으로 표시
- [ ] 경과 시간은 `kp_proc.p_starttime` 에서 계산
- [ ] 플래그 파싱 — 묶음(`-dimsu`)을 개별 칩으로 쪼갠다. `-t` `-w` 는 값을 붙여 보여준다
- [ ] 모르는 플래그는 원문 그대로 칩으로. 툴팁 없음

## 2. 폴링
- [ ] 창이 보이는 동안만. 닫히면 멈춘다 (앱 생존과 무관 — menu-bar-item 에서 창 닫기가 세션을 끊지 않게 바뀌었다)
- [ ] 접힘 5초 / 펼침 2초
- [ ] 펼치는 순간 즉시 1회 조회
- [ ] 목록이 바뀌지 않았으면 `@Published` 를 건드리지 않는다 (불필요한 리렌더 방지)

## 3. 화면
- [ ] 잠자기 방지 탭 맨 아래에 `DisclosureGroup`
- [ ] 접힌 상태 제목 옆에 개수 배지. 0개면 배지 없음
- [ ] 항목마다 pid · 경과 시간 · 옵션 칩 · 부모 이름
- [ ] 옵션 칩 호버 → `.help()` 로 설명 (7개 플래그)
- [ ] 비었으면 `caffeine.empty` 한 줄. 빈 상자를 그리지 않는다
- [ ] 간격·여백은 `Design` 토큰에 추가해서 쓴다. 숫자를 뷰에 직접 쓰지 않는다

## 4. 중지
- [ ] 우클릭 → `.contextMenu` 에 `중지하기` 하나
- [ ] **이 앱 소유(`ppid == getpid()`)면 `manager.stop()` 으로 보낸다** — `kill` 직접 호출 금지
- [ ] 그 외는 `kill(pid, SIGTERM)`
- [ ] 다른 uid 소유면 항목을 비활성하고 `caffeine.stopDenied` 를 툴팁으로
- [ ] 중지 후 즉시 재조회 (2~5초 기다리지 않게)
- [ ] `kill` 이 실패하면 조용히 넘기지 않고 사유를 보여준다

## 5. 문자열
- [ ] `L10n.Key` 에 13개 키 추가 (context.md 표)
- [ ] `ko` · `en` · `ja` 세 파일 모두 채움 — 빠지면 키 이름이 화면에 나온다
- [ ] `docs/i18n-design.md` 표에 추가 (안 하면 문서가 거짓이 된다)

## 6. 검증
- [ ] caffeinate 를 직접 띄워 목록에 나타나는지 (실측)
- [ ] 묶음 플래그(`-dimsu`)가 칩 5개로 쪼개지는지 (실측)
- [ ] 앱에서 시작한 세션이 `이 앱` 으로 표시되는지 (실측)
- [ ] 목록에서 앱 소유를 중지했을 때 `sleepWhenDone` 이 켜져 있어도 맥이 안 잠드는지 (실측 — 0번 항목의 재현이 먼저)
- [ ] root 소유 항목이 비활성으로 보이는지 (실측 — `sudo caffeinate` 로 만들어서)
- [ ] 창을 닫으면 폴링이 멈추는지 (실측)
- [ ] 호버 설명이 3개 언어에서 다 나오는지 (확인)
