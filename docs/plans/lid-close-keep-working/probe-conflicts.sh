#!/bin/bash
# Phase 1 — 기능 A("화면 끄고 작업")와 기능 B("덮개 닫아도 작업 진행")의
# 시스템 레벨 상충 여부를 앱 코드 없이 확정한다.
#
#   sudo bash docs/plans/lid-close-keep-working/probe-conflicts.sh [--sleepnow]
#
# 화면이 3~4회 껐다 켜진다. 약 40초. --sleepnow 를 주면 맥이 실제로 잠들 수 있다.
# 판정은 CGDisplayIsAsleep 로 한다. BlackWorkManager 가 쓰는 API 와 동일하다.

set -u

[ "$(id -u)" -eq 0 ] || { echo "sudo 로 실행하세요."; exit 1; }

WORK=$(mktemp -d)
RESULT="${WORK}/result.txt"
INCLUDE_SLEEPNOW=0
[ "${1:-}" = "--sleepnow" ] && INCLUDE_SLEEPNOW=1

cleanup_and_report() {
    /usr/bin/pmset -a disablesleep "$ORIG_FLAG" 2>/dev/null
    /usr/bin/caffeinate -u -t 1 2>/dev/null
    echo
    echo "================ 결과 ================"
    cat "$RESULT"
    echo "======================================"
    echo "disablesleep 을 원래 값($ORIG_FLAG)으로 복원했습니다."
    ioreg -n IOPMrootDomain -r -d 1 | grep SleepDisabled
}
trap cleanup_and_report EXIT

# --- 프로브 준비 (기능 A 와 동일한 판정 API) ---
cat > "${WORK}/probe.swift" <<'SWIFT'
import CoreGraphics
print(CGDisplayIsAsleep(CGMainDisplayID()) != 0 ? "ASLEEP" : "AWAKE")
SWIFT
echo "프로브 컴파일 중..."
swiftc -O "${WORK}/probe.swift" -o "${WORK}/probe" || { echo "컴파일 실패"; exit 1; }
PROBE="${WORK}/probe"

ORIG=$(ioreg -n IOPMrootDomain -r -d 1 | awk -F'= ' '/SleepDisabled/{gsub(/[ "]/,"",$2);print $2}')
[ "$ORIG" = "Yes" ] && ORIG_FLAG=1 || ORIG_FLAG=0
echo "시작 시 SleepDisabled=$ORIG (복원 대상: $ORIG_FLAG)"
echo

record() { printf '%-28s %s\n' "$1" "$2" >> "$RESULT"; }

wake_display() { /usr/bin/caffeinate -u -t 1; sleep 2; }

# 목표 상태가 될 때까지 최대 $2 초 기다린다. 되면 0, 안 되면 1.
poll_until() {
    local target="$1" limit=$(( $2 * 2 )) i=0
    while [ $i -lt $limit ]; do
        [ "$("$PROBE")" = "$target" ] && return 0
        i=$((i+1)); sleep 0.5
    done
    return 1
}

# ---------------- T1 대조군 ----------------
echo "[T1] 대조군 — disablesleep=0 에서 displaysleepnow"
/usr/bin/pmset -a disablesleep 0
wake_display
/usr/bin/pmset displaysleepnow
if poll_until ASLEEP 6; then
    record "T1 대조군 (disablesleep=0)" "PASS — 화면 꺼짐"
else
    record "T1 대조군 (disablesleep=0)" "FAIL — 안 꺼짐 (환경 문제. 재생 중인 영상/assertion 확인)"
fi
wake_display

# ---------------- T2 (C1) 핵심 ----------------
echo "[T2] C1 — disablesleep=1 에서 displaysleepnow"
/usr/bin/pmset -a disablesleep 1
sleep 1
/usr/bin/pmset displaysleepnow
if poll_until ASLEEP 6; then
    record "T2 (C1) disablesleep=1" "PASS — 화면 꺼짐. 동시 실행 가능"
    T2=PASS
else
    record "T2 (C1) disablesleep=1" "FAIL — 안 꺼짐. 동시 실행 설계 재검토 필요"
    T2=FAIL
fi

# ---------------- T3 (C3) ----------------
echo "[T3] C3 — 화면이 꺼진 상태에서 disablesleep 0→1 이 화면을 깨우는가"
/usr/bin/pmset -a disablesleep 0
wake_display
/usr/bin/pmset displaysleepnow
if poll_until ASLEEP 6; then
    /usr/bin/pmset -a disablesleep 1     # 꺼진 상태에서 플래그 전환
    sleep 3
    if [ "$("$PROBE")" = "ASLEEP" ]; then
        record "T3 (C3) 플래그 전환" "PASS — 화면 그대로 꺼져 있음"
    else
        record "T3 (C3) 플래그 전환" "FAIL — 화면이 깨어남. B 토글 시 A 가 꺼둔 화면이 되살아남"
    fi
else
    record "T3 (C3) 플래그 전환" "SKIP — 화면을 끄지 못해 측정 불가"
fi
wake_display

# ---------------- T4 (C2) 옵트인 ----------------
if [ "$INCLUDE_SLEEPNOW" -eq 1 ]; then
    echo "[T4] C2 — disablesleep=1 에서 pmset sleepnow. 맥이 잠들 수 있습니다."
    /usr/bin/pmset -a disablesleep 1
    sleep 1
    BEFORE=$(pmset -g log | grep -c 'Entering Sleep')
    record "T4 (C2) 실행 시각" "$(date '+%H:%M:%S') — 이후 로그를 확인하세요"
    /usr/bin/pmset sleepnow
    sleep 12
    AFTER=$(pmset -g log | grep -c 'Entering Sleep')
    if [ "$AFTER" -gt "$BEFORE" ]; then
        record "T4 (C2) sleepnow" "FAIL — 잠들었음. B 가 시스템 잠자기를 못 막음"
    else
        record "T4 (C2) sleepnow" "PASS — 잠들지 않음. A 의 '끝나면 잠자기'는 B 가 켜지면 무효"
    fi
else
    record "T4 (C2) sleepnow" "미실행 — --sleepnow 인자로 옵트인"
fi

echo
echo "측정 완료."
