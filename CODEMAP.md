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
- `Analysis`: Logic for analysis retry policies.
- `Tags`: Logic for tag learning and management.
- `Urls`: URL normalization, type detection (Webpage vs Youtube), and safety policies.

#### 🚀 Use Cases (`app/url_favorites/use_cases/`)
- `Analysis`: Enqueueing and running webpage/YouTube analysis.
- `Favorites`: Creating, deleting, toggling pins, and updating categories.
- `Collections`: Adding and removing favorites from collections.
- `Search`: Semantic and keyword search implementation.
- `Newsletter`: Sending weekly digests.
- `Importers`: Importing snapshots from previous versions (URLFavorites 1.0).

#### 🔌 Integrations (`app/url_favorites/integrations/`)
- `LlamaServer`: Client for interacting with the Llama-based inference server.
- `Search`: Indexing and searching using embeddings and semantic search.
- `Webpage`: Scraper for extracting content from standard URLs.
- `Youtube`: Extractor for fetching transcripts and metadata from YouTube videos.

---

## ⚙️ Background Processing (`app/jobs/`)
- `AnalyzeWebpageJob`: Triggers scraping and AI analysis for standard webpages.
- `AnalyzeYoutubeJob`: Triggers transcript extraction and AI analysis for YouTube videos.
- `ReindexFavoriteJob`: Updates the semantic search index for a favorite.
- `WeeklyNewsletterJob`: Aggregates and sends the weekly digest.

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
