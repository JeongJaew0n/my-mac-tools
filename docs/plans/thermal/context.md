# context — thermal

## 원 요청

사용자가 세션마스터(다른 Claude 세션)를 통해 "MyMacTools 에 맥북 발열(온도) 체크 기능을 넣을 수
있는지" 물었다. 이 세션이 이 맥에서 직접 읽어 보고 가능하다고 답했고(2026-11-06), 사용자는
**"새 툴로 넣어줘. 2번까지(온도도 표시)"** 로 정했다. 세부(묶는 방식, 팬 속도, 표시 방식)는
이 세션의 권고대로 판단하라고 했다.

## 실측 (M3 Pro, Mac15,6, macOS 26.3)

- `ProcessInfo.thermalState` → `nominal`. 권한 없이 읽힌다.
- `pmset -g therm` → "No thermal warning level has been recorded". 이 맥에서는 쓸 값이 없다.
- IOHID 온도 센서 46개 (sudo 없음): `PMU tdie1~10` 32~35°C, `PMU tdev1~8` 25~28°C,
  `PMU tcal` 51.9°C(고정), `NAND CH0 temp` 27°C, `gas gauge battery` 24~25°C. 이름마다 두 번씩 나온다.
- 한 번 훑는 데 약 35ms.

## 기각한 대안

- **`powermetrics --samplers smc`** — sudo 가 필요하다. 덮개 Tool 처럼 sudoers 를 늘리면 되지만,
  보기만 하는 기능에 관리자 권한을 받는 것은 과하다.
- **SMC 키 직접 읽기(`Tp09` 등)** — 키 이름이 칩 세대마다 다르고 표가 공개돼 있지 않다.
  IOHID 쪽이 이름(`PMU tdie…`)이라도 준다.
- **센서마다 뜻을 붙여 "CPU · GPU · 메모리" 로 보이기** — Apple 이 공개한 대응표가 없다.
