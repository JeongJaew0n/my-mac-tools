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

    return {key: value_of(key, frozenset()) for key in flat}, flat


def swift_number(value):
    return str(int(value)) if float(value).is_integer() else repr(float(value))


def render_swift(resolved, flat, theme_name):
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
        "import CoreGraphics",
        "",
        "/// 화면에 쓰이는 수치.",
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

    lines.append("}")
    return "\n".join(lines).replace("\n\n}", "\n}") + "\n"


def render_css(resolved, theme_name):
    lines = [
        "/* 이 파일은 design/tokens.json 에서 생성됩니다. 직접 고치지 마세요. */",
        f"/* 테마: {theme_name} */",
        ":root {",
    ]
    for key in sorted(resolved):
        name = "--" + key.replace(".", "-")
        lines.append(f"  {name}: {swift_number(resolved[key])}px;")
    lines.append("}")
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

    resolved, flat = resolve(document)
    swift = render_swift(resolved, flat, theme_name)
    css = render_css(resolved, theme_name)

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
    print(f"테마 '{theme_name}' 로 토큰 {len(resolved)}개를 생성했습니다.")
    print(f"  {SWIFT_OUT.relative_to(ROOT)}")
    print(f"  {CSS_OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
