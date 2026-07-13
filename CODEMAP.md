# Codemap: URLFavorites 2.0

URLFavorites 2.0 is a Ruby on Rails application designed for managing and analyzing bookmarked URLs. It uses a structured architecture inspired by **Hexagonal Architecture** (or Clean Architecture) to separate domain logic, use cases, and infrastructure integrations.

## 🏗 Architecture Overview

The core logic resides in `app/url_favorites/`, organized into three layers:
- **Domain**: Core business rules and entities.
- **Use Cases**: Application-specific business rules.
- **Integrations**: Adapters for external systems (LLMs, Search, Scraping).

---

## 📂 Directory Structure

### 1. `app/models/` (ActiveRecord Models)
- `Favorite`: The central entity representing a bookmarked URL.
- `Analysis`: Stores AI-generated analysis of a favorite.
- `Collection`: Groups of favorites.
- `CollectionMembership`: Join model for favorites and collections.
- `TagFeedback`: Feedback on AI-generated tags.

### 2. `app/controllers/`
- `FavoritesController`: Main interface for listing, creating, and viewing favorites.
- `CollectionsController`: CRUD for collections.
- `FavoriteNotesController`: Handles updates to personal notes on favorites.
- `CollectionMembershipsController`: Manages adding/removing favorites from collections.

### 3. `app/url_favorites/` (Core Logic)

#### 🧬 Domain (`app/url_favorites/domain/`)
- `Analysis`: Retry policies, prompt styles, and **`BackendRouter`** (multi-LLM 라우팅: content_type/length → `heavy`/`fast` role 우선순위).
- `Tags`: Logic for tag learning and management.
- `Urls`: URL normalization, **type detection (webpage / youtube / github / twitter)**, category detection, and safety policies.

#### 🚀 Use Cases (`app/url_favorites/use_cases/`)
- `Analysis`: Enqueueing and running webpage/YouTube analysis.
- `Favorites`: Creating, deleting, toggling pins, and updating categories.
- `Collections`: Adding and removing favorites from collections.
- `Search`: Semantic and keyword search implementation.
- `Newsletter`: Sending weekly digests.
- `Importers`: Importing snapshots from previous versions (URLFavorites 1.0).

#### 🔌 Integrations (`app/url_favorites/integrations/`)
- `LlamaServer`: Client for the llama-server. **다중 백엔드(`LLM_BACKENDS`) + `BackendRouter` 정렬 + failover**, type별 system prompt(youtube/twitter 전용 규칙 포함, detail은 한국어 강제).
- `Search`: Indexing and searching using embeddings and semantic search (`EMBEDDING_URL` 분리 가능).
- `Webpage`: Scraper for standard URLs (Cloudflare 차단 시 Jina Reader fallback).
- `Youtube`: Extractor for transcripts and metadata from YouTube videos.
- **`Twitter`**: X(트위터) extractor — 개별 트윗은 **X syndication API**(키 불필요), 실패 시 Jina Reader, 동영상은 yt-dlp fallback.

---

## ⚙️ Background Processing (`app/jobs/`)
- `AnalyzeWebpageJob` / `AnalyzeWebpageAnalysisJob`: Scraping + AI analysis for webpages/GitHub.
- `AnalyzeYoutubeJob`: Transcript extraction + AI analysis for YouTube videos.
- **`AnalyzeTwitterJob`**: X(트위터) 트윗 추출(syndication/Jina) + AI analysis.
- `ReindexFavoriteJob`: Updates the semantic search index for a favorite.
- `WeeklyNewsletterJob`: Aggregates and sends the weekly digest.

> 라우팅: `enqueue_analysis`가 `content_type`으로 job 분기 → `RunAnalysis`가 extract → `LlamaServer::Client`(BackendRouter로 heavy/fast 라우팅). Solid Queue AI 동시성 2(서버 `-np 1`).

---

## 🛣 Main Routes (`config/routes.rb`)
- `GET /`: `favorites#index` (Root)
- `resources :favorites`: Index, Create, Show, Destroy.
  - `PATCH /favorites/:id/note`: Update notes.
  - `POST /favorites/:id/retry`: Retry failed analysis.
  - `POST /favorites/:id/toggle_pin`: Pin/unpin favorite.
  - `PATCH /favorites/:id/update_category`: Change category.
- `resources :collections`: CRUD for collections.

---

## 🧪 Testing (`test/`)
The project uses Minitest for:
- **Models**: Business logic validation.
- **Controllers**: Request/Response testing.
- **System**: End-to-end flow testing (e.g., `FavoritesFlowTest`).
- **Use Cases & Integrations**: Isolated testing of core logic and external adapters.
