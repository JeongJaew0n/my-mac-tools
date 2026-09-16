# 스크립트가 안내한 명령을 복사해 실행하면 `No such file or directory`

## 증상

`sudo bash scripts/install-sudoers.sh` 를 안내 문구에서 복사해 실행했더니
`No such file or directory`. 두 번 겪었다.

## 원인

안내 문구가 **상대 경로**로 적혀 있었다. 레포 루트가 아닌 디렉터리에서 실행하면 깨진다.

## 해결

스크립트가 자기 위치를 절대 경로로 풀어서 안내한다.

```bash
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
```

## 재발 방지

**사용자가 복사해 붙여넣을 명령은 항상 절대 경로로 출력한다.** 실행 위치를 가정하지
않는다.
