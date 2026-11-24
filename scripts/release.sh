#!/bin/bash
# 릴리스를 낸다 — 번호 올리기 · 커밋 · 태그 · 푸시 · GitHub Release 를 한 번에.
# 앱 메뉴의 "업데이트…" 는 GitHub Release 만 보므로 손으로 태그만 달지 않는다.
# 결정과 근거: docs/plans/app-versioning/spec.md
#
# 쓰는 법:
#   scripts/release.sh <initial|minor|patch> "<무엇이 올랐는지 한 줄>" [git commit 에 넘길 인자…]
#
#   initial  v* 태그가 하나도 없을 때만. 번호를 올리지 않고 지금 번호에 태그를 단다.
#   minor    기능 추가·호환 깨짐   0.3.4 → 0.4.0
#   patch    버그 수정·내부 정리    0.3.4 → 0.3.5
#
#   예: scripts/release.sh minor "Add capture edit" --trailer "Co-Authored-By: …"
#
# 번호는 Resources/Info.plist 의 CFBundleShortVersionString 한 곳에만 있다. 0.x 에 머문다.
# MMT_GH 로 gh 대신 다른 명령을 쓸 수 있다(시험용).
set -euo pipefail

die() { echo "release: $*" >&2; exit 1; }
usage() { sed -n '6,13p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

[ $# -ge 2 ] || usage
KIND="$1"; SUMMARY="$2"; shift 2
case "$KIND" in initial|minor|patch) ;; *) usage ;; esac
[ -n "$SUMMARY" ] || usage

cd "$(git rev-parse --show-toplevel)"
PLIST="Resources/Info.plist"
GH="${MMT_GH:-gh}"
KEY="CFBundleShortVersionString"

read_version() { /usr/libexec/PlistBuddy -c "Print :${KEY}" "$PLIST"; }

# 1. 상태 — main, 깨끗한 트리, origin 보다 뒤처지지 않음, gh 로그인.
[ "$(git symbolic-ref --quiet --short HEAD || true)" = "main" ] || die "main 에서만 낸다"
[ -z "$(git status --porcelain)" ] || die "커밋하지 않은 변경이 있다"
git fetch --quiet --tags origin main
git merge-base --is-ancestor FETCH_HEAD HEAD || die "origin/main 에 받지 않은 커밋이 있다 — 먼저 받는다"
"$GH" auth status >/dev/null 2>&1 || die "gh 로그인이 필요하다 (gh auth login)"

# 2. 번호.
CURRENT="$(read_version)"
[[ "$CURRENT" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || die "${KEY} 가 semver 가 아니다: ${CURRENT}"
MAJOR="${BASH_REMATCH[1]}"; MINOR="${BASH_REMATCH[2]}"; PATCH="${BASH_REMATCH[3]}"
[ "$MAJOR" = "0" ] || die "0.x 에 머문다 — ${CURRENT}"

PREVIOUS="$(git tag --list 'v*' --sort=-v:refname | head -n 1)"
if [ "$KIND" = "initial" ]; then
    [ -z "$PREVIOUS" ] || die "이미 릴리스가 있다(${PREVIOUS}). minor 나 patch 를 쓴다"
    NEXT="$CURRENT"
else
    [ -n "$PREVIOUS" ] || die "릴리스가 아직 없다. 첫 릴리스는 initial 이다"
    # 손으로 번호를 바꿨으면 무엇에서 올릴지 알 수 없다.
    [ "$PREVIOUS" = "v${CURRENT}" ] || die "${KEY}(${CURRENT}) 가 마지막 태그(${PREVIOUS}) 와 다르다"
    if [ "$KIND" = "minor" ]; then NEXT="0.$((MINOR + 1)).0"; else NEXT="0.${MINOR}.$((PATCH + 1))"; fi
fi
TAG="v${NEXT}"
! git rev-parse --quiet --verify "refs/tags/${TAG}" >/dev/null || die "태그 ${TAG} 가 이미 있다"

# 3. 릴리스 노트 — 한 줄 요약과 지난 릴리스 뒤의 커밋 제목.
NOTES="$(mktemp -t mmt-release)"
trap 'rm -f "$NOTES"' EXIT
{
    echo "$SUMMARY"
    echo
    if [ -n "$PREVIOUS" ]; then
        echo "## ${PREVIOUS} 뒤의 커밋"
        git log --reverse --format='- %s' "${PREVIOUS}..HEAD"
    else
        echo "첫 릴리스."
    fi
} > "$NOTES"

# 4. 번호를 올린 커밋. PlistBuddy 는 파일 모양을 다시 써서 한 줄만 바꾼다.
if [ "$KIND" != "initial" ]; then
    /usr/bin/perl -0pi -e "s#(<key>${KEY}</key>\\s*<string>)[^<]*(</string>)#\${1}${NEXT}\${2}#" "$PLIST"
    [ "$(read_version)" = "$NEXT" ] || die "${PLIST} 의 번호를 바꾸지 못했다"
    git add "$PLIST"
    git commit --quiet -m "Release ${NEXT}" -m "$SUMMARY" "$@"
fi

# 5. 태그·푸시·Release. 커밋과 태그는 함께 올라가거나 함께 실패한다.
git tag -a "$TAG" -m "$TAG" -m "$SUMMARY"
git push --quiet --atomic origin HEAD:main "refs/tags/${TAG}"
if ! "$GH" release create "$TAG" --verify-tag --title "$TAG" --notes-file "$NOTES"; then
    die "태그 ${TAG} 는 올라갔지만 Release 를 만들지 못했다. 업데이트에 보이려면 다시 만든다:
  gh release create ${TAG} --verify-tag --title ${TAG} --notes \"${SUMMARY}\""
fi
echo "released ${TAG}"
