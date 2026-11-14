# context — hosts 파일 열기

## 확인한 것 (2026-11-14, 이 맥)
- `/etc/hosts` — `root:wheel`, `644`. 내용 형식 `kMDItemContentType = public.data`(확장자 없음)
- 시스템 기본 열기 앱(`NSWorkspace.urlForApplication(toOpen:)`) = TextEdit
- `urlsForApplications(toOpen: /etc/hosts)` — TextEdit·메모·iTerm·압축 해제·Claude·ChatGPT. **VS Code 가 없다**
- `urlsForApplications(toOpen: .plainText)` — Word·Excel·브라우저와 캐시 안의 테스트용 VS Code·Chrome 사본까지 나온다
- `LSCopyAllRoleHandlersForContentType(public.plain-text, .editor)` — 그래도 Word·Excel·HWP 뷰어가 섞이고 deprecated
- → 목록을 만들지 않고 사용자가 한 번 고르게 한다. 편집기 이름을 앱에 박지도 않는다

## 저장 키
- `hostsEditorPath` — 고른 앱의 경로. 없으면(지웠거나 앱이 사라짐) 시스템 기본
