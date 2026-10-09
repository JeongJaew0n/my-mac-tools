# context — mac-info

## 원 요청 (2026-10-09)

> 그리고 기능 하나 더 추가. 이번엔 Mac 정보 표시.
> 몇gb이고 ram몇이고, 저장공간 몇이고, 얼마나 쓰고있고, 현재 ip뭔지 표시하는.

## 기준 도구로 잰 이 맥의 값

```
system_profiler   MacBook Pro · Mac15,6 · Apple M3 Pro · Memory: 18 GB
hw.memsize        19,327,352,832 bytes
macOS             26.3.1 (25D2128)
diskutil          Container Total 494.4 GB · Container Free 245.2 GB
df -k /           "사용 12.2 GB"                      ← 틀린 값 (아래)
top               PhysMem: 17G used, 86M unused       ← 착시 (아래)
vm_stat 으로 계산 App 3.86 + Wired 3.24 + 압축 9.22 = 16.32 GB
memorystatus      여유 33~40%
ipconfig          en0 192.168.0.23
system_profiler   0.09초
```

## 함정 둘

**`df` 의 사용량은 틀린다.** APFS 에서 `/` 는 봉인된 시스템 볼륨이고, 사용자 데이터는 같은
컨테이너의 Data 볼륨에 있다. `df /` 는 시스템 볼륨만 세어 12.2 GB 라고 한다. 실제 사용은
컨테이너 기준 약 249 GB 다.

**`top` 의 used 는 꽉 찬 것처럼 보인다.** macOS 는 남는 램을 파일 캐시로 쓰고, `top` 은 그것까지
"used" 로 센다. 그래서 18 GB 중 86 MB 만 남은 것처럼 나온다. 사용자가 활성 상태 보기에서 보는
"사용된 메모리" 는 App + Wired + 압축이다.

## 공인 IP 를 누를 때만 묻는 이유

내부 IP(192.168.x)는 이 맥이 안다. 공인 IP 는 공유기 바깥에서 보이는 주소라 **바깥 서비스에
물어야만** 알 수 있다. 창을 열 때마다 제3자에게 요청을 보내지 않는다.

`api.ipify.org` 를 고른 이유 — 공인 IP 를 돌려주는 것만 하는 서비스이고, 키가 필요 없고, 응답이
IP 문자열 하나라 해석할 것이 없다.
