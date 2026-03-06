# DeskMate

macOS 유틸리티 앱

## 기능

### Caffeinate Toggle
GUI에서 `caffeinate -di`를 ON/OFF 할 수 있습니다.
- **ON**: 디스플레이 슬립 + 시스템 idle 슬립 방지
- **OFF**: 정상 슬립 동작 복원

## 빌드 & 실행

```bash
# .app 번들 빌드 (DeskMate.app)
./scripts/build-app.sh

# 실행
open .build/DeskMate.app

# 설치 (선택)
cp -r .build/DeskMate.app /Applications/
```

## 사용법

1. 앱 실행 시 GUI 창이 열림
2. 토글 스위치로 Caffeinate ON/OFF
3. 상태 표시: 녹색 원 = ON, 회색 = OFF
4. 앱 종료 시 caffeinate 프로세스도 자동 종료

## 요구사항

- macOS 14.0+
- Swift 5.9+
