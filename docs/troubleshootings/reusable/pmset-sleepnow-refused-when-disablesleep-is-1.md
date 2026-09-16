# `disablesleep=1` 이면 `pmset sleepnow` 가 조용히 거부된다

## 환경

- macOS 26 (Darwin 25.6.0), Apple Silicon

## 증상

잠자기를 시키려고 `pmset sleepnow` 를 호출했는데 맥이 안 잤다. 오류도 보이지 않았다.

## 원인

`disablesleep` 가 `1` 이면 `sleepnow` 가 `kIOReturnNotPermitted` (`0xe00002e2`) 로
거부된다. 두 설정이 정면으로 모순되므로 당연한 동작이다.

**오류가 안 보인 것은 별개 문제다.** 프로세스 실행 래퍼가 *기동 실패*만 잡고
**종료 코드를 확인하지 않으면** 거부가 아무 데도 표면화되지 않는다.

```bash
sudo pmset -a disablesleep 1
sudo pmset sleepnow            # → Unable to sleep system: error 0xe00002e2
sudo pmset -a disablesleep 0
```

## 해결

두 기능을 동시에 켤 수 없게 막는다. 덮개 차단이 켜지면 "끝나면 잠자기" 쪽을 비활성화하고,
켜는 데 성공하는 시점에 값도 함께 내린다.

화면 슬립(`pmset displaysleepnow`)은 `disablesleep` 의 영향을 받지 않으므로, 화면 끄기와
덮개 차단을 같이 쓰는 것 자체는 문제없다.

## 재발 방지

- 외부 명령을 실행하는 공용 래퍼는 **`terminationStatus` 를 반드시 확인**한다.
  기동 성공과 실행 성공은 다르다. 이 함정은 `pmset` 에 국한되지 않는다.
- 서로 모순되는 시스템 설정을 다루는 기능은 UI 단계에서 상호 배타로 만든다.
