# checklist — mac-info

`(확인)` 은 사용자가 직접 써보고 확인해준 것, `(실측)` 은 명령·캡처로 확인한 것이다.

## 0. 조사
- [x] 기준 도구로 이 맥의 값 수집 (실측)
- [x] `df` · `top` 의 함정 확인 (실측)
- [x] spec · context 작성

## 1. 구현
- [x] `MacInfoManager` — sysctl · `host_statistics64` · URL 자원값 · `getifaddrs` · `NWPathMonitor` · 메모리 압력 소스
- [x] `Tab.macInfo` 와 화면, ko/en/ja 문자열
- [x] API `mac.info` · `mac.publicIP`
- [x] 탭이 여섯이 되며 이름이 두 줄로 꺾임 → 한 줄에 안 들어가면 아이콘만 (`ViewThatFits`)
- [x] 저장공간 숫자 꼴 — `ByteCountFormatter` 가 "222.41GB" 로 붙여 써서 직접 포맷

## 2. 검증 (실측)
- [x] 메모리 사용 — 앱 15.743 GB · `vm_stat` 같은 정의 15.729 GB (0.1% 차, 읽은 시점 차이)
- [x] 저장공간 남음 — 앱 271,977,843,561 B · Finder `free space of startup disk` 2.7198e11 B 일치
- [x] 전체 용량 — 494,384,795,648 B, `diskutil` 컨테이너 전체와 일치
- [x] 내부 IP — en0 192.168.0.23, `ipconfig getifaddr en0` 과 일치, 종류 Wi-Fi
- [x] 공인 IP — `mac.publicIP` 뒤 `ok 175.197.62.151`, `curl api.ipify.org` 와 일치
- [x] 기종 이름 `MacBook Pro`(system_profiler) · `Mac15,6` · `Apple M3 Pro` · `macOS 26.3.1 (25D2128)`
- [x] 화면 캡처로 배치·숫자 꼴 확인
- [ ] (확인) 사용자가 직접 써보기

## 3. MAC 주소 (추가 요청)
- [x] 지금 MAC — `getifaddrs` 의 AF_LINK. `sa_len` 안에서 읽는다 (`sdl_data` 선언 12바이트를 넘는 긴 이름 대비)
- [x] 하드웨어 MAC — IOKit `IOMACAddress` (인터페이스의 부모 컨트롤러). 인터페이스별 한 번만 읽고 캐시
- [x] (실측) en0 지금 `d2:22:e2:b6:4b:3d` = `ifconfig en0 ether`, 하드웨어 `10:42:10:ee:f2:16` = `networksetup -getmacaddress en0`
- [x] 둘이 다르면 "비공개 주소" 표시 + 하드웨어 줄, 같으면 한 줄
