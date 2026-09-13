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
