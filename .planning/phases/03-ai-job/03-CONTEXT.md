# Phase 3: AI 추출 + 비동기 Job — Context

## Goal
WebpageScraper, YoutubeExtractor, LlmAnalyzer 서비스와
AnalyzeWebpageJob, AnalyzeYoutubeJob을 TDD로 구현한다.

## Requirements
- R04: 웹페이지 스크래핑 (Nokogiri, OG tags, 본문 8,000자 제한)
- R05: YouTube 추출 (yt-dlp --dump-json, 자막 fallback, 12,000자 제한)
- R06: AI 비동기 분석 (Solid Queue, llama-server 120s timeout)
- R07: 상태 머신 (pending → analyzing → done/failed, 3회 재시도)
- R08: raw_content 캐싱 (재시도 시 재활용)

## Architecture

### Services
- `WebpageScraper.call(url)` → `{ title:, description:, body_text:, og_image: }`
  - Faraday GET + Nokogiri HTML 파싱
  - og:title, og:description, og:image 추출
  - 본문: article/main/body 우선순위, 8,000자 절삭

- `YoutubeExtractor.call(url)` → `{ title:, description:, transcript: }`
  - Open3.capture3("yt-dlp --dump-json #{url}")
  - transcript: subtitles → automatic_captions → description 순서 fallback
  - 12,000자 절삭

- `LlmAnalyzer.call(content, type:)` → `{ summary:, key_points:, tags:, sentiment: }`
  - LLAMA_SERVER_URL 환경변수 필수
  - Faraday POST /v1/chat/completions, timeout 120s
  - JSON 파싱 실패 시 LlmAnalyzer::ParseError

### Jobs (Solid Queue)
- `AnalyzeWebpageJob.perform(favorite_id)`
  - Favorite.find, status pending → analyzing → done/failed
  - WebpageScraper → LlmAnalyzer 순서
  - Analysis upsert (raw_content 캐싱)
  - 실패 시 favorite.status = "failed"

- `AnalyzeYoutubeJob.perform(favorite_id)`
  - 동일 패턴, YoutubeExtractor 사용

## Test Tools
- WebMock (HTTP stub)
- Open3.capture3 stub (yt-dlp)
- Minitest

## Plans
- 03-01-PLAN.md: [Wave 1 RED] 서비스 테스트 3개
- 03-02-PLAN.md: [Wave 1 RED] Job 테스트 2개
- 03-03-PLAN.md: [Wave 2 GREEN] 서비스 구현 3개 (48B)
- 03-04-PLAN.md: [Wave 2 GREEN] Job 구현 2개 (30B×2)
