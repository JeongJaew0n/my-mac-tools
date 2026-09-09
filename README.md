# MyMacTools

macOS 유틸리티 앱

## 기능

### 화면 끄고 작업 계속하기

지정한 시간 동안 **화면만 꺼둔 채 시스템은 계속 돌립니다.** 잠자기(sleep)가 아니라서
백그라운드 작업은 멈추지 않습니다.

| 대상 | 상태 | 명령 |
| --- | --- | --- |
| 시스템 유휴 잠자기 | 차단 | `caffeinate -i -t <초>` |
| 디스플레이 | 꺼짐 | `pmset displaysleepnow` |
| 종료 (선택) | 잠자기 | `pmset sleepnow` |

- **Keep working**: 유지 시간을 시(0~24) · 분(0~50, 10분 단위)으로 고릅니다.
  `0h 00m` 이면 Stop 을 누를 때까지 계속 유지합니다.
- **Screen off in**: 화면이 꺼지기까지의 지연을 3 / 5 / 7 / 10초 중에 고릅니다.
  Start 를 누른 뒤 손을 뗄 시간입니다.
- **Sleep when time is up**: 켜면 유지 시간이 끝날 때 `pmset sleepnow` 로 잠재웁니다.
  무제한(`0h 00m`)이면 끝나는 시점이 없으므로 비활성화됩니다.
- **Start** → caffeinate 가 즉시 시작되고, 지연 시간이 지나면 화면이 꺼집니다.
- **Stop** → caffeinate 를 끄고 아직 안 꺼진 화면 예약도 취소합니다.
  수동 정지는 잠자기로 이어지지 않습니다.
- 유지 시간이 끝나면 caffeinate 가 스스로 만료돼 평소 절전 동작으로 돌아옵니다.

> **Sleep 옵션을 끄면 시간이 끝나도 안 잠들 수 있습니다.**
> 유휴 잠자기 여부는 시스템 설정을 따르는데, AC 전원에서 `sleep 0`(안 함)으로 두는
> 경우가 흔합니다. `pmset -g custom` 으로 확인할 수 있습니다.

`caffeinate -d`(디스플레이 슬립 방지)는 화면을 끄려는 목적과 정반대라 쓰지 않습니다.

#### 한계

- 키보드·트랙패드를 건드리면 화면은 다시 켜집니다. `pmset` 으로 막을 수 없습니다.
- `-i` 는 **유휴** 잠자기만 막습니다. 노트북 뚜껑을 닫으면 잠듭니다.
- 배터리 전원이면 전원 정책이 달라질 수 있습니다.
- caffeinate 가 외부에서 kill 되면 세션은 정리되지만 잠자기로는 보내지 않습니다.
  만료 시각에 도달한 종료만 잠자기 대상입니다.

## 빌드 & 실행

```bash
# .app 번들 빌드 (MyMacTools.app)
./scripts/build-app.sh

# 실행
open .build/MyMacTools.app

# 설치 (선택)
cp -r .build/MyMacTools.app /Applications/
```

## 사용법

1. 앱 실행 시 GUI 창이 열림
2. 토글 스위치로 Caffeinate ON/OFF
3. 상태 표시: 녹색 원 = ON, 회색 = OFF
4. 앱 종료 시 caffeinate 프로세스도 자동 종료

## 요구사항

- macOS 14.0+
- Swift 5.9+
