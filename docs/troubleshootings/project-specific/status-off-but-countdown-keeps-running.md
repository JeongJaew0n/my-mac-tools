# 상태는 "꺼짐"인데 남은 시간이 계속 줄어든다

## 증상

앱 밖에서 `sudo pmset -a disablesleep 0` 을 돌려 기능을 껐는데, 창의 카운트다운이 멈추지
않고 계속 돌았다. 상태 표시와 남은 시간이 서로 다른 말을 했다.

```bash
# 앱에서 유지 시간을 걸고 시작한 뒤
sudo pmset -a disablesleep 0
ioreg -n IOPMrootDomain -r -d 1 | grep SleepDisabled   # No 인데 창은 여전히 카운트다운
```

## 원인

`LidWorkManager.refreshFromSystem()` 이 `isRunning` 만 갱신하고 티커·`endDate`·`remaining`
은 그대로 뒀다.

이 기능은 전부 "로컬 기억을 믿지 말고 커널의 `SleepDisabled` 를 읽는다" 는 원칙 위에 서
있는데, **시간을 재는 부분만 그 원칙 밖에 있었다.**

## 해결

2026-09-13 수정.

- `refreshFromSystem()` 이 커널상 꺼져 있으면 카운트다운을 정리하고 `turnedOnByThisProcess`
  도 내려놓는다.
- 티커를 유지 시간이 없을 때도 돌린다. 카운트다운용만이 아니라 매 초 커널을 읽어 표시를
  현실과 맞추는 역할을 겸한다. 화면이 실제와 어긋날 수 있는 시간이 최대 1초가 된다.
- `tick()` 은 항상 `refreshFromSystem()` 으로 현실을 먼저 확인하고 진행한다.

## 재발 방지

**이 기능에서 화면에 보이는 모든 값은 커널에서 파생돼야 한다.** 앱이 따로 기억하는 값이
생기면 언젠가 어긋난다. 이 원칙은 `docs/DESIGN.md` 에서도 참조한다.

같은 클래스의 후속 버그가 실제로 한 번 더 났다 —
[`stop-notice-stays-after-turning-the-feature-off.md`](stop-notice-stays-after-turning-the-feature-off.md).
