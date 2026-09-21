# context — menu-bar-item

## 원 요청 (2026-09-21)

> mac북 상단 상태바에 이제 우리 tool을 표시하고 싶어.

세부는 물어서 정했다 — Dock 유지, 드롭다운 메뉴, 상태 반영.

## 검토 단계에서 실측한 것

```
배포 타깃: macOS 14        → MenuBarExtra(13+) 사용 가능, 컴파일 통과
NSStatusItem 생성          → 성공, 권한 불필요
상태 막대 두께             → 22pt
SF Symbol 후보             → wrench.and.screwdriver(.fill) 등 모두 존재
현재 Info.plist            → LSUIElement 없음 (Dock 아이콘 있는 일반 앱)
```

## 기각 — 메뉴바 전용 앱(`LSUIElement`)

상주 유틸리티다운 모양이지만 Dock 에서 사라지고 `Cmd-Tab` 에도 안 잡힌다. 앱을 끄는
방법이 메뉴바 하나로 줄어드는 것도 부담이다. 기존 동작을 안 바꾸는 쪽을 골랐다.

## 기각 — 팝오버에 전체 UI

탭 3개가 좁은 팝오버에 들어가면 답답하다. 창을 이미 잘 쓰고 있으므로 메뉴바는 빠른
토글과 상태 확인만 맡는다.

## 기각 — 메뉴 항목에 색 점

탭바에서 쓰는 `Circle().fill(.green)` 을 메뉴에도 쓰려 했으나, 메뉴는 이미지를 template
으로 렌더링해 색이 죽을 수 있다. 탭바를 만들 때 `.tabItem` 을 피한 것과 같은 이유다.
메뉴에서는 체크마크가 관례이므로 `Toggle` 로 간다.

## 참고

- `docs/plans/tabbed-window/spec.md` — 색 점이 template 렌더링에 죽는 문제
- `docs/troubleshootings/reusable/pmset-sleepnow-refused-when-disablesleep-is-1.md`
  — 덮개 기능을 켤 때 "끝나면 잠자기" 를 내려야 하는 이유
