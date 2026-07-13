# X 개별 트윗 syndication 추출 우회

- 날짜: 2026-07-13
- 범위: URLFavorites v3.0 / Task G

## 원인

개별 X URL을 모두 Jina Reader에 전달했으나, Jina 무인증 tier가 `x.com`을 abuse 차단하여 HTTP 403을 반환했다. `yt-dlp`는 동영상 트윗만 처리하므로 텍스트 트윗 분석에는 사용할 수 없었다.

## 수정

- `/status/<id>` URL은 `cdn.syndication.twimg.com/tweet-result`를 브라우저 User-Agent와 함께 먼저 요청한다.
- syndication JSON에서 본문, 인용 트윗, 작성자, 제목, 이미지, 동영상 여부를 추출한다.
- syndication이 비-200이거나 JSON 파싱에 실패하면 기존 Jina 경로로 폴백한다.
- 동영상 트윗은 기존 yt-dlp 자막·썸네일 보강 로직을 재사용한다.
- 프로필 등 `/status/`가 없는 X URL은 기존 Jina 경로를 유지한다.
- 프로젝트 문서의 로컬 LLM dispatch 경로가 이 머신에 없어 직접 구현했다.

## 검증

- `test/url_favorites/integrations/twitter/extractor_test.rb`: syndication 성공/폴백/프로필/동영상 경로 검증
- `bundle exec rubocop -a`
- `bin/rails test`
