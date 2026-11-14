# `SO_NOSIGPIPE` 를 걸었는데도 SIGPIPE 로 서버가 죽는다

## 환경

- macOS 26 (Darwin 25.3.0), Apple Silicon, Swift 6.2
- 유닉스 도메인 소켓(`AF_UNIX`, `SOCK_STREAM`) 서버. 요청 한 줄을 읽고 응답 한 줄을 `write` 로 쓴다
- macOS 에는 `MSG_NOSIGNAL` 이 없어서, 흔히 소켓마다 `SO_NOSIGPIPE` 를 건다

## 증상

클라이언트가 요청을 보내자마자 끊으면 서버 프로세스가 **아무 크래시 리포트 없이** 사라진다.
종료 코드는 141(128 + SIGPIPE 13)이다. 앱이라면 `~/Library/Logs/DiagnosticReports` 에도 아무것도 없다
(SIGPIPE 의 기본 동작은 리포트 없는 종료다).

```text
accept 직후: setsockopt(SO_NOSIGPIPE) → -1, errno 22 (Invalid argument)
write(응답)  → SIGPIPE → 종료 코드 141
```

재현 — 보내고 바로 닫는 클라이언트 몇 번이면 된다.

```python
s = socket.socket(socket.AF_UNIX); s.connect(PATH)
s.sendall(b'{"method":"status"}\n'); s.close()
```

## 원인

**이미 상대가 끊은 연결을 `accept` 하면, 그 소켓에는 `SO_NOSIGPIPE` 가 걸리지 않는다**(`EINVAL`).
요청은 커널 버퍼에 남아 있어 `read` 는 성공하므로 서버는 평소처럼 처리하고, 응답을 쓰는 순간
EPIPE 와 함께 SIGPIPE 를 받는다. 옵션을 걸 때 반환값을 보지 않으면 실패한 줄 모른다.

같은 옵션을 **연결된** 소켓(`socketpair`)에 걸면 잘 듣는다. 그래서 단순한 시험으로는 드러나지 않고,
"보내고 바로 끊는" 클라이언트에서만 나온다 — 클라이언트 타임아웃, Ctrl-C, 앞 요청이 오래 걸린 뒤의
대기열 같은 상황이다.

## 해결

프로세스 전체에서 SIGPIPE 를 무시하고, `write` 의 `-1`/`EPIPE` 로 처리한다.

```swift
signal(SIGPIPE, SIG_IGN)   // 서버를 시작할 때 한 번
```

소켓별 `SO_NOSIGPIPE` 는 겹으로 남겨 둬도 되지만 **그것만으로는 모자란다.**
같은 프로세스에서 `Pipe` 에 쓰는 코드가 있다면, 그쪽도 이제 신호 대신 EPIPE 를 받게 된다는 점만
확인한다(`FileHandle.write` 는 예외를 던질 수 있다).

시도했지만 통하지 않은 것: `accept` 직후 `SO_NOSIGPIPE` 만 거는 것(위 증상 그대로).

## 재발 방지

- 소켓 서버는 시작할 때 `signal(SIGPIPE, SIG_IGN)` 을 기본으로 둔다
- `setsockopt` 반환값을 버리지 않는다
- 시험에 "보내고 바로 끊는 클라이언트" 를 넣는다
