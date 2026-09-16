# `caffeinate` 를 띄워둬도 덮개를 닫으면 잠든다

## 환경

- macOS 26 (Darwin 25.6.0), Apple Silicon (MacBook)

## 증상

`caffeinate -i` (또는 `-d -m -s -u`) 를 실행해둔 상태에서 덮개를 닫았는데 잠들었다.

## 원인

덮개 닫기는 **유휴 잠자기가 아니라 강제 잠자기 경로**다. `caffeinate` 가 만드는 전력
assertion 은 유휴 경로에만 작용하므로 통째로 무시된다.

이를 막는 것은 `pmset -a disablesleep` 뿐인데, **`man pmset` 에 문서화되지 않은
비공식 플래그**다.

## 해결

```bash
sudo pmset -a disablesleep 1    # 덮개 닫기 잠자기 차단
sudo pmset -a disablesleep 0    # 원복
```

현재 값은 커널에서 읽는다. `pmset -g` 출력이 아니라 이쪽이 정본이다.

```bash
ioreg -n IOPMrootDomain -r -d 1 | grep SleepDisabled   # Yes / No
```

## 재발 방지

- `caffeinate` 로 덮개 잠자기를 막으려는 코드를 쓰지 않는다. 검증은 **실제 잠자기
  기록**으로 한다.
  ```bash
  pmset -g log | grep -i 'Clamshell Sleep' | tail -5
  ```
- `disablesleep` 는 전역·영구 설정이다. 켠 프로세스가 비정상 종료하면 그대로 남으므로,
  켠 주체를 기억하고 내려놓는 경로를 반드시 만든다.
