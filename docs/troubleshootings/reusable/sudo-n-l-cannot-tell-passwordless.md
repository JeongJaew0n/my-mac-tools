# `sudo -n -l` 로는 "암호 없이 실행되는지" 판정할 수 없다

## 환경

- macOS 26 (Darwin 25.6.0), Apple Silicon
- 관리자 계정 (`%admin ALL=(ALL) ALL` 에 해당)
- `sudoers.d` 로 특정 명령만 `NOPASSWD` 허용하는 구성

## 증상

`sudoers` 규칙이 제대로 깔리지 않았는데도, 설치 스크립트가 "OK, 암호 없이 실행할 수
있습니다" 라고 보고했다. 같은 방식으로 판정하던 앱 코드도 똑같이 속았다.

## 원인

`sudo -l` 은 **"이 명령이 허용되는가"** 를 보지, **"암호 없이 되는가"** 를 보지 않는다.

관리자 계정은 `%admin ALL=(ALL) ALL` 에 걸리므로 무엇이든 허용으로 나온다. 게다가 한 번
암호를 넣어 통과하면 **자격 캐시**가 생겨 그 뒤로는 전부 통과한다. 그래서 규칙이 없어도
있는 것처럼 보인다.

규칙에 없는 명령으로 재보면 바로 드러난다.

```bash
sudo -k                       # 자격 캐시부터 비운다. 안 비우면 전부 통과한다
sudo -n -v                    # → "a password is required" (캐시 없음 확인)
sudo -n -l /bin/ls; echo $?   # → 0.  규칙에 없는데도 통과한다
```

## 해결

**실제로 실행해봐야만 알 수 있다.** 단, 상태를 바꾸면 안 되므로 **현재 값을 그대로 다시
쓰는 무해한 명령**을 프로브로 쓴다.

```bash
# 예: pmset -a disablesleep 을 NOPASSWD 로 허용했는지 판정
CUR=$(ioreg -n IOPMrootDomain -r -d 1 | awk -F'= ' '/SleepDisabled/{gsub(/[ "]/,"",$2);print $2}')
[ "$CUR" = "Yes" ] && SAME=1 || SAME=0
sudo -k
sudo -n /usr/bin/pmset -a disablesleep "$SAME"   # 성공해야 진짜 암호 없이 되는 것
```

통하지 않은 시도 — `sudo -n -l <명령>`, `sudo -l | grep NOPASSWD`. 둘 다 관리자 계정의
포괄 규칙과 자격 캐시에 가려진다.

## 재발 방지

- 규칙 범위를 검사할 때 **매 시도마다 `sudo -k`** 를 넣는다. 안 넣으면 첫 허용 명령이
  캐시를 만들어 그 뒤 전부 ALLOW 로 보인다.
- "암호 없이 되는가" 는 조회가 아니라 **실행**으로만 답할 수 있다는 것을 판정 코드
  주석에 남긴다.
