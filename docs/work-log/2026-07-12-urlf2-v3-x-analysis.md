# URLFavorites v3.0 X 콘텐츠 분석

- 날짜: 2026-07-12
- 범위: Feature 1 / Task B

## 구현

- `x.com`, `twitter.com`, `mobile.twitter.com`을 `twitter` content type으로 감지한다.
- Twitter extractor는 X 원문을 직접 요청하지 않고 기존 Webpage Jina fetch/parse 경로를 재사용한다.
- Jina 결과에 동영상 힌트가 있을 때만 yt-dlp 메타데이터와 자막을 사용하며, 실패하면 Jina 텍스트로 분석을 계속한다.
- Twitter 전용 Solid Queue job이 공통 `RunAnalysis` use case에 위임하고, 캐시된 raw content 및 Task A의 길이 기반 backend routing을 그대로 사용한다.
- LlamaServer client는 Twitter prompt 규칙만 추가했으며 Task A의 backend 선택·failover 로직은 변경하지 않았다.
- 프로젝트 문서가 지정한 로컬 LLM dispatch 경로(`/Users/hwandam/workspace/infrastructure/llm-orchestration`)는 머신에 없어 직접 구현으로 에스컬레이션했다.

## 검증

- `bundle exec rubocop -a`: 146 files, 위반 0
- `bin/rails test`: 197 runs, 579 assertions, 0 failures, 0 errors, 0 skips
