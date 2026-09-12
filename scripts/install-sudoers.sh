#!/bin/bash
# "덮개 닫아도 작업 진행" 기능을 암호 없이 쓰기 위한 sudoers 규칙을 설치한다.
#
#   sudo bash scripts/install-sudoers.sh            # 설치
#   sudo bash scripts/install-sudoers.sh --uninstall # 제거
#
# 이 규칙 없이도 앱은 동작한다. 없으면 관리자 인증 창을 띄우는 경로로 넘어간다.
#
# 허용 범위는 정확히 두 개의 명령뿐이다. `pmset *` 같은 와일드카드를 쓰면
# 다른 전원 설정까지 열리므로 argv 를 끝까지 고정한다. 이 권한으로 할 수 있는 일은
# "맥을 안 재운다" 하나뿐이며, 파일 접근이나 프로세스 실행으로 이어지지 않는다.

set -eu

RULE_PATH="/etc/sudoers.d/mymactools"

[ "$(id -u)" -eq 0 ] || { echo "sudo 로 실행하세요."; exit 1; }

# sudo 로 실행됐으므로 실제 사용자는 SUDO_USER 다. 없으면 root 로 설치하려는 것이므로 막는다.
TARGET_USER="${SUDO_USER:-}"
if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
    echo "일반 사용자 계정에서 sudo 로 실행하세요. (SUDO_USER 를 확인할 수 없음)"
    exit 1
fi

if [ "${1:-}" = "--uninstall" ]; then
    if [ -f "$RULE_PATH" ]; then
        rm -f "$RULE_PATH"
        echo "제거했습니다: $RULE_PATH"
        echo "앱은 이제 관리자 인증 창을 띄우는 방식으로 돌아갑니다."
    else
        echo "설치되어 있지 않습니다: $RULE_PATH"
    fi
    exit 0
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

cat > "$TMP" <<EOF
# MyMacTools — "덮개 닫아도 작업 진행"
# 정확한 argv 두 개만 허용한다. 와일드카드를 쓰지 않는다.
${TARGET_USER} ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
EOF

# 문법이 틀린 파일을 /etc/sudoers.d 에 넣으면 sudo 전체가 망가진다. 넣기 전에 반드시 검사한다.
if ! visudo -c -f "$TMP" >/dev/null 2>&1; then
    echo "문법 검사 실패. 설치를 중단합니다."
    visudo -c -f "$TMP" || true
    exit 1
fi

install -m 440 -o root -g wheel "$TMP" "$RULE_PATH"
echo "설치했습니다: $RULE_PATH"
cat "$RULE_PATH" | sed 's/^/  /'

# 전체 sudoers 가 여전히 유효한지 확인한다. 여기서 깨지면 즉시 되돌린다.
if ! visudo -c >/dev/null 2>&1; then
    rm -f "$RULE_PATH"
    echo "설치 후 sudoers 전체 검사에 실패해 되돌렸습니다."
    exit 1
fi

echo
echo "동작 확인:"

# `sudo -n -l` 로 확인하면 안 된다. `-l` 은 "암호 없이 되는가"가 아니라 "허용되는가"를
# 보므로, 관리자 계정이면 %admin 의 (ALL) ALL 때문에 규칙과 무관하게 무엇이든 통과한다.
# 실제로 실행해봐야만 알 수 있다. 현재 값을 그대로 다시 쓰면 상태가 바뀌지 않는다.
CURRENT=$(ioreg -n IOPMrootDomain -r -d 1 \
          | awk -F'= ' '/SleepDisabled/{gsub(/[ "]/,"",$2);print $2}')
[ "$CURRENT" = "Yes" ] && SAME=1 || SAME=0

# 대상 사용자의 자격 캐시가 남아 있으면 규칙이 없어도 통과해버린다. 비우고 잰다.
sudo -u "$TARGET_USER" sudo -k 2>/dev/null || true

if sudo -u "$TARGET_USER" sudo -n /usr/bin/pmset -a disablesleep "$SAME" >/dev/null 2>&1; then
    echo "  OK — ${TARGET_USER} 가 암호 없이 실행할 수 있습니다."
    echo "  (확인용으로 현재 값 ${SAME} 을 그대로 다시 썼습니다. 상태는 바뀌지 않았습니다.)"
else
    rm -f "$RULE_PATH"
    echo "  실패 — 규칙이 적용되지 않아 되돌렸습니다."
    echo "  앱은 관리자 인증 창 방식으로 동작합니다."
    exit 1
fi

echo
echo "제거하려면: sudo bash scripts/install-sudoers.sh --uninstall"
