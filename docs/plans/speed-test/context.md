# context — speed-test

## 원 요청 (2026-10-09)

> 기능 추가 하나 하자. 인터넷 속도 측정. 설계 문서 작성 ㄱㄱ

## 실측 — `networkQuality` 한 번

macOS 12 부터 `/usr/bin/networkQuality` 가 들어 있다. 이 맥(macOS 26.3.1, Wi-Fi)에서
`-c`(JSON 출력)로 한 번 돌렸다.

```
걸린 시간      21초
쓴 데이터      받음 57 MB · 보냄 90 MB  (netstat -ib 로 en0 차이를 쟀다)
다운로드       20.4 Mbps
업로드         44.9 Mbps
응답성         56 RPM
기본 지연      16 ms
서버           krsel6-edge-fx-013.aaplimg.com (서울 엣지)
```

`dl_throughput` 의 단위를 바이트 수로 검산했다 — `dl_bytes_transferred × 8 / 시간` 이
20.6 Mbps, `dl_throughput` 이 20.4 Mbps. **bit/s 다.**

JSON 에 쓸 만한 키:

| 키 | 뜻 |
|---|---|
| `dl_throughput` · `ul_throughput` | bit/s |
| `responsiveness` | RPM — 회선이 바쁠 때 1분에 주고받을 수 있는 왕복 수. 클수록 좋다 |
| `base_rtt` | 한가할 때의 왕복 지연(ms) |
| `interface_name` · `other.interface-type` | `en0` · `wifi` |
| `test_endpoint` | 측정 서버 |

쓸 만한 옵션: `-M`(최대 실행 시간), `-s`(순차), `-I`(인터페이스 지정), `-d`/`-u`(한쪽만).

## 데이터 사용량이 설계를 정한다

147 MB 는 **20~45 Mbps 회선에서**의 값이다. 측정은 정해진 시간 동안 최대로 흘려보내는
방식이라, **회선이 빠를수록 많이 쓴다.** 기가비트라면 같은 21초에 수 GB 가 될 수 있다.

그래서 이 기능은 이 앱의 다른 목록들과 반대로 간다 — 카페인·포트 목록은 2초마다 훑지만,
이것은 **절대 저절로 돌면 안 된다.** 그리고 테더링·셀룰러처럼 데이터가 비싼 회선에서는
시작 전에 묻는 것이 맞다.

## 기각 — 다른 측정 수단

**Speedtest(Ookla) CLI** — 가장 익숙한 숫자를 준다. 그러나 별도로 설치해야 하고, 앱에
넣어 배포하려면 약관을 따로 확인해야 한다. 내장 도구가 있는데 의존성을 늘릴 이유가 없다.

**fast.com** — 공식 API 가 없다.

**Cloudflare(speed.cloudflare.com)** — 다운·업로드 엔드포인트가 열려 있어 `URLSession` 으로
직접 짤 수 있다. 하지만 측정 방식(병렬 흐름 수, 워밍업, 집계)을 우리가 설계해야 하고, 그
숫자가 맞는지 검증할 기준이 없다. Apple 이 이미 그 일을 해둔 도구를 쓰는 편이 낫다.

**직접 구현** — 측정 서버가 필요하다.

## 기각 — 앱 안에서 `NetworkQuality` 프레임워크

`networkQuality` 를 프레임워크로 부르는 공개 API 는 찾지 못했다. 명령줄 도구를 띄우는
것이 문서화된 유일한 길이다.

## 아직 확인하지 않은 것

- **응답성 등급 기준.** `networkQuality` 의 사람용 출력은 RPM 옆에 등급(낮음/중간/높음)을
  붙인다. 그 경계값을 지어내지 않고, 구현할 때 사람용 출력과 맞춰 확인한다
- **기가비트 회선에서의 실제 데이터 사용량** — 이 맥의 회선으로는 잴 수 없다
- **측정 중 CPU·전력** — 재지 않았다

---

## 편의 기능 — 기준값 출처 (2026-10-09 확인)

> 그리고 여기도 편의 기능하나 더 추가해줘. 몇정도되면 평균적으로 어느정도로 쓸 수 있는지.

측정 결과 아래에 "이 속도로 무엇을 할 수 있는가" 를 보여준다. **기준값은 지어내지 않고
각 서비스의 공식 문서에서 가져왔다.** 응답성 등급을 붙이지 않은 것과 같은 원칙이다.

| 활동 | 쓰는 값 | 출처 |
|---|---|---|
| 4K 영상 | ↓20 Mbps | YouTube 4K "20 Mbps" · Netflix UHD "15 Mbps or higher" → **엄격한 쪽** |
| 1080p 영상 | ↓5 Mbps | YouTube 1080p "5 Mbps" · Netflix FHD "5 Mbps or higher" |
| 720p 영상 | ↓3 Mbps | Netflix HD "3 Mbps or higher" · YouTube 720p "2.5 Mbps" → **엄격한 쪽** |
| 1080p 화상 통화 (1:1) | ↑3.8 ↓3.0 Mbps | Zoom 1:1 1080p "3.8Mbps/3.0Mbps (up/down)" |
| 720p 화상 회의 (여럿) | ↑2.6 ↓1.8 Mbps | Zoom group 720p "2.6Mbps/1.8Mbps (up/down)" |

- Netflix — https://help.netflix.com/en/node/306
- YouTube — https://support.google.com/youtube/answer/78358
- Zoom — https://support.zoom.com/hc/en/article?id=zm_kb&sysparm_article=KB0060748

두 서비스 값이 다르면 **더 엄격한 쪽**을 쓴다. 한쪽에서 버벅일 속도를 "된다" 고 하면 안 된다.
각 줄에 마우스를 올리면 출처가 뜬다.

**기기 한 대 기준**이다. 여러 기기가 함께 쓰면 나눠 갖는다는 것을 화면에 한 줄로 알린다.

### 게임은 뺐다

게임은 대역폭보다 **지연**이 갈리는 분야라 넣을 값어치가 크다. 그런데 기준을 확인하지 못했다.

- Xbox 지원 페이지는 본문을 스크립트로 그려서 원문 HTML 에 수치가 없었다
- PlayStation 연결 문제 페이지는 404 였다

출처 없이 "게임 가능" 을 판정하지 않는다. 확인할 수 있는 공식 기준을 찾으면 넣는다.

### 계산값 — 1 GB 를 옮기는 시간

`8,000,000,000 bit ÷ 측정 속도` 다. 출처가 필요 없는 산수라 넣었다. 이론값이라 실제로는
서버와 혼잡에 따라 더 걸린다.
