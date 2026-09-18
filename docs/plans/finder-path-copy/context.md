# context — finder-path-copy

## 원 요청 (2026-09-18)

> finder에서 파일 선택하고 내가 지정한 단축키 누르면 절대경로 복사되게 하고 싶음.

검토 결과 macOS 에 이미 `⌥⌘C` 가 있다는 것을 알렸으나, **키를 바꿀 수 없다**는 점 때문에
직접 만드는 쪽으로 정해졌다.

> 뭐야 전역 단축키 있으면 그거 쓰면 되겠네

여기서 "전역 단축키" 는 화면 가리기에 쓴 `HotKeyCenter` 를 가리킨다.

## 검토 단계에서 실측한 것

```
osascript -e 'tell application "Finder" to get (POSIX path of (item 1 of (get selection) as alias))'
→ /Users/jjw/Downloads/ChatGPT Image 2026년 9월 18일 오후 05_22_29.png
   (당시 Finder 에서 선택돼 있던 파일)

Finder 바이너리: cmdCopyAsPathname:, FXCopyAsPathnameQuoted
메뉴 제목(ko): "‘^1’의 경로 이름을 복사" / "^0개의 항목을 경로 이름으로 복사"
  → 제목이 가변이라 시스템 설정 "앱 단축키" 로 재지정 불가

앱 서명: designated => cdhash H"aed0539f...e4"
  소스 불변 시 재빌드해도 CDHash 동일
```

## 기각 — 시스템 설정의 "앱 단축키" 로 재지정

코드를 한 줄도 안 쓰는 방법이라 먼저 검토했다. 메뉴 제목에 파일명과 개수가 들어가
정확히 일치시킬 수 없어 포기했다.

## 기각 — 따옴표 옵션

`defaults write com.apple.finder FXCopyAsPathnameQuoted -bool true` 로 Finder 는 따옴표를
씌울 수 있다. 우리 것에는 넣지 않는다. 옵션을 하나 더 두는 값어치보다, 붙여넣는 쪽에서
필요하면 감싸는 편이 단순하다. 요청이 오면 그때 넣는다.

## 참고

- `docs/plans/screen-cover/spec.md` — `HotKeyCenter` 를 처음 도입한 작업
- `Sources/MyMacTools/Shortcut.swift` — 단축키 모델과 등록기
