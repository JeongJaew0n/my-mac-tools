# spec — mac-info

## 목표

여섯째 Tool **Mac 정보**. 이 맥이 무엇이고(기종·칩·macOS), 메모리·저장공간이 얼마이고 얼마나
쓰고 있는지, IP 가 무엇인지 한 화면에 보인다.

## 확정한 결정

| 결정 축 | 확정 내용 | 근거 |
|---|---|---|
| 배치 | **새 Tool (여섯째 탭)** | 다른 Tool 과 다루는 대상이 다르다 |
| 메모리 "사용" | **App + Wired + 압축** — 활성 상태 보기의 "사용된 메모리" 와 같은 정의 | `top` 의 "17G used, 86M unused" 는 macOS 가 남는 램을 캐시로 쓰는 것까지 세어 **꽉 찬 것처럼 보인다**(실측). 사용자가 아는 숫자는 활성 상태 보기의 것이다 |
| 메모리 압력 | `DispatchSource.makeMemoryPressureSource` 의 정상·주의·위험 | OS 가 판정한 값이다. 경계를 우리가 정하지 않는다 |
| 메모리 여유 % | `sysctl kern.memorystatus_level` | `memory_pressure` 명령이 보여주는 "System-wide memory free percentage" 와 같은 값 |
| 저장공간 | `/` 의 `volumeTotalCapacity` · `volumeAvailableCapacityForImportantUsage` | **`df` 를 쓰면 틀린다.** `df` 는 봉인된 시스템 볼륨만 세어 "사용 12.2 GB" 로 나왔다(실측). 실제는 컨테이너 494.4 GB 중 245.2 GB 여유. 위 두 값은 컨테이너 기준이고 Finder 와 같다 |
| 단위 | **10진 GB** (`ByteCountFormatter`) | Finder 와 같은 단위 |
| 기종 이름 | `system_profiler SPHardwareDataType` 을 **처음 한 번만** 띄워 캐시 | `hw.model` 은 `Mac15,6` 처럼 사람이 못 읽는다. 0.09초라 한 번은 싸다 |
| 칩 · 식별자 | `machdep.cpu.brand_string` · `hw.model` | |
| 내부 IP | `getifaddrs` — 켜진 인터페이스의 IPv4 (루프백 제외) | 네트워크 요청이 없다 |
| 인터페이스 종류 | `NWPathMonitor` 가 주는 Wi-Fi · 유선 등 | 이벤트로 받는다 |
| **공인 IP** | **누를 때만** `https://api.ipify.org` 에 묻는다 | 공인 IP 는 바깥 서비스에 물어야만 알 수 있다. 창을 열 때마다 제3자에게 요청을 보내지 않는다 — 로컬호스트 `열기` 가 남의 서버에 요청을 보내지 않은 것과 같은 원칙이다 |
| 갱신 | 탭이 보일 때 한 번 + **탭이 보이는 동안 5초마다**(tolerance 20%). 기종·칩·용량은 한 번만 | 메모리·저장공간은 변하지만 빨리 변하지 않는다. 다른 목록과 같은 규칙 — 안 보이면 훑지 않는다 |
| 복사 | IP 는 눌러서 복사 | 보통 IP 를 보는 이유는 어딘가에 붙여 넣기 위해서다 |
| 메뉴바 | 넣지 않는다 | |
| API | `mac.info` | 다른 Tool 과 같은 원칙. 공인 IP 는 `mac.publicIP` 로 따로 — 바깥 요청을 부르는 쪽이 고르게 한다 |

## 화면 (초안)

```
 MacBook Pro · Apple M3 Pro
 macOS 26.3.1 (25D2128) · Mac15,6

 메모리      16.3 / 18.0 GB  [████████░]   압력 정상 · 여유 33%
 저장공간    249 / 494 GB    [█████░░░░]   245 GB 남음

 내부 IP     192.168.0.23   Wi-Fi (en0)     ← 눌러서 복사
 공인 IP     [확인]                          ← 누를 때만 바깥에 묻는다
```

## 완료 조건

- 각 값이 기준 도구와 맞는다 — 메모리는 `vm_stat` 으로 같은 정의를 계산한 값, 저장공간은
  `diskutil info /` 의 컨테이너 값, 내부 IP 는 `ipconfig getifaddr`, 기종은 `system_profiler`
- 탭을 떠나면 갱신이 멈춘다
- 공인 IP 는 누르기 전에는 요청이 나가지 않는다
- 문구 ko · en · ja
