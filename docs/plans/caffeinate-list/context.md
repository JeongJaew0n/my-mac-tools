# context — caffeinate-list

## 원 요청 (2026-09-21)

> 카페인 전부 종료하고, 현재 실행중인 카페인을 목록으로 볼 수 있게 '잠자기 방지'의 아래쪽에
> '> 현재 실행중인 카페인'을 표시하고, 저길 누르면 목록이 나오고, 거기서 실행중인 카페인을
> 보여줘. 그리고 그 카페인의 우클릭하면 중지하기가 보이도록 해줘. 그리고 해당 카페인이
> i옵션 t 옵션 이런거 켜져있는지도. 그리고 옵션들 호버시 무슨옵션인지 설명도.

범위·배지·조회 방식은 물어서 정했다.

## 이 요청이 나온 배경 — 오해였다

며칠간 앱을 재설치할 때마다 `caffeinate -i -t 300` 이 살아 있어서, **MyMacTools 가 종료 시
자기 프로세스를 정리하지 못하고 고아로 흘린다**고 판단했다. 사용자에게도 그렇게 보고했다.

틀렸다. 부모를 따라가 보니 이렇게 나왔다.

```
caffeinate -i -t 300  (pid 63888)
  ← 부모 33399  /Users/jjw/.local/share/claude/versions/2.1.276 --session-id ...
  ← 부모 33342  ClaudeCode.app/Contents/MacOS/claude
  ← 부모 1      launchd
```

**Claude Code 세션이 띄운 것**이고 5분마다 갱신된다. 그래서 죽여도 계속 되살아났다.
앱은 자기 caffeinate 를 제대로 정리하고 있었다.

이 오해 자체가 기능의 근거다. **부모 프로세스를 같이 보여주지 않으면 사용자도 똑같이
헷갈린다.** 목록에 부모 이름을 넣는 이유가 이것이다.

## 검토 단계에서 실측한 것

`sysctl` 로 프로세스를 열거하고 인자를 읽는 스파이크를 돌렸다.

```
전체 프로세스 열거 (KERN_PROC_ALL)   → 712개, 권한 불필요
내 uid 프로세스 인자 (KERN_PROCARGS2) → ["caffeinate", "-dimsu", "-t", "90"]  읽힘
root 프로세스 인자 (findmybeaconingd) → 읽기 실패 (권한)
caffeinate 플래그 (man caffeinate)    → -d -i -m -s -u -t -w  7개
```

`kinfo_proc` 하나에 `p_comm`(이름) · `p_pid` · `e_ppid` · `e_ucred.cr_uid` 가 다 들어 있다.
부모 이름은 같은 스냅숏에서 `e_ppid` 로 찾으면 되므로 추가 호출이 없다.

## 기각 — `ps` 프로세스를 띄워 파싱

`ps -ax -o pid,ppid,uid,etime,args` 로도 필요한 정보가 전부 나온다 (실측). 구현이 훨씬 짧다.

기각한 이유는 폴링이다. 창이 열려 있는 동안 2~5초마다 `fork`/`exec` 를 하게 된다. 이 앱은
이미 같은 상황에서 반대로 결정한 전례가 두 번 있다 — `ioreg` 를 띄우지 않고 IOKit 을 직접
읽고(`LidWorkManager.readSleepDisabled`), `pmset` 을 띄우지 않고 `CGDisplayIsAsleep` 을
부른다. 그 판단을 뒤집을 이유가 없다.

## 기각 — `pmset -g assertions` 파싱

잠자기를 막고 있는 주체를 pid 와 함께 보여주므로 "무엇이 맥을 깨우고 있나" 에는 오히려 더
정확하다. 하지만 **caffeinate 만 골라낼 수 없고**(bluetoothd 같은 것이 섞인다) **옵션 원문이
없다.** 사용자가 원한 것은 caffeinate 의 `-i` `-t` 이므로 맞지 않는다.

`pmset -g assertions` 를 보여주는 기능은 그 자체로 값어치가 있을 수 있다. 다만 이번 요청의
범위가 아니라 적어만 둔다.

## 기각 — 접힌 상태에서 폴링하지 않기

CPU·배터리에는 낫다. 하지만 이 기능의 목적이 "모르게 돌고 있는 것을 드러내기" 인데 펼쳐야만
보이면 목적을 절반만 달성한다. `sysctl` 은 프로세스를 띄우지 않으므로 5초 폴링이 부담되지
않는다는 것을 실측으로 확인했고, 그래서 배지를 택했다.

## 새로 필요한 L10n 키

| 키 | 쓰임 |
|---|---|
| `caffeine.sectionTitle` | 현재 실행중인 카페인 |
| `caffeine.empty` | 돌고 있는 것이 없습니다 |
| `caffeine.stop` | 중지하기 (우클릭 메뉴) |
| `caffeine.owner.thisApp` | 이 앱 |
| `caffeine.argsUnreadable` | 옵션을 읽을 수 없습니다 (권한) |
| `caffeine.stopDenied` | 다른 사용자가 띄운 것은 중지할 수 없습니다 |
| `caffeine.flag.d` / `.i` / `.m` / `.s` / `.u` / `.t` / `.w` | 호버 설명 7개 |

`ko` · `en` · `ja` 세 파일 모두 채운다. 빠지면 키 이름이 그대로 화면에 나온다.
