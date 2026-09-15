# cmux 알림(Claude Code 턴 완료·입력 대기 배너)이 뜨지 않는다

## 환경

- macOS 26 (Darwin 25.3.0)
- cmux 0.64.12
- Claude Code (cmux 래퍼가 `--settings` 로 훅을 주입하는 구성)

## 증상

Claude Code 턴이 끝나도, 다른 앱을 보고 있어도 배너가 뜨지 않는다.
시스템 설정 > 알림에 cmux 는 등록돼 있고 알림 허용도 켜져 있다.

`cmux list-notifications` 에 기록도 남지 않아서 cmux 쪽 고장처럼 보인다.

## 원인

**macOS 집중 모드가 켜져 있었다.** cmux·훅·알림 파이프라인은 전부 정상이었다.

원인을 찾는 데 오래 걸린 이유는 진단 순서가 틀려서다. 집중 모드는 셸로 확인할 수 없다 —
`~/Library/DoNotDisturb/DB/` 는 TCC 로 막혀 있어 `Operation not permitted` 가 나고,
`defaults read com.apple.ncprefs` 는 도메인이 없다고 나온다. **도구로 확인이 안 된다는
이유로 뒤로 미루는 바람에**, cmux 훅 주입 경로와 알림 파이프라인을 전부 계측하고 나서야
도달했다.

## 해결

집중 모드를 끈다. 진단은 이 순서로 한다 — **1·2 번을 먼저 사람에게 묻는다.**

1. **집중 모드**가 켜져 있는지 (제어 센터)
2. 시스템 설정 > 알림 > 해당 앱의 **알림 스타일이 "없음"이 아닌지**.
   허용만 켜져 있고 스타일이 "없음"이면 소리·배지만 오고 배너는 안 뜬다.
3. 표시 경로가 살아 있는지 — **비포커스** 워크스페이스로 쏜다.
   포커스된 pane 으로 보내면 정상 동작으로도 회수되어 판정이 안 된다.
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

### 통하지 않은 시도

- **`osascript` 로 대체 배너를 띄우기.** `display notification` 은 "스크립트 편집기" 이름으로
  뜨는데 그 앱에 알림 권한이 없으면 **exit 0 으로 조용히 아무것도 안 한다.** 알림 훅에서
  `desktop:false` 로 cmux 정품 배너까지 끄고 이걸로 대체하면 알림이 완전히 사라진다.
  cmux 는 이미 권한이 있으니 cmux 경로를 살려야 한다.
- **`cmux set-app-focus inactive` 로 판정하기.** cmux 내부 판단만 흉내 낼 뿐 실제 macOS 배너
  전달에는 영향이 없다. 이걸로 "고쳐졌다"고 결론내면 틀린다.
- **`cmux hooks claude notification` 을 손으로 쏘기.** 세션이 Running 인 동안에는 드롭돼서
  `OK` 만 나오고 알림이 안 생긴다. 결론을 낼 수 없다.

### 오판하기 쉬운 정상 동작

포커스된 pane 의 알림 기록이 사라지는 건 정상이다. 확인하러 cmux 로 돌아와 그 pane 에
포커스를 주는 순간 회수된다.

## 재발 방지

`~/.config/cmux/cmux.json` 에 아래를 넣었다. 집중 모드와는 별개 문제로, 기본값이면 보고 있는
워크스페이스 안의 **다른** pane 알림까지 같이 회수되어 옆 pane 알림을 놓친다.

```jsonc
"notifications": {
  "suppressOnlyFocusedSurface": true
}
```

관련 설정:

| 키 | 기본값 | 의미 |
|---|---|---|
| `notifications.suppressOnlyFocusedSurface` | `false` | `false` 면 **워크스페이스가 화면에 보이기만 해도** 배너를 회수한다. cmux 가 백그라운드여도 그렇다 |
| `notifications.agentTurnComplete` | `whenIdle` | 백그라운드 작업이 남으면 미룬다. 매 턴 끝마다 원하면 `always` |
| `notifications.agentIdleReminder` | `true` | 턴 종료 약 60초 후 "입력 대기" 알림 |
| `notifications.agentPermissionPrompt` | `true` | 권한 대기 알림 |

`--dangerously-skip-permissions` 세션은 "Permission" 알림이 원천적으로 안 온다.
Claude Code 훅은 cmux 래퍼(`<cmux.app>/Contents/Resources/bin/claude`)가 `--settings` 로
주입하므로 `~/.claude/settings.json` 에 훅이 없어도 정상이다.

문서: `cmux docs settings`, `cmux docs agents`, `cmux config doctor`
