# context — lid-close-keep-working

## 사용자의 원 요청
> "데몬은 지우고 우리 제품의 기능으로 전환하자. 기능 이름은 '맥북 덮개 닫아도 작업 진행'
> 기능이고, 간단하게 버튼 1개로 가자. 시작/중지를 나타내는 버튼.
> 대신, 주의사항을 반드시 적어줘. 1. ac를 연결해야한다. 이런거. 사용자가 지켜야할거.
> 프로그램이 아니라."

## 왜 이걸 지금 하는가
사용자는 맥북 덮개를 닫아도 모든 앱이 계속 돌아가기를 원했다. 외장 디스플레이 없이 덮개만
닫는 시나리오다. 별도 세션에서 조사한 결과 `caffeinate` 로는 불가능하고 `pmset -a disablesleep`
만이 유일한 수단이라는 결론이 나왔고, 안전장치로 LaunchDaemon `local.clamshell-awake` 를
2026-09-12 에 임시 설치해 실제로 동작을 검증했다.

검증은 성공했다. 18:24:45 에 AC 연결 상태로 덮개를 닫고 18:25:41 에 열었으며, 그 56초 동안
`pmset -g log` 에 `Entering Sleep` 항목이 하나도 남지 않았다. 같은 날 배터리 상태에서 닫았을
때는 4초 만에 `Clamshell Sleep` 으로 잠들었던 것과 대비된다.

검증이 끝났으므로 임시 데몬을 제거하고, 같은 동작을 제품(MyMacTools 앱)의 정식 기능으로
옮기는 것이 이 작업이다.

## 결정된 방향
앱 안에서 관리자 인증 다이얼로그를 띄워 `pmset -a disablesleep` 을 토글한다.
시스템에 영구 설치물을 남기지 않는다.

## 기각된 대안
- **LaunchDaemon 유지** — 검증용으로 쓴 방식. 설치에 `sudo` 가 필요하고 `/usr/local/bin` 과
  `/Library/LaunchDaemons` 에 영구 파일을 남긴다. 제품 기능으로는 설치 부담이 크다.
- **`SMJobBless` 권한 헬퍼** — 정석적인 방법이지만 Developer ID 인증서가 필요하다.
  이 앱은 ad-hoc 서명이라 사용할 수 없다.
- **`/etc/sudoers.d` 드롭인** — 한 번 설치하면 암호 없이 동작하지만, 결국 최초 1회 `sudo`
  설치 과정이 필요하고 시스템에 영구 파일이 남는다. LaunchDaemon 과 같은 성격의 부담.
- **전원 소스 자동 감시 후 배터리면 자동 해제** — 데몬이 하던 안전장치. 사용자가 명시적으로
  "프로그램이 아니라 사용자가 지켜야 할 것"이라고 선을 그어, 감시 대신 주의사항 텍스트로
  대체하기로 했다.
- **종료 시 무조건 자동 원복** — 원복도 root 권한이라 인증 다이얼로그가 필요한데, 앱 종료
  중에는 그 창이 뜨지 않거나 사용자가 취소할 수 있어 "될 때도 있고 안 될 때도 있는" 동작이
  된다. 대신 경고 다이얼로그 + 다음 실행 시 상태 복원을 택했다.
- **기존 세션과 상호 배타** — "덮개 닫고 화면도 끈 채로 돌리기" 조합을 막게 되어 기각.

## 제약 / 합의 사항
- 기술적 제약:
  - 앱이 ad-hoc 서명이라 권한 헬퍼 설치 방식 전부 사용 불가
  - `pmset -a disablesleep` 은 `man pmset` 에 문서화되지 않은 비공식 플래그
  - `disablesleep` 값은 재부팅해도 유지된다. 프로세스가 아니라 시스템 설정이므로
    앱이 죽어도 잔류한다. 기존 `caffeinate`(자식 프로세스)와 성질이 다르다.
- 사용자가 명시한 선호:
  - 버튼 1개, 시작/중지만 나타낼 것
  - 주의사항을 반드시 적을 것. 단 프로그램이 강제하는 것이 아니라 사용자가 지킬 것으로.

## 관련 자료
- `Sources/MyMacTools/BlackWorkManager.swift` — 기존 "화면 끄고 작업" 구현.
  `Process` 로 `/usr/bin/caffeinate`, `/usr/bin/pmset displaysleepnow` 실행. 둘 다 root 불필요.
  `CGDisplayIsAsleep` 로 실제 화면 상태를 확인하는 패턴이 이 작업의 상태 판정 방식의 선례다.
- `Sources/MyMacTools/Localization.swift`, `docs/i18n-design.md` — 문자열 추가 시 따라야 할 구조.
  `Bundle.module` 을 쓰지 않고 `Contents/Resources/*.lproj` 를 `Bundle.main` 으로 읽는 이유가 적혀 있다.
- `scripts/build-app.sh` — `.lproj` 번들링과 ad-hoc `codesign` 단계.
