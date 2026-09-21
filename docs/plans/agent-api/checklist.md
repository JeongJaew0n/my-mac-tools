# checklist — agent-api

`(확인)` 은 사용자가 직접 써보고 확인해준 것, `(실측)` 은 명령·캡처로 확인한 것이다.

## 0. 설계
- [x] 전송 방식 결정 (유닉스 소켓) 과 기각한 넷의 이유 기록
- [x] 메서드 표 · 오류 코드 · 거부 정책 확정
- [x] `spec.md` · `context.md` 작성

## 1. 서버
- [x] `APIServer` — `AF_UNIX` `SOCK_STREAM`, 시작 시 낡은 소켓 파일 제거
- [x] 소켓 파일 권한 `0600` (실측 — `srw-------`)
- [x] `accept` 를 `DispatchSource` 로 받고, 연결마다 한 줄 읽고 한 줄 쓰고 닫는다
- [x] 상태를 건드리는 것은 모두 `MainActor` 로 넘긴다
- [x] 앱 종료 시 소켓 파일 제거 (`applicationWillTerminate`)

## 2. 메서드
- [x] `status` · `sleep.get` · `lid.get` · `cover.get` · `caffeinate.list` · `ports.list`
- [x] `sleep.start` (파라미터 선택 적용) · `sleep.stop`
- [x] `cover.start` (사진 없으면 `preconditionFailed`) · `cover.stop`
- [x] `caffeinate.stop` (이 앱 것이면 매니저 경유)
- [x] `ports.stop` (시스템·자기 자신이면 `forbidden`)
- [x] `ports.open`
- [x] `lid.start` · `lid.stop` → `needsHuman` 으로 거부

## 3. 클라이언트
- [x] `scripts/mymactools` — python3, 인자를 메서드·파라미터로 바꿔 보낸다
- [x] 소켓이 없으면 "앱이 안 떠 있다" 고 말한다 (실측)
- [x] 기본은 `result` 만 예쁘게, `--raw` 는 응답 전체

## 4. 문서
- [x] `docs/api.md` — 메서드 표, 오류 코드, 붙여 쓸 수 있는 예시
- [x] ~~`curl --unix-socket` 예시~~ **틀렸다.** 그 옵션은 유닉스 소켓 위의 HTTP 용이라
      이 서버에는 빈 응답이 온다(실측). `nc -U` 와 python 예시로 바꾸고 문서에 그 사실을 적었다
- [x] MCP 로 감쌀 때의 안내
- [x] `CLAUDE.md` 구조 절에 새 파일 추가
- [x] `README.md` 에 API 절 추가

## 5. 검증
- [x] 앱이 뜨면 소켓이 `0600` 으로 생긴다 (실측)
- [x] `status` 가 네 Tool 상태를 낸다 (실측)
- [x] `nc -U` 와 python 소켓으로도 같은 결과 (실측)
- [x] API 로 잠자기 방지를 켜면 실제로 `caffeinate -di -t 600` 이 뜬다 (실측)
      창 표시도 함께 바뀐다 (확인)
- [x] `ports.list` 결과가 스캐너 결과와 같다 (실측 — 22개)
- [x] 거부 세 가지가 제 코드로 거부된다 (실측 — `needsHuman` · `forbidden` × 2)
- [x] 앱이 안 떠 있으면 클라이언트가 그렇다고 말한다 (실측)
- [x] `kill -9` 뒤 다시 띄워도 소켓이 다시 만들어진다 (실측 — 낡은 파일을 지우고 bind)

## 6. 테스트에서 찾아 고친 것
- [x] `search=8501` 이 전체를 돌려줬다 — 클라이언트가 숫자로 보내는데 서버가 `String` 만
      받아 조용히 무시됐다. 숫자도 받게 고쳤다
- [x] `bundleIdentifier` 가 `-` 로 나왔다 — adhoc 서명의 자리표시자다. 없는 것으로 다룬다
- [x] `curl --unix-socket` 이 된다고 설계에 적었던 것을 바로잡았다
