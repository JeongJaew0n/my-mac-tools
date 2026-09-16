# `AppleClamshellCausesSleep` 값을 판정 근거로 쓰면 안 된다

## 환경

- macOS 26 (Darwin 25.6.0), Apple Silicon (MacBook)

## 증상

`ioreg` 에서 `AppleClamshellCausesSleep = No` 로 읽혀 "덮개를 닫아도 안 자겠구나" 라고
판단했는데 실제로는 잤다. 다른 시점에 다시 읽으니 `Yes` 였다.

## 원인

순간 상태값이다. 외부 디스플레이·전원·현재 덮개 상태에 따라 계속 바뀌므로, 어느 한 시점에
읽은 값으로 미래의 동작을 예측할 수 없다.

## 해결

**실제 잠자기 기록**으로 판단한다.

```bash
pmset -g log | grep -i 'Clamshell Sleep' | tail -5
```

## 재발 방지

시스템 동작을 예측하는 판정은 순간 상태값이 아니라 **로그에 남은 사실**로 한다.
