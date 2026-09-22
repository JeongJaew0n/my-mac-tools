# 디자인 토큰

수치의 단일 출처는 **`design/tokens.json`** 하나다. 코드는 거기서 생성한다.

```
design/tokens.json          출처. 여기를 고친다
design/themes/*.json        값만 덮어쓰는 테마
scripts/build-tokens.py     생성기
  ↓
Sources/MyMacTools/Design.swift    앱이 쓰는 것 (생성물 — 직접 고치지 않는다)
design/build/tokens.css            같은 값의 CSS 변수 (생성물)
```

```bash
scripts/build-tokens.py                     # 생성
scripts/build-tokens.py --theme normalized  # 테마를 얹어서 생성
scripts/build-tokens.py --check             # 생성물이 최신인지 확인 (다르면 종료 코드 1)
```

## 왜 세 층인가

| 층 | 무엇 | 다른 제품으로 가져가나 |
|---|---|---|
| `primitive` | **값만 있는 눈금.** `space.5 = 8` | 아니다. **여기만 갈아끼운다** |
| `semantic` | **역할 이름.** `space.inline → {primitive.space.5}` | 그렇다. 이름을 그대로 쓴다 |
| `product` | 이 앱에서만 뜻이 있는 것. 창 크기 | 아니다. 버린다 |

층을 나누는 이유는 하나다. **역할 이름을 고정해야 값을 마음대로 바꿀 수 있다.**

`spacing8` 이라고 부르면 값을 12로 바꾸는 순간 이름이 거짓이 된다. `inline` 이라고 부르면
값이 무엇이든 이름은 계속 맞다. 그래서 화면 코드는 `semantic` 만 집고, 원시 눈금은
Swift 로 내보내지도 않는다 — 집을 수 없으면 우회할 수도 없다.

## 역할 이름

`primitive` 를 뺀 나머지는 이 앱을 몰라도 읽힌다. `caffeineItem` 이 아니라 `listItem` 이고,
`tabBarHorizontal` 이 아니라 `navX` 다.

### `space` — 사이 간격

| 이름 | 쓰임 |
|---|---|
| `none` | 간격을 주지 않는다. 구분선이 대신 가른다 |
| `rowTight` | 한 덩어리로 읽혀야 하는 줄 사이. 항목 사이보다 좁다 |
| `chipGap` · `navItemGap` | 칩 사이 · 탐색 항목 사이 |
| `listRow` | 목록의 줄 사이, 불릿과 글 사이 |
| `labelGap` | 표시기(점·아이콘)와 그 옆 글 사이 |
| `inline` | 한 줄 안에서 라벨과 컨트롤 사이 |
| `listItem` | 목록 항목 사이 |
| `formRow` | 설정 항목 사이 |
| `block` · `blockLoose` | 화면 안 블록 사이 |
| `overlayRow` | 전체 화면 오버레이의 줄 사이 |

### `inset` — 안쪽 여백

`screen` · `card` · `chipX` · `chipY` · `panel` · `overlay` ·
`navX` · `navTop` · `navBottom` · `navItemY`

### `radius` — 모서리

`control` · `card` · `chip` · `panel`.
`chip` 은 `card` 보다 작아야 안에 든 것으로 읽힌다.

### `size` — 크기

`indicator` · `indicatorSmall` · `navIcon`.
`indicatorSmall` 은 본문보다 작게 두어 위계를 만든다.

## 값만 바꿔 다른 디자인 입히기

`design/themes/<이름>.json` 에 **바꿀 값만** 쓴다. 쓰지 않은 것은 기본값을 따른다.

```json
{
  "$name": "roomy",
  "primitive": { "space": { "5": { "value": 12 } } }
}
```

```bash
scripts/build-tokens.py --theme roomy
```

`primitive.space.5` 하나를 바꾸면 그것을 가리키는 `inline` · `listItem` · `navBottom` 이
함께 따라간다. 화면 코드는 한 줄도 고치지 않는다.

딸려 있는 `normalized` 테마가 그 예다. `docs/DESIGN.md` §8.1 의 "눈금을 4의 배수로" 제안을
값으로만 적용한 것이다.

```
primitive.space.1     3 → 4        semantic.space.rowTight    3 → 4
primitive.space.3     5 → 4        semantic.space.listRow     5 → 4
primitive.space.4     6 → 8        semantic.space.labelGap    6 → 8
primitive.space.6    10 → 12       semantic.space.formRow    10 → 12
                                   semantic.inset.navTop     10 → 12
원시 4개를 바꾸면 → 값 14개가 따라 바뀐다. 역할 이름은 하나도 안 바뀐다.
```

`normalized` 는 **아직 적용하지 않았다.** 블록 간격을 통일하면 내용 높이가 바뀌어
고정 높이(336)를 다시 재야 하고(§8.2), 그 값은 눈으로 확인해야 정해진다. 테마 파일 안에
그 사실을 적어 두었다.

## 다른 제품에서 쓰기

`design/tokens.json` 을 복사한 뒤 두 가지만 한다.

1. **`product` 블록을 버린다.** 창 크기처럼 이 앱에서만 뜻이 있는 값이다
2. **`primitive` 값을 그 제품의 눈금으로 바꾼다.** `semantic` 은 손대지 않는다

`semantic` 이름을 그대로 쓰면 두 제품이 같은 말로 같은 역할을 부른다. 값이 달라도
"칩 사이" 를 찾을 때 볼 곳이 같다.

웹이라면 생성된 `design/build/tokens.css` 를 그대로 가져간다.

```css
:root {
  --semantic-space-inline: 8px;
  --semantic-radius-chip: 3px;
  /* … */
}
```

Swift 외의 출력이 필요하면 `scripts/build-tokens.py` 의 `render_*` 함수를 하나 더 쓴다.
해석은 이미 끝난 상태로 넘어오므로 값을 찍는 일만 남는다.

## 이 체계가 다루지 않는 것

- **색** — 아직 토큰이 아니다. `Color.primary.opacity(0.05)` 처럼 SwiftUI 의 의미 색을
  직접 쓴다. macOS 의 라이트·다크 대응을 공짜로 얻는 대가로, 색만은 토큰 밖에 있다.
  `docs/DESIGN.md` §4 를 보라
- **글자** — `.caption` · `.callout` 같은 시스템 텍스트 스타일을 쓴다. 같은 이유다
- **애니메이션 · 그림자** — 쓰는 곳이 없어 넣지 않았다

색과 글자를 토큰으로 옮기려면 시스템 의미 색을 포기하고 직접 값을 지정해야 한다. 그
값어치가 분명해질 때 하는 것이 맞다.

## 규칙

- **`Design.swift` 를 직접 고치지 않는다.** 생성물이고 다음 생성에서 덮어써진다
- 새 수치가 필요하면 **역할 이름을 먼저 정한다.** 이름이 안 나오면 기존 역할 중
  하나로 충분한 경우가 많다
- 제품 이름(`caffeine`, `port`, `lid`)을 `semantic` 에 넣지 않는다. 그것은 `product` 층이거나,
  아니면 역할 이름을 잘못 고른 것이다
