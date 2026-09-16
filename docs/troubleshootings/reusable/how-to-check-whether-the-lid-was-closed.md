# 덮개를 정말 닫았었는지 나중에 확인하는 법

## 환경

- macOS 26 (Darwin 25.6.0), Apple Silicon (MacBook)

## 증상

덮개 관련 테스트를 끝내고 나서 "정말 닫혀 있던 게 맞나" 를 확인할 방법이 없어, 측정
결과를 해석할 수 없었다.

## 원인

덮개 상태를 직접 읽는 공개 API 가 마땅치 않다. 대신 powerd 가 **덮개가 열릴 때**
`UserIsActive "com.apple.powermanagement.lidopen"` assertion 을 만든다는 점을 역으로 쓴다.

## 해결

```bash
pmset -g assertions | grep -i lidopen
# 유지 시간(00:08:02 같은)이 곧 "그 시각부터 계속 열려 있었다" 는 뜻이다.

pmset -g log | grep -i lidopen | tail -3
# Created 시각 = 덮개가 열린 시각. 그 전까지 닫혀 있었다는 뜻.
```

## 재발 방지

덮개 관련 측정은 **결과를 보기 전에 관측 구간의 덮개 상태부터 확인**한다.

한 번은 이걸 안 보고 "패킷 손실 0" 만 보고 통과로 오판할 뻔했다. 관측 구간 내내 덮개가
열려 있었으므로 아무것도 검증하지 못한 측정이었다.
