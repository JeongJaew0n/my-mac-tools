#!/bin/bash
# 시험을 전부 돌린다: swift test (swift-testing) + 디자인 토큰 검사.
#
# Xcode 없이 명령줄 도구만 있으면 swift-testing 이 기본 검색 경로에 없다.
# 그때만 그 프레임워크 경로를 넘긴다. Xcode 가 있으면 그냥 돈다.
set -euo pipefail
cd "$(dirname "$0")/.."

FRAMEWORKS="$(xcode-select -p)/Library/Developer/Frameworks"
EXTRA=()
if [[ "$(xcode-select -p)" == *CommandLineTools* && -d "$FRAMEWORKS/Testing.framework" ]]; then
    # 명령줄 도구판에는 Testing+Foundation 교차 모듈(`_Testing_Foundation`)이 없어 `import Foundation`
    # 과 함께 쓰면 컴파일이 멈춘다(실측). 교차 모듈을 찾지 않게 한다 — 시험은 그 모듈을 쓰지 않는다.
    EXTRA=(-Xswiftc -F"$FRAMEWORKS" -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays
           -Xlinker -F"$FRAMEWORKS" -Xlinker -rpath -Xlinker "$FRAMEWORKS")
fi

swift test "${EXTRA[@]}" "$@"
scripts/build-tokens.py --check
