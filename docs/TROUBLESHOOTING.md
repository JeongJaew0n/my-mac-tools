# 트러블슈팅

실제로 물렸던 것만 적는다. 추측은 넣지 않는다. 각 항목은 **증상 → 원인 → 확인법 → 대응** 순.

---

## 상태는 "꺼짐"인데 남은 시간이 계속 줄어든다

**증상** — 앱 밖에서 `sudo pmset -a disablesleep 0` 을 돌려 기능을 껐는데, 창의 카운트다운이
멈추지 않고 계속 돌았다. 상태 표시와 남은 시간이 서로 다른 말을 했다.

**원인** — `refreshFromSystem()` 이 `isRunning` 만 갱신하고 티커·`endDate`·`remaining` 은
그대로 뒀다. 이 기능은 전부 "로컬 기억을 믿지 말고 커널의 `SleepDisabled` 를 읽는다"는 원칙
위에 서 있는데, **시간을 재는 부분만 그 원칙 밖에 있었다.**

**확인법**
```bash
# 앱에서 유지 시간을 걸고 시작한 뒤
sudo pmset -a disablesleep 0
ioreg -n IOPMrootDomain -r -d 1 | grep SleepDisabled   # No 인데 창은 여전히 카운트다운
```

**대응** (2026-09-13 수정됨)
- `refreshFromSystem()` 이 커널상 꺼져 있으면 카운트다운을 정리하고 `turnedOnByThisProcess`
  도 내려놓는다.
- 티커를 유지 시간이 없을 때도 돌린다. 카운트다운용만이 아니라 매 초 커널을 읽어 표시를
  현실과 맞추는 역할을 겸한다. 화면이 실제와 어긋날 수 있는 시간이 최대 1초가 된다.
- `tick()` 은 항상 `refreshFromSystem()` 으로 현실을 먼저 확인하고 진행한다.

> 이 클래스의 버그를 또 만들지 않으려면: **이 기능에서 화면에 보이는 모든 값은 커널에서
> 파생돼야 한다.** 앱이 따로 기억하는 값이 생기면 언젠가 어긋난다.

---

## 껐는데 "직접 정지를 눌러주세요" 가 계속 떠 있다

**증상** — 유지 시간이 끝났는데 자동 해제에 실패해 빨간 안내가 떴다. 안내대로 정지를
눌러 껐는데도 그 문구가 사라지지 않았다.

**원인** — `autoStopFailed` 를 `false` 로 되돌리는 곳이 "켤 때" 하나뿐이었다.
끌 때도, 밖에서 꺼졌을 때도 내려놓지 않아 꺼진 상태에 켜졌을 때의 문구가 남았다.
바로 위 항목과 같은 클래스다 — **켜져 있을 때만 의미가 있는 값이 꺼진 뒤에도 살아 있었다.**

**확인법** — 코드에서 플래그를 세우는 곳과 내리는 곳의 수를 세어 본다. 내리는 경로가
세우는 경로보다 적으면 거의 항상 이 버그다.

**대응** (2026-09-15 수정) — `refreshFromSystem()` 이 꺼진 것을 확인하면
카운트다운·실패 표시·소유권을 **한곳에서 전부** 내려놓는다. 경로마다 따로 지우지 않는다.

---

## `sudo -n -l` 로는 "암호 없이 되는지" 판정할 수 없다

**증상** — sudoers 규칙이 제대로 안 깔렸는데도 설치 스크립트가 "OK, 암호 없이 실행할 수
있습니다" 라고 보고했다. 앱 쪽 판정 코드도 같은 함정에 빠져 있었다.

**원인** — `sudo -l` 은 "이 명령이 **허용되는가**" 를 보지, "**암호 없이** 되는가" 를 보지
않는다. 관리자 계정은 `%admin ALL=(ALL) ALL` 에 걸리므로 무엇이든 통과한다. 게다가 한 번
통과하면 자격 캐시가 생겨 그 뒤로는 전부 통과한다.

**확인법** — 규칙에 없는 명령으로 재보면 드러난다.
```bash
sudo -k                       # 자격 캐시부터 비운다. 안 비우면 전부 통과한다
sudo -n -v                    # → "a password is required" (캐시 없음 확인)
sudo -n -l /bin/ls; echo $?   # → 0.  /bin/ls 는 규칙에 없는데도 통과한다
```

**대응** — 실제로 실행해봐야만 알 수 있다. **현재 값을 그대로 다시 쓰는 무해한 명령**으로
판정한다. 상태가 바뀌지 않으므로 프로브로 안전하다.
```bash
CUR=$(ioreg -n IOPMrootDomain -r -d 1 | awk -F'= ' '/SleepDisabled/{gsub(/[ "]/,"",$2);print $2}')
[ "$CUR" = "Yes" ] && SAME=1 || SAME=0
sudo -k
sudo -n /usr/bin/pmset -a disablesleep "$SAME"   # 이게 성공해야 진짜 암호 없이 되는 것
```

> 규칙 범위를 검사할 때도 마찬가지다. `sudo -k` 를 **매 시도마다** 넣지 않으면 첫 허용
> 명령이 캐시를 만들어 그 뒤 전부 ALLOW 로 보인다.

---

## `caffeinate` 로는 덮개 닫기 잠자기를 못 막는다

**증상** — `caffeinate -i` 를 띄워뒀는데도 덮개를 닫으면 잠들었다.

**원인** — 덮개 닫기는 유휴 잠자기가 아니라 **강제 잠자기 경로**라 assertion
(`-d/-i/-m/-s/-u`)이 무시된다. `pmset -a disablesleep` 만이 이를 막는다.
`man pmset` 에 문서화되지 않은 비공식 플래그다.

**확인법**
```bash
pmset -g log | grep -i 'Clamshell Sleep'   # caffeinate 가 떠 있던 시각에도 기록이 남는다
```

---

## `disablesleep=1` 이면 "끝나면 Mac잠자기 모드"가 조용히 실패한다

**증상** — 유지 시간이 끝나도 맥이 안 잠들었다. 오류도 안 보였다.

**원인** — `pmset sleepnow` 가 `kIOReturnNotPermitted` (`0xe00002e2`) 로 거부된다.
`BlackWorkManager.run()` 은 실행 실패만 잡고 종료 코드를 보지 않아 아무것도 표면화되지 않았다.

**확인법**
```bash
sudo pmset -a disablesleep 1
sudo pmset sleepnow            # → Unable to sleep system: error 0xe00002e2
sudo pmset -a disablesleep 0
```

**대응** — 덮개 기능이 켜지면 해당 토글을 비활성화하고, 켜는 데 성공하면 값도 함께 내린다.
화면 슬립(`pmset displaysleepnow`)은 영향받지 않으므로 두 기능의 동시 실행 자체는 문제없다.

---

## `AppleClamshellCausesSleep` 값을 믿지 말 것

**증상** — `ioreg` 에서 `AppleClamshellCausesSleep = No` 로 읽혀 "덮개를 닫아도 안 자겠구나"
라고 판단했는데 실제로는 잤다. (다른 시점에 읽으니 `Yes` 였다.)

**원인** — 순간 상태값이라 판정 근거로 쓸 수 없다.

**대응** — 실제 잠자기 기록으로 판단한다.
```bash
pmset -g log | grep -i 'Clamshell Sleep' | tail -5
```

---

## 덮개를 열 때 암호를 묻는 건 잠자기가 아니다

**증상** — 외장 모니터를 연결한 채 기능을 켜고, 덮개를 닫고, **닫힌 상태에서 외장 모니터를
뽑았다.** 다시 열었더니 암호를 요구했다. 잠들어버린 줄 알았다.

**원인** — 화면 잠금은 **디스플레이가 꺼지는 것**을 기준으로 걸린다. 시스템 잠자기와
무관하다. 덮개를 닫으면 내장 화면이 꺼지고 외장까지 뽑으면 출력 장치가 0개가 되므로,
설정된 지연 뒤 잠금이 걸린다. 볼 수 있는 화면이 하나도 없으니 잠든 것처럼 보일 뿐이다.

**확인법** — 실제로 잤는지는 암호 화면이 아니라 이 둘로 판정한다.
```bash
sysctl -n kern.waketime            # 마지막으로 깨어난 시각. 잤다 깼으면 갱신돼 있어야 한다
pmset -g log | awk '$4=="Sleep"'   # 해당 구간에 Sleep 기록이 있는지
sysadminctl -screenLock status     # 잠금 지연. 이 맥은 60초
```

실측 (2026-09-14) — 11:34~12:54 덮개를 닫아둔 구간에 **Sleep 기록 0건**, `waketime` 은
09:33:48 그대로였다. 같은 구간 powerd 로그 215줄에 Claude·cloudd·coreaudiod 활동이 끊기지
않고 찍혔고, 12:52 에는 cloudd 가 `NSURLSessionTask` 를 완료했다. 12:54:30 에 powerd 가
"화면이 켜져 있어 잠자기 방지" assertion 을 **3시간 20분 41초** 만에 놓았다 — 그동안 내내
깨어 있었다는 뜻이다.

**대응** — 고치지 않는다. 자리를 비운 사이 화면이 잠기는 건 의도된 보안 동작이고, 앱이
전역 잠금 설정을 건드려서는 안 된다. 화면 잠금은 `loginwindow` 가 화면을 덮는 것일 뿐
프로세스를 멈추지 않는다.

> **화면에 그리는 일은 예외일 수 있다.** 디스플레이가 0개면 WindowServer 가 렌더링할
> 대상이 없다. 화면 캡처·좌표 기반 자동화가 이 조건에서 어떻게 되는지는 확인하지 않았다.
> 페이지를 직접 조작하는 브라우저 자동화는 아래 Chrome 항목에서 문제없음이 확인됐다.
> CPU·네트워크·파일 작업은 위 실측대로 영향 없다.

---

## 덮개를 닫아도 Chrome 은 계속 돈다 (확인됨 — 문제 아님)

**의문** — OS 가 안 자는 것과 별개로, **Chrome 은 보이지 않는 탭의 타이머를 스스로
throttle** 한다. 덮개를 닫으면 창이 가려지므로, 브라우저 안에서 돌던 작업만 조용히
멈추는 것 아니냐는 의심이 있었다. `caffeinate` 나 `disablesleep` 로는 막을 수 없는
영역이라 따로 확인이 필요했다.

**테스트** (2026-09-15, 사용자 직접 수행)
1. AI 에게 임의의 웹사이트에 들어가 페이지를 조작하도록 지시
2. 조작이 진행되는 중에 덮개를 닫음

**결과** — **문제 없었다.** 덮개를 닫은 상태에서도 Chrome 동작이 유지됐다.

**범위** — 이 테스트가 확인한 것은 **브라우저 자동화가 페이지를 실제로 조작하는 경로**다.
`setTimeout`/`setInterval` 의 지연이 얼마나 벌어지는지를 수치로 잰 것은 아니다. 타이머
간격에 민감한 작업이라면 그건 따로 재야 한다.

```js
// 타이머 지연을 재야 할 때. 덮개 닫기 전에 콘솔에 붙여둔다.
window.__t = []; setInterval(() => window.__t.push(Date.now()), 1000);
// 연 뒤: 간격이 1초에서 얼마나 벌어졌는지 본다
window.__t.map((v,i,a) => i && v-a[i-1]).filter(d => d > 2000);
```

---

## 덮개를 닫았는지 나중에 확인하는 법

테스트 후 "정말 닫았던 게 맞나" 를 뒤늦게 확인해야 할 때가 있다.

```bash
pmset -g assertions | grep -i lidopen
# 유지 시간(00:08:02 같은)이 곧 "그 시각부터 계속 열려 있었다" 는 뜻이다.
pmset -g log | grep -i lidopen | tail -3
# Created 시각 = 덮개가 열린 시각. 그 전까지 닫혀 있었다는 뜻.
```

한 번은 이걸 안 보고 "패킷 손실 0" 만 보고 통과로 오판할 뻔했다. 관측 구간 내내 덮개가
열려 있었으므로 아무것도 검증하지 못한 측정이었다.

---

## 스크립트 안내 문구에 상대 경로를 쓰지 말 것

**증상** — `sudo bash scripts/install-sudoers.sh` 를 복사해 실행했더니
`No such file or directory`. 두 번 겪었다.

**원인** — 레포 루트가 아닌 디렉터리에서 실행하면 상대 경로가 깨진다.

**대응** — 스크립트가 자기 위치를 절대 경로로 풀어서 안내한다.
```bash
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
```

---

## cmux 알림이 안 온다 — 집중 모드부터 확인할 것

**증상** — Claude Code 턴이 끝나도 배너가 안 뜬다. 다른 앱을 보고 있어도 안 뜬다.
시스템 설정 > 알림에 cmux 는 등록돼 있고 켜져 있다.

**원인** — macOS **집중 모드**가 켜져 있었다. cmux·훅·알림 파이프라인은 전부 정상이었다.

**확인법** — 셸에서는 확인할 수 없다. `~/Library/DoNotDisturb/DB/` 는 TCC 로 막혀 있고
(`Operation not permitted`), `defaults read com.apple.ncprefs` 는 이 머신에서 도메인이 없다고 나온다.
제어 센터를 눈으로 봐야 한다.

**대응** — cmux 알림 문제는 이 순서로 좁힌다.

1. **집중 모드** 켜져 있는지 (제어 센터)
2. 시스템 설정 > 알림 > cmux 의 **알림 스타일이 "없음"이 아닌지**.
   허용만 켜져 있고 스타일이 "없음"이면 소리·배지만 오고 배너는 안 뜬다.
3. 표시 경로 생존 확인 — **비포커스** 워크스페이스로 쏜다. 포커스된 pane 으로 보내면
   정상 동작으로도 회수되어 판정이 안 된다.
   ```bash
   cmux list-workspaces
   cmux notify --workspace workspace:N --title TEST --body "표시 경로 확인"
   sleep 1; cmux list-notifications | head -3
   ```
4. 실제 조건 배너 확인 — 지연 발송하고 **다른 앱으로 전환한 뒤** 본다.
   cmux 가 최전면이면 macOS 가 배너를 억제하므로 포그라운드 테스트는 무의미하다.
   ```bash
   sleep 15; cmux notify --title "Claude Code" --subtitle Waiting --body "실제 조건 테스트"
   ```

1·2 번은 도구로 확인이 안 된다는 이유로 뒤로 미루면 안 된다. 그 바람에 3·4 번과 훅 계측까지
전부 하고 나서야 원인에 도달했다.

---

## cmux 알림 진단에서 하지 말 것

**증상** — 알림이 안 뜨는 걸 고치려다 더 나빠졌다.

**원인·대응** — 세 가지를 물렸다.

- **`osascript` 로 대체 배너를 띄우려 하지 마라.** `display notification` 은 "스크립트 편집기"
  이름으로 뜨는데 그 앱에 알림 권한이 없으면 **exit 0 으로 조용히 아무것도 안 한다.**
  알림 훅에서 `desktop:false` 로 cmux 정품 배너까지 끄고 이걸로 대체하면 알림이 완전히 사라진다.
  cmux 는 이미 권한이 있으니 cmux 경로를 살려야 한다.
- **`cmux set-app-focus inactive` 로 배너 유무를 판정하지 마라.** cmux 내부 판단만 흉내 낼 뿐
  실제 macOS 배너 전달에는 영향이 없다. 이걸로 "고쳐졌다"고 결론내면 틀린다.
- **`cmux hooks claude notification` 을 손으로 쏴서 판정하지 마라.** 세션이 Running 인 동안에는
  드롭돼서 `OK` 만 나오고 알림이 안 생긴다. 결론을 낼 수 없다.

**참고** — 포커스된 pane 의 알림 기록이 사라지는 건 정상이다. 확인하러 cmux 로 돌아와
그 pane 에 포커스를 주는 순간 회수된다. 버그로 오판하지 말 것.

알아두면 되는 cmux 설정 (`~/.config/cmux/cmux.json`):

| 키 | 기본값 | 의미 |
|---|---|---|
| `notifications.suppressOnlyFocusedSurface` | `false` | `false` 면 **워크스페이스가 화면에 보이기만 해도** 배너를 회수한다. cmux 가 백그라운드여도 그렇다. 에이전트를 여러 pane 에 띄우면 옆 pane 알림을 놓치므로 `true` 권장 |
| `notifications.agentTurnComplete` | `whenIdle` | 백그라운드 작업이 남으면 미룬다. 매 턴 끝마다 원하면 `always` |
| `notifications.agentIdleReminder` | `true` | 턴 종료 약 60초 후 "입력 대기" 알림 |
| `notifications.agentPermissionPrompt` | `true` | 권한 대기 알림. `--dangerously-skip-permissions` 세션에는 해당 없음 |

`--dangerously-skip-permissions` 세션은 "Permission" 알림이 원천적으로 안 온다.
Claude Code 훅은 cmux 래퍼(`/Applications/cmux.app/Contents/Resources/bin/claude`)가 `--settings`
로 주입하므로 `~/.claude/settings.json` 에 훅이 없어도 정상이다.
