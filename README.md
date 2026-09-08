# MyMacTools

macOS 유틸리티 앱

## 기능

### Caffeinate Toggle
GUI에서 `caffeinate -di`를 ON/OFF 할 수 있습니다.
- **ON**: 디스플레이 슬립 + 시스템 idle 슬립 방지
- **OFF**: 정상 슬립 동작 복원

### 지속 시간 선택
ON 으로 켜기 전에 유지 시간을 셀렉트 박스 두 개로 고를 수 있습니다.
- **시간**: 0 ~ 24
- **분**: 0 ~ 50 (10분 단위)
- `0h 00m` 이면 시간 제한 없이(`caffeinate -di`) 계속 유지합니다
- 시간을 지정하면 `caffeinate -di -t <초>` 로 실행되어 만료 시 자동으로 OFF 로 돌아옵니다
- 실행 중에는 남은 시간이 `H:MM:SS` 로 표시되고, 선택 박스는 잠깁니다

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
