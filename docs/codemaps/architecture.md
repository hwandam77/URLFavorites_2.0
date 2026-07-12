# Architecture Codemap: URLFavorites 2.0 (DDD)

This map visualizes the dependency flow and layer responsibilities based on the DDD architecture.

## 🏗 Dependency Flow
`Controllers/Jobs` (Rails Adapters) → `UseCases` → (`Domain` + `Integrations`)

---

## 📂 Layer Responsibilities

### 1. Rails Adapters (`app/controllers/`, `app/jobs/`, `app/models/`)
*Entry points and data persistence.*
- **Controllers**: Handle HTTP requests, call **one** UseCase, return response.
- **Jobs**: Background workers (Solid Queue), call **one** UseCase.
- **Models**: ActiveRecord definitions, associations, simple validations.

### 2. Use Cases (`app/url_favorites/use_cases/`)
*Application logic and orchestration.*
- Coordinate Domain policies and Integration adapters.
- Manage database transactions.
- Examples: `CreateFavorite`, `RunAnalysis`, `AddFavoriteToCollection`.

### 3. Domain (`app/url_favorites/domain/`)
*Pure business logic and policies.*
- **Zero dependencies** on Rails or external services.
- **Urls**: Normalization, Safety (IP blocking), Type detection.
- **Analysis**: Retry policies, state machine rules.
- **Tags**: Learning algorithms.

### 4. Integrations (`app/url_favorites/integrations/`)
*External system adapters.*
- **LlamaServer**: LLM inference client.
- **Youtube**: yt-dlp wrapper for transcripts.
- **Webpage**: Nokogiri scraper.
- **Search**: Embedding and Vector DB (SQLite FTS5) client.

---

## 🗺 Map of Bounded Contexts

| Context | Domain Policies | Key Use Cases | Integrations |
| :--- | :--- | :--- | :--- |
| **Favorites** | `Normalizer`, `SafetyPolicy`, `TypeDetector` | `CreateFavorite`, `DeleteFavorite`, `TogglePin` | - |
| **Analysis** | `RetryPolicy`, `StatusStateMachine` | `RunAnalysis`, `EnqueueAnalysis` | `LlamaServer`, `Webpage`, `Youtube` |
| **Search** | - | `ReindexFavorite`, `FavoriteSearch` | `EmbeddingClient`, `Indexer`, `SemanticClient` |
| **Collections** | - | `AddFavoriteToCollection`, `RemoveFavoriteFromCollection` | - |
| **Newsletter** | `DigestRules` | `SendWeeklyNewsletter` | `Mailer` |
| **Notes** | - | `UpdateFavoriteNote` | - |
| **Importers** | - | `ImportUrlfSnapshot` | `UrlfSnapshot::Reader` |
