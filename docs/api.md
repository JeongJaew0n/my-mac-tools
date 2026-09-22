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
print(json.loads(sock.recv(1 << 20))["result"])
```

## 메서드

### 읽기

| 메서드 | 파라미터 | 결과 |
|---|---|---|
| `status` | — | 네 Tool 의 상태 한 번에 |
| `sleep.get` | — | 잠자기 방지 상태·설정 |
| `lid.get` | — | 덮개 상태 (커널의 지금 값으로 갱신 후) |
| `cover.get` | — | 화면 가리기 상태 |
| `caffeinate.list` | — | 돌고 있는 `caffeinate` 전부 |
| `ports.list` | `category` `search` | 듣고 있는 localhost 포트 |

`ports.list` 의 `category` 는 `all` · `system` · `wellKnown` · `terminal` · `other` 중 하나다.
`search` 는 숫자만 쓴다 — 문자열이든 숫자든 받고, 포트 번호에 **부분 일치**한다
(`87` 은 `8765` 도 `9876` 도 잡는다).

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

`screenMode` 는 `system` · `keepOff` · `keepOn`.
`hours` 0–24, `minutes` 0–50(10 단위), `displayDelaySeconds` 3·5·7·10.

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
stdout 을 파싱하지 않고 종료 코드로 갈라낼 수 있다.

## 에이전트에게 주는 예시

포트를 잡고 있는 프로세스를 찾아 끄기.

```bash
PID=$(scripts/mymactools ports.list search=3000 \
      | python3 -c 'import json,sys; r=json.load(sys.stdin); print(r[0]["pid"] if r else "")')
[ -n "$PID" ] && scripts/mymactools ports.stop pid="$PID"
```

긴 빌드 전에 잠자기를 막고, 끝나면 되돌리기.

```bash
scripts/mymactools sleep.start hours=2 screenMode=system
./gradlew build
scripts/mymactools sleep.stop
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
