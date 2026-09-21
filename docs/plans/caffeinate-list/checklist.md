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
- [ ] 목록에서 이 앱 소유를 `kill` 했을 때 `sleepWhenDone` 이 맥을 잠재우는지 재현
      **하지 않았다.** 성공하면 맥이 실제로 잠드는 테스트다. 방어 코드(매니저 경유)는
      넣었고 그 경로가 도는 것은 확인했지만, "안 고쳤으면 정말 잠들었는가" 는 미검증이다

## 1. 조회 계층 (`CaffeinateScanner`)
- [x] `sysctl(KERN_PROC_ALL)` 열거 → `p_comm == "caffeinate"` 만 추린다
- [x] `sysctl(KERN_PROCARGS2, pid)` 로 인자. 실패하면 `argsUnreadable` 로 남긴다
- [x] 부모는 `proc_pidpath` 로 **전체 경로**를 쓰고, 못 읽으면 같은 스냅숏의 짧은 이름으로 떨어진다
      (짧은 이름만으로는 주인을 못 알려준다 — Claude Code 의 부모 이름이 `2.1.276` 이었다)
- [x] `ppid == getpid()` 면 `이 앱` 으로 표시
- [x] 경과 시간은 `kp_proc.p_starttime` 에서 계산
- [x] 플래그 파싱 — 묶음(`-dimsu`)을 개별 칩으로 쪼갠다. `-t` `-w` 는 값을 붙여 보여준다 (실측 — 8개 경우)
- [x] 모르는 플래그는 원문 그대로 칩으로. 툴팁 없음 (실측 — `-iz` → `-i`, `-z`(설명없음))

## 2. 폴링
- [x] 창이 보이는 동안만. 닫히면 멈춘다 — `onAppear`/`onDisappear`
- [x] 접힘 5초 / 펼침 2초
- [x] 펼치는 순간 즉시 1회 조회 (`isExpanded` 의 `didSet`)
- [x] 목록이 바뀌지 않았으면 `@Published` 를 건드리지 않는다 (`Equatable` 비교)

## 3. 화면
- [x] 잠자기 방지 탭 맨 아래에 `DisclosureGroup`
- [x] 접힌 상태 제목 옆에 개수 배지. 0개면 배지 없음
- [x] 항목마다 pid · 경과 시간 · 옵션 칩 · 부모 경로
- [x] 옵션 칩 호버 → `.help()` 로 설명 (7개 플래그)
- [x] 비었으면 `caffeine.empty` 한 줄. 빈 상자를 그리지 않는다
- [x] 간격·여백은 `Design` 토큰에 추가해서 쓴다 (9개 추가)

## 4. 중지
- [x] 우클릭 → `.contextMenu` 에 `중지하기` 하나
- [x] **이 앱 소유(`ppid == getpid()`)면 `manager.stop()` 으로 보낸다** — `kill` 직접 호출 금지
- [x] 그 외는 `kill(pid, SIGTERM)`
- [x] 다른 uid 소유면 메뉴 항목을 비활성하고 `caffeine.stopDenied` 를 같이 보여준다
- [x] 중지 후 즉시 재조회 (`defer { refresh() }`)
- [x] `kill` 이 실패하면 `strerror(errno)` 를 `caffeine.stopFailed` 로 보여준다

## 5. 문자열
- [x] `L10n.Key` 에 **15개** 키 추가 — 설계의 13개에 `caffeine.stopFailed` · `caffeine.utility` 를 더했다
- [x] `ko` · `en` · `ja` 세 파일 모두 채움 (실측 — 각 15개)
- [x] `docs/i18n-design.md` 표는 **건드리지 않는다.** 그 표는 초기 설계의 키만 담고 있고
      나중에 붙은 `cover.*`(16개) · `menu.*`(2개)도 없다. 전례를 따른다

## 6. 검증
- [x] caffeinate 를 직접 띄워 목록에 나타나는지 (실측 — `caffeinate -dimsu -t 60` 이 pid 째로 등장)
- [x] 묶음 플래그가 쪼개지는지 (실측 — 살아 있는 `-dimsu -t 60` → `-d -i -m -s -u -t 60` 6개.
      파서 단위로도 8개 경우 확인)
- [x] 앱에서 시작한 세션이 `이 앱` 으로 표시되는지 (실측 — API `caffeinate.list` 에서
      `pid 84791 MyMacTools ['-d','-i','-t 600'] isThisApp=true`)
- [x] 목록에서 앱 소유를 중지해도 맥이 안 잠드는 것 (실측 — API `caffeinate.stop` 으로
      앱 소유 pid 를 껐고, `sleep.get` 이 `running:false` 로 복귀했으며 맥은 잠들지 않았다.
      단 `sleepWhenDone=false` 로 돌린 것이라 만료 직전 구간까지 재현한 것은 아니다)
- [ ] root 소유 항목이 비활성으로 보이는지 (실측 — `sudo caffeinate` 로 만들어서)
- [x] 창을 닫으면 폴링이 멈추는지 — `onDisappear` 로 `stopPolling`. 앱 CPU 0.0% 로 간접 확인
- [x] 호버 설명이 뜨는지 (확인). **3개 언어 문구가 다 있는 것은 실측**(각 15개)이지만,
      언어를 바꿔 눈으로 본 것은 ko 뿐이다
