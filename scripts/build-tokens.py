#!/usr/bin/env python3
"""디자인 토큰에서 코드를 만든다.

    scripts/build-tokens.py                       # 기본 테마로 생성
    scripts/build-tokens.py --theme normalized    # 테마를 얹어서 생성
    scripts/build-tokens.py --check               # 생성물이 최신인지만 확인 (CI 용)

출처는 `design/tokens.json` 하나다. 거기서 두 가지를 만든다.

    Sources/MyMacTools/Design.swift   앱이 쓰는 것
    design/build/tokens.css           같은 값의 CSS 변수. 기술에 매이지 않았다는 증거이자
                                      다른 제품이 가져다 쓰는 자리

테마는 `primitive` 블록만 덮어쓴다. 역할 이름(`semantic`)은 그대로이므로 값만 갈아끼워
다른 디자인을 입힐 수 있다.

색(`*.color.*`)은 숫자와 따로 푼다. 값의 모양은 셋이다.

    "#RRGGBB"                                   원시 색. primitive 에만 둔다
    {"light": <한쪽>, "dark": <한쪽>}           테마마다 다른 색
    {"system": "green"}                         macOS 시스템 색. 두 테마가 같다

<한쪽> 은 "{primitive.color.x}" 참조, {"ref": "{…}", "alpha": 0.32}, {"system": "…"} 중 하나다.
"""

import argparse
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOKENS = ROOT / "design" / "tokens.json"
THEMES = ROOT / "design" / "themes"
SWIFT_OUT = ROOT / "Sources" / "MyMacTools" / "Design.swift"
CSS_OUT = ROOT / "design" / "build" / "tokens.css"

REFERENCE = re.compile(r"^\{([a-zA-Z0-9_.]+)\}$")
BANNER = "// 이 파일은 design/tokens.json 에서 생성됩니다. 직접 고치지 마세요.\n// 값을 바꾸려면 그 파일을 고치고 `scripts/build-tokens.py` 를 돌리세요."


def load(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def merge(base, overlay):
    """테마를 얹는다. 토큰 노드(`value` 를 가진 것)는 통째로 바꾼다."""
    for key, value in overlay.items():
        if key.startswith("$"):
            continue
        if isinstance(value, dict) and isinstance(base.get(key), dict) and "value" not in value:
            merge(base[key], value)
        else:
            base[key] = value
    return base


def walk(node, prefix=()):
    """토큰 노드를 (경로, 노드) 로 펼친다."""
    for key, value in node.items():
        if key.startswith("$"):
            continue
        if isinstance(value, dict) and "value" in value:
            yield prefix + (key,), value
        elif isinstance(value, dict):
            yield from walk(value, prefix + (key,))


def resolve(document):
    """`{a.b.c}` 참조를 실제 값으로 바꾼다. 순환 참조는 그 자리에서 멈춘다."""
    flat = {".".join(path): node for path, node in walk(document)}

    def value_of(key, seen):
        if key in seen:
            raise SystemExit(f"순환 참조: {' -> '.join(list(seen) + [key])}")
        if key not in flat:
            raise SystemExit(f"없는 토큰을 가리킵니다: {key}")
        raw = flat[key]["value"]
        match = REFERENCE.match(raw) if isinstance(raw, str) else None
        if match:
            return value_of(match.group(1), seen | {key})
        if not isinstance(raw, (int, float)):
            raise SystemExit(f"{key} 의 값이 숫자도 참조도 아닙니다: {raw!r}")
        return raw

    numbers = {key: value_of(key, frozenset()) for key in flat if not is_color_key(key)}
    return numbers, flat, resolve_colors(flat)


HEX = re.compile(r"^#[0-9A-Fa-f]{6}$")
MODES = ("light", "dark")

# CSS 로 낼 때 쓰는 시스템 색 근사값. macOS 26 에서 NSColor 를 sRGB 로 읽은 값이다.
# 앱은 이 값을 쓰지 않는다 — Swift 쪽은 시스템 색을 그대로 가리킨다.
SYSTEM_CSS = {
    "green": ("#34C759", "#30D158"),
    "gray": ("#8E8E93", "#98989D"),
    "orange": ("#FF8D28", "#FF9230"),
    "red": ("#FF383C", "#FF4245"),
}


def is_color_key(key):
    parts = key.split(".")
    return len(parts) > 2 and parts[1] == "color"


def resolve_colors(flat):
    """색 토큰을 테마별 값으로 푼다.

    결과는 key → {"light": 한쪽, "dark": 한쪽}. 한쪽은 ("rgb", "#RRGGBB", alpha) 또는
    ("system", 이름) 이다.
    """
    def side(raw, key, seen):
        if isinstance(raw, str):
            match = REFERENCE.match(raw)
            if match:
                target = color_of(match.group(1), seen | {key})
                if target["light"] != target["dark"]:
                    raise SystemExit(f"{key}: 한쪽 값이 테마마다 다른 색을 가리킵니다: {raw}")
                return target["light"]
            if HEX.match(raw):
                return ("rgb", raw.upper(), 1.0)
            raise SystemExit(f"{key}: 색으로 읽을 수 없습니다: {raw!r}")
        if isinstance(raw, dict) and "system" in raw:
            if raw["system"] not in SYSTEM_CSS:
                raise SystemExit(f"{key}: 모르는 시스템 색입니다: {raw['system']}")
            return ("system", raw["system"])
        if isinstance(raw, dict) and "ref" in raw:
            base = side(raw["ref"], key, seen)
            if base[0] != "rgb":
                raise SystemExit(f"{key}: 시스템 색에는 알파를 줄 수 없습니다")
            alpha = float(raw.get("alpha", 1))
            if not 0 < alpha <= 1:
                raise SystemExit(f"{key}: alpha 는 0 보다 크고 1 이하여야 합니다: {alpha}")
            return ("rgb", base[1], alpha)
        raise SystemExit(f"{key}: 색으로 읽을 수 없습니다: {raw!r}")

    def color_of(key, seen):
        if key in seen:
            raise SystemExit(f"순환 참조: {' -> '.join(list(seen) + [key])}")
        if key not in flat:
            raise SystemExit(f"없는 토큰을 가리킵니다: {key}")
        raw = flat[key]["value"]
        if isinstance(raw, dict) and set(raw) >= set(MODES):
            return {mode: side(raw[mode], key, seen) for mode in MODES}
        one = side(raw, key, seen)
        return {mode: one for mode in MODES}

    return {key: color_of(key, frozenset()) for key in flat if is_color_key(key)}


def swift_number(value):
    return str(int(value)) if float(value).is_integer() else repr(float(value))


def swift_side(value):
    if value[0] == "system":
        return f"NSColor.system{value[1].capitalize()}"
    hexcode, alpha = value[1], value[2]
    r, g, b = (int(hexcode[i:i + 2], 16) for i in (1, 3, 5))
    tail = "" if alpha == 1 else f", {swift_number(alpha)}"
    return f"rgb(0x{r:02X}, 0x{g:02X}, 0x{b:02X}{tail})"


def swift_color(value):
    light, dark = swift_side(value["light"]), swift_side(value["dark"])
    return light if light == dark else f"adaptive(light: {light}, dark: {dark})"


def render_swift_colors(colors, flat):
    semantic = sorted(key for key in colors if key.startswith("semantic."))
    if not semantic:
        return []
    indent, inner = "    ", "        "
    lines = [
        f"{indent}/// 색. 테마마다 값이 다르면 **그리는 순간의 appearance** 를 따른다.",
        f"{indent}///",
        f"{indent}/// SwiftUI 의 `Color` 와 이름이 같지만 `Design.Color` 로 부르므로 겹치지 않는다.",
        f"{indent}enum Color {{",
    ]
    for key in semantic:
        name = key.split(".")[-1]
        description = flat[key].get("$description")
        if description:
            lines.append(f"{inner}/// {description}")
        lines.append(f"{inner}static let {name} = SwiftUI.Color(nsColor: AppKitColor.{name})")
    lines += [f"{indent}}}", "",
              f"{indent}/// 같은 색의 AppKit 판. 메뉴바처럼 AppKit 으로 그리는 곳에서 쓴다.",
              f"{indent}enum AppKitColor {{"]
    for key in semantic:
        name = key.split(".")[-1]
        lines.append(f"{inner}static let {name} = {swift_color(colors[key])}")
    lines += [f"{indent}}}", ""]
    return lines


SWIFT_COLOR_HELPERS = """
private func rgb(_ red: Int, _ green: Int, _ blue: Int, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(red) / 255, green: CGFloat(green) / 255,
            blue: CGFloat(blue) / 255, alpha: alpha)
}

/// 그리는 순간의 appearance 로 라이트·다크를 고른다. 창마다, 메뉴바마다 따로 판단된다.
private func adaptive(light: NSColor, dark: NSColor) -> NSColor {
    NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
    }
}
"""


def render_swift(resolved, flat, theme_name, colors=None):
    """사람이 읽을 이름으로 Swift 를 만든다.

    구조는 토큰 파일의 계층을 그대로 따른다. `semantic.space.inline` 은
    `Design.space.inline` 이 된다. 이름을 여기서 새로 짓지 않으므로 토큰 파일과
    코드가 어긋날 수 없다.
    """
    groups = {}
    for key in resolved:
        parts = key.split(".")
        layer = parts[0]
        if layer == "primitive":
            # 원시 눈금은 코드에 노출하지 않는다. 쓰임을 모르는 값을 화면 코드가
            # 직접 집으면 역할 층을 우회하게 된다.
            continue
        group = ".".join(parts[1:-1]) or "root"
        groups.setdefault(group, []).append((parts[-1], key))

    lines = [
        BANNER,
        "//",
        f"// 테마: {theme_name}",
        "",
        "import AppKit",
        "import SwiftUI",
        "",
        "/// 화면에 쓰이는 수치와 색.",
        "///",
        "/// 이름은 크기가 아니라 **쓰임**으로 짓는다. `space8` 이 아니라 `inline` 이라고",
        "/// 부르면 값을 바꿀 때 어디가 영향받는지 이름만 보고 알 수 있다.",
        "///",
        "/// `product` 를 뺀 나머지는 이 앱에 매이지 않는다. 다른 제품으로 가져갈 때",
        "/// `design/tokens.json` 의 `primitive` 값만 바꾸면 된다.",
        "enum Design {",
    ]

    for group in sorted(groups):
        entries = sorted(groups[group])
        indent = "    "
        # Swift 의 타입 이름 규칙에 맞춘다. 토큰 파일은 소문자로 두고 여기서만 올린다.
        path = [part[:1].upper() + part[1:] for part in group.split(".")]
        for depth, part in enumerate(path):
            lines.append(f"{indent * (depth + 1)}enum {part} {{")
        inner = indent * (len(path) + 1)
        for name, key in entries:
            description = flat[key].get("$description")
            if description:
                lines.append(f"{inner}/// {description}")
            lines.append(f"{inner}static let {name}: CGFloat = {swift_number(resolved[key])}")
        for depth in reversed(range(len(path))):
            lines.append(f"{indent * (depth + 1)}}}")
        lines.append("")

    lines += render_swift_colors(colors or {}, flat)
    lines.append("}")
    text = "\n".join(lines).replace("\n\n}", "\n}") + "\n"
    if colors and any(key.startswith("semantic.") for key in colors):
        text += SWIFT_COLOR_HELPERS
    return text


def css_side(value, mode):
    if value[0] == "system":
        return SYSTEM_CSS[value[1]][MODES.index(mode)]
    hexcode, alpha = value[1], value[2]
    if alpha == 1:
        return hexcode
    r, g, b = (int(hexcode[i:i + 2], 16) for i in (1, 3, 5))
    return f"rgba({r}, {g}, {b}, {swift_number(alpha)})"


def render_css(resolved, theme_name, colors=None):
    colors = colors or {}
    lines = [
        "/* 이 파일은 design/tokens.json 에서 생성됩니다. 직접 고치지 마세요. */",
        f"/* 테마: {theme_name} */",
        "/* 시스템 색은 macOS 26 에서 잰 근사값이다. */",
        ":root {",
    ]
    for key in sorted(resolved):
        name = "--" + key.replace(".", "-")
        lines.append(f"  {name}: {swift_number(resolved[key])}px;")
    for key in sorted(colors):
        lines.append(f"  --{key.replace('.', '-')}: {css_side(colors[key]['light'], 'light')};")
    lines.append("}")
    dark = [key for key in sorted(colors) if colors[key]["light"] != colors[key]["dark"]
            or colors[key]["light"][0] == "system"]
    if dark:
        lines += ["@media (prefers-color-scheme: dark) {", "  :root {"]
        for key in dark:
            lines.append(f"    --{key.replace('.', '-')}: {css_side(colors[key]['dark'], 'dark')};")
        lines += ["  }", "}"]
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--theme", help="design/themes/<이름>.json 을 얹는다")
    parser.add_argument("--check", action="store_true",
                        help="생성물이 최신인지만 확인한다. 다르면 종료 코드 1")
    args = parser.parse_args()

    document = load(TOKENS)
    theme_name = document.get("$name", "base")

    if args.theme:
        path = THEMES / f"{args.theme}.json"
        if not path.exists():
            raise SystemExit(f"테마를 찾을 수 없습니다: {path}")
        theme = load(path)
        merge(document, theme)
        theme_name = theme.get("$name", args.theme)

    resolved, flat, colors = resolve(document)
    swift = render_swift(resolved, flat, theme_name, colors)
    css = render_css(resolved, theme_name, colors)

    if args.check:
        stale = []
        if not SWIFT_OUT.exists() or SWIFT_OUT.read_text(encoding="utf-8") != swift:
            stale.append(str(SWIFT_OUT.relative_to(ROOT)))
        if not CSS_OUT.exists() or CSS_OUT.read_text(encoding="utf-8") != css:
            stale.append(str(CSS_OUT.relative_to(ROOT)))
        if stale:
            print("생성물이 토큰과 다릅니다:", ", ".join(stale), file=sys.stderr)
            print("scripts/build-tokens.py 를 돌리세요.", file=sys.stderr)
            return 1
        print("최신입니다.")
        return 0

    CSS_OUT.parent.mkdir(parents=True, exist_ok=True)
    SWIFT_OUT.write_text(swift, encoding="utf-8")
    CSS_OUT.write_text(css, encoding="utf-8")
    print(f"테마 '{theme_name}' 로 수치 {len(resolved)}개 · 색 {len(colors)}개를 생성했습니다.")
    print(f"  {SWIFT_OUT.relative_to(ROOT)}")
    print(f"  {CSS_OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
