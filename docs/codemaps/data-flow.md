# Data Flow Codemap: URL to Searchable Analysis

This map traces the lifecycle of a favorite from creation to being searchable via semantic search.

## 1. Creation Phase (Sync)
1. **User** submits URL → `FavoritesController#create`
2. `UrlFavorites::UseCases::Favorites::CreateFavorite` is invoked.
3. **Domain Logic**:
   - `Urls::Normalizer`: Cleans the URL.
   - `Urls::SafetyPolicy`: Validates the URL is safe (no internal IPs).
   - `Urls::TypeDetector`: Determines content type — `webpage` / `youtube` / `github` / `twitter`.
4. **Persistence**: `Favorite` record is saved to SQLite.
5. **Trigger**: `UrlFavorites::UseCases::Analysis::EnqueueAnalysis` is called.

## 2. Analysis Phase (Async)
1. **Solid Queue** picks up `AnalyzeWebpageJob` / `AnalyzeYoutubeJob` / `AnalyzeTwitterJob` (by `content_type`).
2. `UrlFavorites::UseCases::Analysis::RunAnalysis` is invoked (`raw_content` 있으면 재사용).
3. **Extraction**:
   - Webpage/GitHub: `Webpage::Scraper` (Nokogiri, CF 차단 시 Jina fallback).
   - Youtube: `Youtube::Extractor` (yt-dlp).
   - Twitter: `Twitter::Extractor` — 개별 트윗은 X syndication API, 실패 시 Jina, 동영상 yt-dlp.
4. **AI Analysis**:
   - `LlamaServer::Client`가 `BackendRouter`로 백엔드 선택(긴 콘텐츠·detail → `heavy`, 그 외 → `fast`) 후 요청, 실패 시 failover.
   - LLM returns `summary`(한국어), `tags`, `key_points`, `sentiment`, `detail_content`(원문 언어 무관 한국어).
5. **Persistence**: `Analysis` record is saved, linked to `Favorite`. `Favorite#status` set to `done`.

## 3. Indexing Phase (Async)
1. Analysis success triggers `ReindexFavoriteJob`.
2. `UrlFavorites::UseCases::Search::ReindexFavorite` is invoked.
3. **Embedding**:
   - `UrlFavorites::Integrations::Search::EmbeddingClient` generates vector for the analysis.
4. **Indexing**:
   - `UrlFavorites::Integrations::Search::Indexer` updates SQLite FTS5 / Vector index.

## 4. Discovery Phase (Sync)
1. **User** searches → `FavoritesController#index(q: "...")`
2. `UrlFavorites::UseCases::Search::FavoriteSearch` is invoked.
3. **Semantic Search**:
   - `UrlFavorites::Integrations::Search::SemanticClient` performs vector similarity search.
4. **Results**: Top matches are returned and rendered in `favorites/_favorite_card`.
