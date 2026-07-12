# Data Flow Codemap: URL to Searchable Analysis

This map traces the lifecycle of a favorite from creation to being searchable via semantic search.

## 1. Creation Phase (Sync)
1. **User** submits URL → `FavoritesController#create`
2. `UrlFavorites::UseCases::Favorites::CreateFavorite` is invoked.
3. **Domain Logic**:
   - `Urls::Normalizer`: Cleans the URL.
   - `Urls::SafetyPolicy`: Validates the URL is safe (no internal IPs).
   - `Urls::TypeDetector`: Determines if it's `webpage` or `youtube`.
4. **Persistence**: `Favorite` record is saved to SQLite.
5. **Trigger**: `UrlFavorites::UseCases::Analysis::EnqueueAnalysis` is called.

## 2. Analysis Phase (Async)
1. **Solid Queue** picks up `AnalyzeWebpageJob` or `AnalyzeYoutubeJob`.
2. `UrlFavorites::UseCases::Analysis::RunAnalysis` is invoked.
3. **Extraction**:
   - If Webpage: `UrlFavorites::Integrations::Webpage::Scraper` (Nokogiri).
   - If Youtube: `UrlFavorites::Integrations::Youtube::Extractor` (yt-dlp).
4. **AI Analysis**:
   - `UrlFavorites::Integrations::LlamaServer::Client` sends content to LLM.
   - LLM returns `summary`, `tags`, `key_points`, `sentiment`.
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
