# API — 에이전트가 이 앱을 쓰는 법

Claude Code 같은 에이전트가 셸에서 MyMacTools 의 기능을 쓸 수 있다. 상태를 읽고, Tool 을
켜고 끄고, 카페인·포트 목록을 받아간다.

설계 근거와 기각한 대안은 `docs/plans/agent-api/`.

## 빠른 시작

```bash
scripts/mymactools status
scripts/mymactools ports.list category=system
scripts/mymactools ports.list search=8501
scripts/mymactools sleep.start hours=1 screenMode=keepOn
scripts/mymactools ports.stop pid=12345
```

앱이 떠 있어야 한다. 안 떠 있으면 클라이언트가 그렇게 말하고 종료 코드 1 을 준다.

```bash
open -a MyMacTools
```

## 전송

유닉스 도메인 소켓이다.

```
~/Library/Application Support/MyMacTools/api.sock     권한 0600
```

**포트를 열지 않는다.** 이 앱에는 듣고 있는 포트를 보여주는 Tool 이 있어서 HTTP 서버를
열면 자기 목록에 자기가 나타나고, 포트는 같은 맥의 다른 프로그램에도 열려 있어 토큰이
필요해진다. 소켓 파일의 권한이 그 일을 대신한다 — 이 파일을 열 수 있는 것은 이 사용자뿐이다.

프로토콜은 **줄 단위 JSON** 이다. 요청 한 줄을 보내고 응답 한 줄을 받는다.

```json
{"method":"ports.list","params":{"category":"system"}}
```

```json
{"ok":true,"result":[…]}
{"ok":false,"error":{"code":"forbidden","message":"…"}}
```

`ok` 하나만 보고 갈라내면 된다.

### HTTP 가 아니다

`curl --unix-socket` 은 **유닉스 소켓 위의 HTTP** 를 위한 옵션이라 이 서버에는 통하지
않는다 (빈 응답이 온다). 직접 부를 때는 이렇게 한다.

```bash
SOCK="$HOME/Library/Application Support/MyMacTools/api.sock"

# nc
printf '{"method":"status"}\n' | nc -U "$SOCK"
```

```python
import json, socket

sock = socket.socket(socket.AF_UNIX)
sock.connect("/Users/<너>/Library/Application Support/MyMacTools/api.sock")
sock.sendall(b'{"method":"ports.list"}\n')
data = b""
while not data.endswith(b"\n"):      # 응답이 길면 recv 한 번에 다 오지 않는다
    chunk = sock.recv(65536)
    if not chunk:
        break
    data += chunk
print(json.loads(data)["result"])
```

서버는 연결마다 읽기·쓰기에 **5초 시한**을 둔다. 붙어 놓고 요청을 보내지 않는 연결은 끊긴다
(요청은 차례로 처리하므로, 그런 연결 하나가 뒤의 요청을 모두 막지 않게 한 것이다).

## 메서드

### 읽기

| 메서드 | 파라미터 | 결과 |
|---|---|---|
| `status` | — | 켜고 끄는 Tool 들의 상태 한 번에 |
| `sleep.get` | — | 잠자기 방지 상태·설정 |
| `lid.get` | — | 덮개 상태 (커널의 지금 값으로 갱신 후) |
| `cover.get` | — | 화면 가리기 상태 |
| `caffeinate.list` | — | 돌고 있는 `caffeinate` 전부 |
| `ports.list` | `category` `search` | 듣고 있는 localhost 포트 |
| `speedtest.status` | — | 측정 중인지, 경과 시간, 마지막 결과 |
| `mac.info` | — | 기종·칩·macOS, 메모리·저장공간(바이트), 내부 IP, 마지막으로 확인한 공인 IP |
| `thermal.info` | — | 열 상태(OS 판정)와 센서 온도(°C) — 묶음별 최고·평균, 센서 전체 |
| `intellij.info` | — | IntelliJ 색 — 대상 IntelliJ, 지금 테마, 팔레트, 프리셋 이름 |

`ports.list` 의 `category` 는 `all` · `system` · `wellKnown` · `terminal` · `other` 중 하나다.
`search` 는 숫자만 쓴다 — 문자열이든 숫자든 받고, 포트 번호에 **부분 일치**한다
(`87` 은 `8765` 도 `9876` 도 잡는다). 숫자가 하나도 없으면(`search=http`) `badParams` 다 —
걸러진 것 없이 전체가 나가면 호출자가 엉뚱한 줄을 집기 때문이다.

결과 필드 (값이 없으면 키가 빠지는 것은 따로 적었다):

| 메서드 | 필드 |
|---|---|
| `sleep.get` | `running` `hours` `minutes` `screenMode` `displayDelaySeconds` `sleepWhenDone`, 돌고 있고 시간 제한이 있으면 `remainingSeconds`, 화면 끄기를 기다리는 중이면 `screenOffInSeconds` |
| `lid.get` | `running` `turnedOnByThisApp` |
| `cover.get` | `covering` `fillMode` `imagePath`(고르지 않았으면 `""`) |
| `caffeinate.list` | `pid` `flags`(`"-t 300"` 처럼 값을 붙인 옵션 목록) `utility` `parent` `parentPath` `startedAt` `isThisApp` `canStop` `argsUnreadable` |
| `ports.list` | `port` `pid` `process` `processPath` `addresses` `families` `isSystem` `startedFromTerminal` `isWellKnown` `bundleIdentifier` `canStop` |
| `speedtest.status` | `running` `expensiveNetwork`, 측정 중이면 `elapsedSeconds`, 실패했으면 `error`, 잰 적이 있으면 `latest`(`measuredAt` `downloadMbps` `uploadMbps` `responsivenessRPM` `baseRTTms` `interface` `interfaceType` `endpoint` `usage[]` `secondsPerGigabyteDown` `secondsPerGigabyteUp`) |

`mac.info` 의 숫자는 **바이트**다. 메모리 `usedBytes` 는 활성 상태 보기의 "사용된 메모리",
`pressure` 는 `normal` · `warning` · `critical` (OS 판정), `freePercent` 는
`kern.memorystatus_level`. 저장공간 `availableBytes` 는 Finder 의 "사용 가능" 과 같다.
`addresses` 의 각 줄에 `mac`(지금 쓰는 MAC — 공유기가 보는 값)과 `hardwareMAC`(기기 고유)이
오고, 둘이 다르면 `privateMAC: true` 다(비공개 Wi-Fi 주소).
`publicIP.status` 는 `unknown`(아직 안 물음) · `loading` · `ok`(`address`) · `failed`(`error`).

`thermal.info` 의 `state` 는 `nominal` · `fair` · `serious` · `critical` (`ProcessInfo.thermalState`,
OS 판정). `groups` 는 `{group, maxCelsius, averageCelsius, count}` 이고 `group` 은 `die`(SoC 다이) ·
`pmuDevice` · `ssd` · `battery` 중 센서가 있는 것만 온다. `sensors` 는 `{name, celsius}` 전부(이름순,
같은 이름의 **서로 다른** 센서가 둘씩 올 수 있다 — 중복이 아니다, `count` 는 둘 다 센다). 온도는 소수 한 자리(화면과 같은 반올림). **온도로 뜨겁다 아니다를 판정하지 말고 `state` 를 본다.**
센서를 못 읽으면(비공개 API) `groups`·`sensors` 가 빈 배열이고 `state` 는 그대로 온다.

`intellij.info` 의 `palette` 는 색 역할 → `#RRGGBB` (역할 이름은 `IntelliJThemeTemplate.Role`).
`target` 은 `{name, version, configDir, running}` — IntelliJ 가 없으면 빠진다. `currentTheme` 은
`laf.xml` 의 themeId, `applied` 는 그것이 이 앱의 테마(`mymactools-theme`)인지. `previousTheme` 은
되돌리기가 돌아갈 themeId 로, 이 앱이 적용한 뒤에만 온다.

### 쓰기

| 메서드 | 파라미터 | 비고 |
|---|---|---|
| `sleep.start` | `hours` `minutes` `screenMode` `displayDelaySeconds` `sleepWhenDone` | 모두 선택. **준 것만 바꾸고** 시작한다. 이미 돌고 있으면 **새 설정으로 갈아끼운다** |
| `sleep.stop` | — | |
| `cover.start` | — | 사진을 먼저 골라야 한다 |
| `cover.stop` | — | |
| `caffeinate.stop` | `pid` | 이 앱이 띄운 것이면 매니저를 거친다 |
| `ports.stop` | `pid` | `SIGTERM` |
| `ports.open` | `port` | 기본 브라우저로 `http://localhost:<포트>` |
| `speedtest.start` | — | 인터넷 속도 측정을 **시작만** 하고 곧바로 돌아온다 |
| `speedtest.cancel` | — | 측정을 멈춘다 |
| `mac.publicIP` | — | 공인 IP 를 `api.ipify.org` 에 **묻기만** 하고 곧바로 돌아온다. 결과는 `mac.info` 의 `publicIP` |

`screenMode` 는 `system` · `keepOff` · `keepOn`.
`hours` 0–24, `minutes` 0–50(10 단위), `displayDelaySeconds` 3·5·7·10.

`sleep.start` 는 **형까지 본다.** `hours: "2"`, `hours: 1.5`, `sleepWhenDone: 1` 은 `badParams` 다
(예전에는 조용히 무시돼 시간 제한 없는 세션이 시작될 수 있었다). 값은 **모두 검사한 뒤 한꺼번에**
반영하므로, 거부되면 창의 값도 그대로다. 덮개 기능이 켜져 있을 때 `sleepWhenDone=true` 는
`preconditionFailed` 다 — 그 상태에서는 잠자기가 거부된다. 따로 주지 않았는데 창에 남은 값이
`true` 면 조용히 끈다(창과 같은 규칙).

`caffeinate.stop` · `ports.stop` 의 결과는 `{"stopped": true}` 또는 `{"stopped": false, "reason": "…"}` 다.
끄려 했지만 커널이 거부한 경우(권한 등)가 뒤의 것이다. 클라이언트는 `stopped: false` 를
`[notStopped] 이유` 와 **종료 코드 1** 로 낸다. `ports.open` 의 결과는 `{"opened": "http://localhost:<포트>"}`.

**시간 늘리기**는 `sleep.start` 를 다시 부르면 된다. 멈출 필요가 없다. 주는 시간은
남은 시간에 더해지는 것이 아니라 **지금부터 다시 센다.**

```bash
scripts/mymactools sleep.start hours=2   # 남은 시간과 무관하게, 지금부터 2시간
```

`caffeinate` 가 `-t` 를 도중에 못 바꾸므로 프로세스를 갈아끼운다. 그 찰나에 assertion 이
끊기지만 그 사이에 유휴 잠자기가 일어나지는 않는다.

### 하지 않는 것

| 메서드 | 코드 | 이유 |
|---|---|---|
| `lid.start` · `lid.stop` | `needsHuman` | `pmset` 에 관리자 인증이 필요하다. 에이전트 호출로 암호창이 튀어나오면 사용자는 무엇 때문에 뜬 창인지 알 수 없다 |
| `ports.stop` (시스템 구성요소) | `forbidden` | 앱은 사람에게 한 번 더 묻고 끈다. 호출자에게는 물어볼 화면이 없다 |
| `ports.stop` (이 앱 자신) | `forbidden` | 자기를 끄는 호출이 된다 |
| `speedtest.start` (데이터 요금 회선) | `needsHuman` | 1회에 약 150 MB 를 쓴다. 앱은 사람에게 묻고 시작한다 |
| `intellij.apply` · `intellij.restore` | `needsHuman` | 켜져 있는 IntelliJ 를 끄고 다시 연다. 작업 중인 다른 앱을 에이전트 호출이 끄면 사용자는 왜 꺼졌는지 모른다 |
| `sleep.start sleepWhenDone=true` (덮개 켜짐) | `preconditionFailed` | 덮개 기능이 `disablesleep` 을 켜 두면 `pmset sleepnow` 가 거부된다 |

`ports.list` 의 각 줄에 `canStop` 이 함께 온다. 부르기 전에 걸러낼 수 있다.

## 오류 코드

| 코드 | 뜻 |
|---|---|
| `badRequest` | JSON 이 아니거나 `method` 가 없다 |
| `unknownMethod` | 없는 메서드 |
| `badParams` | 파라미터가 빠졌거나 값이 범위를 벗어났다 |
| `notFound` | 그 pid·포트가 목록에 없다 |
| `forbidden` | 정책으로 막은 것 |
| `needsHuman` | 사람의 인증·확인이 필요한 것 |
| `preconditionFailed` | 조건이 안 맞는다 |
| `internalError` | 그 외 |

클라이언트는 실패하면 stderr 에 `[코드] 메시지` 를 쓰고 **종료 코드 1** 을 준다.
`stopped: false` 도 실패로 친다(`[notStopped]`). stdout 을 파싱하지 않고 종료 코드로 갈라낼 수 있다.
10초 안에 응답이 없으면 그렇게 말하고 종료 코드 1 이다 — 앱이 관리자 암호 창 같은 것을 띄워 둔 채
기다리는 중일 수 있다.

## 에이전트에게 주는 예시

포트를 잡고 있는 프로세스를 찾아 끄기. `search` 는 **부분 일치**라 `3000` 이 `13000` 도 잡는다 —
반드시 포트 번호가 **같은** 줄만 고른다.

```bash
PID=$(scripts/mymactools ports.list search=3000 \
      | python3 -c 'import json,sys; r=[p for p in json.load(sys.stdin) if p["port"] == 3000 and p["canStop"]]; print(r[0]["pid"] if r else "")')
[ -n "$PID" ] && scripts/mymactools ports.stop pid="$PID"
```

긴 빌드 전에 잠자기를 막고, 끝나면 되돌리기.

```bash
scripts/mymactools sleep.start hours=2 screenMode=system
./gradlew build
scripts/mymactools sleep.stop
```

인터넷 속도 재기 — 약 21초가 걸려 **시작과 조회를 나눈다.** 한 번에 기다리면 클라이언트의
10초 타임아웃에 걸린다.

```bash
scripts/mymactools speedtest.start
until ! scripts/mymactools speedtest.status | grep -q '"running": true'; do sleep 3; done
scripts/mymactools speedtest.status
```

공인 IP 도 같은 꼴이다. 보통 1초 안에 온다.

```bash
scripts/mymactools mac.publicIP
sleep 1; scripts/mymactools mac.info
```

모르게 돌고 있는 `caffeinate` 찾기.

```bash
scripts/mymactools caffeinate.list \
  | python3 -c 'import json,sys; [print(p["pid"], p["parent"], p["flags"]) for p in json.load(sys.stdin)]'
```

## MCP 로 감싸려면

이 API 는 셸 호출만으로 쓸 수 있어서 MCP 서버를 따로 두지 않았다. 감싸고 싶으면 각
메서드를 도구 하나로 노출하고 위 python 예시처럼 소켓을 두드리면 된다. 상태를 바꾸는
도구에는 `ports.list` 의 `canStop` 을 먼저 보게 하는 설명을 붙이는 것이 좋다.

## 한계

- **이 맥 안에서만** 쓴다. 원격 접근은 없다
- **물어보는 쪽만 있다.** 상태가 바뀔 때 알려주는 구독은 없다
- 앱이 **샌드박스가 아니라서** 이 경로를 쓴다. 샌드박스를 켜면 소켓이 컨테이너 안으로
  밀려나고 컨테이너 밖의 에이전트가 닿지 못한다 — 샌드박스를 검토하면 이 API 가 먼저 걸린다
