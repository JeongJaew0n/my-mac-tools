# research — localhost-list

> 조사만 한 문서다. `spec.md` · `checklist.md` 는 아래 *결정이 필요한 축* 을 사용자와
> 확정한 뒤에 쓴다. 아직 무엇을 만들지 정해진 것이 없어 미리 쓰지 않는다.

## 원 요청 (2026-09-21)

> 그리고 실행중인 localhost 확인하는 것도 만들 수 있어? 조사해서 문서로 남겨.

## 결론

**만들 수 있다.** 권한도, 외부 프로세스도, 사설 API 도 필요 없다. 카페인 목록과 같은
구조(`sysctl` + `libproc` 직접 호출)로 짜면 되고, 비용은 카페인 목록보다도 싸다.

## 실측한 것

### 되는 방식 — `libproc` 직접 호출

```
sysctl(KERN_PROC_ALL)                         → 전체 프로세스
proc_pidinfo(pid, PROC_PIDLISTFDS)            → 그 프로세스의 fd 목록
proc_pidfdinfo(pid, fd, PROC_PIDFDSOCKETINFO) → fd 하나의 소켓 정보
  soi_kind == SOCKINFO_TCP
  soi_proto.pri_tcp.tcpsi_state == TSI_S_LISTEN   ← 듣고 있는 것만
  tcpsi_ini.insi_lport / insi_laddr / insi_vflag  ← 포트 · 주소 · IPv4/IPv6
```

이게 `lsof` 가 root 없이 쓰는 것과 같은 경로다. 실측 결과가 `lsof` 와 **정확히 일치**했다.

```
libproc : LISTEN 소켓 20개
lsof -iTCP -sTCP:LISTEN -P -n : 20개
```

주소·포트·프로세스까지 다 나온다.

```
IPv4  127.0.0.1:8501    python3.12 (pid 13012)
IPv4  127.0.0.1:5037    adb (pid 16872)
IPv4  127.0.0.1:6463    Discord Helper (Renderer) (pid 11259)
IPv4  0.0.0.0:7000      ControlCenter (pid 758)
IPv6  ::1:42050         OneDrive Sync Service (pid 2954)
```

이름은 `lsof` 보다 낫다. `lsof` 는 9자로 잘라 `Code\x20H`, `Discord` 로 보여주는데,
`proc_pidpath` 는 `Code Helper (Plugin)`, `Discord Helper (Renderer)` 를 준다.

### 비용 — 무시할 수 있다

```
프로세스 ~200개 전수 조회 3회 반복 → 매번 real 0.00s (5ms 미만)
```

카페인 목록이 쓰는 `KERN_PROCARGS2` 보다 싸다. 폴링 주기를 훨씬 짧게 잡아도 된다.

### 권한 — 필요 없다. 단 **내 uid 것만 보인다**

```
fd 목록 조회가 거부된 프로세스: 188개 (root 등 다른 사용자 소유)
```

`PROC_PIDLISTFDS` 는 같은 uid 의 프로세스만 읽힌다. root 데몬이 듣고 있는 포트는
목록에 안 나온다. `lsof` 를 root 없이 돌렸을 때도 똑같이 20개라 동작이 일치한다.

개발용으로는 이게 오히려 맞다 — 내가 띄운 개발 서버가 전부 내 uid 소유다.

### 이름은 두 경로가 필요하다

`proc_pidpath` 가 실패하는 프로세스가 있다.

```
pid 11100: proc_pidpath 실패,  p_comm = "ChatGPT for Chro"   ← 16자로 잘림
```

카페인 목록이 이미 쓰는 대체 순서(`NSRunningApplication` → `.app` 번들 이름 →
경로 조각 → `p_comm`)를 그대로 재사용하면 된다. `CaffeinateScanner.friendlyName` 을
공용으로 빼는 것이 자연스럽다.

### 곁가지로 보이는 것들

소켓 종류 분포 (전체 프로세스, 내 uid).

```
UNIX 437개 · TCP 95개 · KERN_CTL 81개 · IN(UDP 등) 30개 · KERN_EVENT 1개 · GENERIC 1개
```

- **TCP 95개** 중 LISTEN 이 20개다. 나머지는 연결된 소켓이다. 연결 수를 세어
  "이 포트에 몇 개가 붙어 있나" 를 보여줄 수도 있다.
- **UDP(`SOCKINFO_IN`)** 도 포트가 잡힌 것이 26개 나온다 (`5353` mDNS 등). UDP 는
  LISTEN 상태가 없어 "듣고 있다" 를 TCP 처럼 판정할 수 없다. 포함하려면 기준을
  따로 정해야 한다.
- **UNIX 도메인 소켓 437개** 는 포트가 없다. localhost 라는 말과 어긋나므로 범위에서
  빠지는 쪽이 자연스럽다.

## 결정이 필요한 축

| 축 | 갈리는 지점 |
|---|---|
| **localhost 의 정의** | `127.0.0.1`·`::1` 만인가, `0.0.0.0`·`::`(모든 인터페이스, 그래서 localhost 로도 닿는다)도 넣나. 실측한 20개 중 4개가 `0.0.0.0`/`::` 였다 |
| **UDP 포함 여부** | TCP 만인가. UDP 는 LISTEN 이 없어 "바인드된 것" 을 보여주는 다른 기준이 필요하다 |
| **IPv4/IPv6 중복** | 같은 포트가 IPv4·IPv6 두 줄로 나온다(`ControlCenter:7000` 등). 합쳐 한 줄로 볼지 |
| **무엇을 하게 하나** | 보기만 / 브라우저로 열기(`NSWorkspace.open`) / 프로세스 종료(`SIGTERM`, 같은 uid 라 통한다) |
| **HTTP 인지 판별** | 열기 버튼을 주려면 HTTP 서버인지 알아야 자연스럽다. 판별하려면 **실제로 요청을 보내야** 한다 — 내 맥의 서버에 앱이 말을 거는 것이라 별도 판단이 필요하다 |
| **갱신 주기** | 5ms 라 짧게 잡아도 되지만, 카페인 목록과 같은 규칙(창 보일 때만)을 쓰는 것이 일관된다 |
| **배치** | **새 Tool 인가.** 카페인 목록은 "잠자기 방지" 안에 들어갔지만, 포트는 잠자기와 무관하다. `CLAUDE.md` 규칙상 먼저 정해야 한다 |

## 기각 후보

**`lsof` 를 띄워 파싱** — 한 줄이면 되고 root 로 올리면 남의 포트까지 본다. 그러나
폴링마다 `fork`/`exec` 이고, `lsof` 는 이름을 9자로 잘라 `Code\x20H` 처럼 준다.
이 앱은 `ioreg`·`pmset`·`ps` 를 모두 직접 호출로 대체한 전례가 세 번 있다.

**`netstat -an`** — 포트는 보이지만 **pid 와 프로세스 이름이 없다.** "무엇이 8501 을
잡고 있나" 가 이 기능의 핵심이라 쓸 수 없다.

**`NWBrowser` / Bonjour** — 광고하는 서비스만 보인다. 개발 서버는 대개 광고하지 않는다.

## 미확인

- **root 소유 리스너가 실제로 얼마나 있는지.** `sudo -n` 이 암호를 요구해 확인하지
  못했다. 목록에 안 나오는 것이 얼마나 아쉬운지는 그 수를 봐야 판단된다.
- **샌드박스.** 이 앱은 샌드박스가 아니라서 위 호출이 다 된다. 나중에 샌드박스를 켜면
  `PROC_PIDLISTFDS` 가 막힐 가능성이 크다. 켤 계획이 생기면 먼저 확인해야 한다.


---

# 추가 조사 — "함부로 끄면 안 되는 것" 을 표시할 수 있는가 (2026-09-21)

## 원 요청

> 근데 내가 띄운것과 진짜 맥에서 시스템이 필요한것, 어떤 프로그램이 필요에 의해서 띄운것,
> well-known port등은 함부로 끄면 안되잖아. 이런거 표시 가능?

## 결론 — 일부만 가능하다

| 표시 | 근거 | 신뢰도 |
|---|---|---|
| **시스템(Apple)** | 코드 서명의 플랫폼 식별자 | **확실** |
| **서명 주체** | 번들·팀 식별자 | **확실** |
| **well-known 포트** | 포트 < 1024 (IANA) | **확실** |
| **내 터미널에서 띄움** | 제어 터미널 보유 (`kp_eproc.e_tdev != -1`) | **있으면** 확실, 없으면 모름 |
| ~~내가 띄운 것 vs 앱이 띄운 것~~ | — | **불가능** |

## 되는 것 — 실측

`SecCodeCopyGuestWithAttributes` → `SecCodeCopyStaticCode` → `SecCodeCopySigningInformation`.
공개 API 이고 권한이 필요 없다.

```
/usr/libexec/rapportd                          com.apple.rapportd        플랫폼바이너리 true
/System/…/ControlCenter.app/…/ControlCenter    com.apple.controlcenter   플랫폼바이너리 true
/Applications/Raycast.app/…/Raycast            com.raycast.macos         팀 SY64MV22J9, false
```

제어 터미널도 읽힌다.

```
pid 13012 python3.12  제어 터미널 있음   사슬: zsh ← Code Helper ← Code ← launchd
pid 758   ControlCenter  없음            사슬: launchd(1)
```

## 안 되는 것 — "누가 띄웠나"

신호가 셋 다 우회된다.

```
pid 16872 adb   제어 터미널 없음  부모 launchd(1)  ← 내가 띄웠는데 못 알아낸다
pid 11370 java  제어 터미널 없음  부모 launchd(1)  ← gradle 데몬. 같음
```

`adb` 와 gradle `java` 는 **사용자가 띄웠지만** 스스로 daemonize 해서 터미널을 놓고
부모가 launchd 로 바뀐다. 시스템 데몬과 구별되지 않는다.

**서명으로도 안 된다.** 테스트로 띄운 `python3 -m http.server` 가 `com.apple.python3` 로
서명돼 있었다. 서명은 *누가 만들었나*이고 *누가 띄웠나*가 아니다.

그래서 "내가 띄운 것 / 앱이 필요해서 띄운 것" 이라는 **단정은 앱이 뒷받침할 수 없다.**
그 라벨을 달면 틀린 확신을 준다. 근거가 확실한 것만 라벨로 달고, 나머지는 번들 식별자를
그대로 보여주어 판단을 사용자에게 남긴다.

## 비용 — 캐시가 필요하다

```
서명 조회 17개:        24~64ms   ← 2초 폴링마다 부르면 메인 스레드가 걸린다
pid 캐시 후 재조회 2회:  4.4ms
```

살아 있는 pid 의 서명은 바뀌지 않으므로 pid 별로 캐시한다. 못 읽은 것(nil)도 캐시해야
매번 다시 두드리지 않는다. 죽은 pid 는 스캔마다 버린다.

## 탐색하지 않은 것

macOS 는 TCC 를 위해 프로세스의 **responsible pid** 를 따로 들고 있다. daemonize 뒤에도
원래 띄운 주체를 가리킬 가능성이 있지만 사설 API 다. 공개 API 로 "누가 띄웠나" 를 알
방법은 찾지 못했다.
