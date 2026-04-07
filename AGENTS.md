# URLFavorites — Agent Instructions

## Project Summary

A personal URL bookmark manager with automatic AI analysis.
When a URL (webpage or YouTube) is saved, a local LLM (Qwen3-30B-A3B) automatically extracts summary, tags, key insights, and sentiment.

**Full spec**: `docs/superpowers/specs/2026-03-25-urlfavorites-ai-board-design.md`

---

## Communication

- Communicate with the user in Korean unless they explicitly ask for another language.

---

## Tech Stack

- **Framework**: Rails 8.1.2, Ruby 3.4.9
- **Database**: SQLite3 (main app) + `queue.sqlite3` (Solid Queue)
- **Background jobs**: Solid Queue (Rails 8 built-in)
- **Frontend**: Hotwire — Turbo Frames + Turbo Streams + Stimulus + ActionCable
- **AI model**: Qwen3-30B-A3B-Instruct-2507 (MoE) via llama-server on `beacon` server
- **AI transport**: HTTP over WireGuard VPN — endpoint in `LLAMA_SERVER_URL` env var
- **Web scraping**: Nokogiri (webpages), yt-dlp (YouTube subtitles + metadata)
- **Deployment**: VPS_server via `deploy urlfavorites`

---

## Database Schema

### favorites

| Column        | Type     | Notes                                                   |
| ------------- | -------- | ------------------------------------------------------- |
| id            | integer  | PK                                                      |
| url           | string   | unique                                                  |
| title         | string   | auto-extracted                                          |
| favicon_url   | string   | nullable                                                |
| thumbnail_url | string   | YouTube only, nullable                                  |
| content_type  | string   | `webpage` or `youtube`                                  |
| status        | string   | `pending` → `analyzing` → `done` / `failed`             |
| raw_content   | text     | cached extracted text — reuse on retry, do not re-fetch |
| error_message | text     | nullable, set on failure                                |
| retry_count   | integer  | default 0, max 3                                        |
| created_at    | datetime |                                                         |
| updated_at    | datetime |                                                         |

### analyses

| Column          | Type        | Notes                                                 |
| --------------- | ----------- | ----------------------------------------------------- |
| id              | integer     | PK                                                    |
| favorite_id     | integer     | FK, dependent: :destroy                               |
| summary         | text        | 2–5 sentence AI summary                               |
| tags            | text (JSON) | array of strings                                      |
| key_points      | text (JSON) | array of `{point, timestamp?}`                        |
| sentiment       | string      | `positive`, `neutral`, or `negative`                  |
| transcript      | text        | YouTube subtitle text, nullable                       |
| subtitle_source | string      | `manual`, `auto`, or `description`                    |
| video_metadata  | text (JSON) | channel, views, duration, publish_date (YouTube only) |
| model_used      | string      |                                                       |
| analyzed_at     | datetime    |                                                       |

---

## AI Analysis Pipeline

### State machine

```
pending → analyzing → done
                  ↘ failed (auto-retry up to 3×, exponential backoff: 30s/60s/120s)
                         ↘ failed (manual retry button shown after 3 failures)
```

### Webpage flow (AnalyzeWebpageJob)

1. Set `status: analyzing`, broadcast via ActionCable
2. Nokogiri: extract title, OG tags, body text (max 8,000 chars)
3. Save `raw_content` (reuse if already present)
4. HTTP POST to llama-server (120s timeout)
5. Parse JSON response → create `analyses` record
6. Set `status: done`, broadcast

### YouTube flow (AnalyzeYoutubeJob)

1. Set `status: analyzing`, broadcast
2. `yt-dlp --dump-json` → metadata (title, channel, views, duration, thumbnail)
3. Subtitle fallback chain:
   - `--write-sub` (manual captions) → `subtitle_source: manual`
   - `--write-auto-sub` (auto-generated) → `subtitle_source: auto`
   - description + title → `subtitle_source: description`
4. Truncate to 12,000 chars
5. HTTP POST to llama-server → parse JSON → create `analyses`
6. Set `status: done`, broadcast

### Qwen3 expected JSON output

```json
{
  "summary": "string",
  "tags": ["string"],
  "key_points": [{ "point": "string", "timestamp": "HH:MM:SS" }],
  "sentiment": "positive|neutral|negative"
}
```

On JSON parse failure: log to `error_message`, trigger Solid Queue retry.

---

## REST API

Base path: `/api/v1/`
Auth: none in Phase 1 (VPN-only access). Bearer token added in Phase 2.

| Method | Path                       | Description                                          |
| ------ | -------------------------- | ---------------------------------------------------- |
| GET    | `/favorites`               | List — params: `q`, `tag`, `status`, `limit`, `page` |
| GET    | `/favorites/:id`           | Single item with nested `analysis` object            |
| POST   | `/favorites`               | Create — body: `{ "url": "..." }`                    |
| DELETE | `/favorites/:id`           | Destroy                                              |
| GET    | `/favorites/search?q=`     | Full-text search on title, summary, tags             |
| GET    | `/favorites/recent?limit=` | Recently analyzed items                              |

### Response shape

```json
{
  "id": 1,
  "url": "https://example.com",
  "title": "Page Title",
  "content_type": "webpage",
  "status": "done",
  "created_at": "2026-03-25T10:00:00Z",
  "analysis": {
    "summary": "...",
    "tags": ["tag1", "tag2"],
    "key_points": [{ "point": "...", "timestamp": null }],
    "sentiment": "positive",
    "model_used": "Qwen3-30B-A3B",
    "analyzed_at": "2026-03-25T10:01:30Z"
  }
}
```

---

## PWA / Mobile

- `public/manifest.json` includes `share_target` pointing to `POST /favorites`
- Mobile browsers show the app in the OS share sheet
- `FavoritesController#create` handles both regular form and Share Target requests identically
- Service worker provides offline fallback screen

---

## Turbo Stream Conventions

```ruby
# Broadcast from job
Turbo::StreamsChannel.broadcast_replace_to(
  "favorites",
  target: "favorite_#{favorite.id}",
  partial: "favorites/favorite"
)
Turbo::StreamsChannel.broadcast_replace_to(
  "favorites",
  target: "analysis_panel",
  partial: "favorites/analysis_panel"
)
```

DOM target IDs:

- List item: `favorite_<id>`
- Detail panel: `analysis_panel`

---

## Environment Variables

```bash
LLAMA_SERVER_URL=http://<beacon-wg-ip>:<port>
RAILS_ENV=production
SECRET_KEY_BASE=<generated>
RAILS_MASTER_KEY=<generated>
```

System dependency: `yt-dlp` must be installed on VPS_server.

---

## Implementation Phases

| Phase | Scope                                                              |
| ----- | ------------------------------------------------------------------ |
| 0     | Commit Next.js file deletions, clean git state                     |
| 1     | Rails init → models → AI jobs → board UI → PWA → REST API → deploy |
| 2     | Browser extension (Manifest V3) + Bearer token auth                |

---

## qmd Code Search

Project qmd collection: `urlfavorites`

When using qmd for code search, always scope queries to this collection:

- `qmd search "keyword" -c urlfavorites`
- `qmd query "question" -c urlfavorites`
- `qmd vsearch "question" -c urlfavorites`

After code changes, refresh the qmd index in separate commands:

- `qmd update`
- `qmd embed`

---

## Coding Rules

- Keep controllers thin — business logic in Service objects or Jobs
- All AI analysis MUST be async via Solid Queue — never inline in a request
- Always respect Turbo Stream target ID conventions
- Set 120s timeout on every llama-server HTTP call
- Reuse `raw_content` on retry — never re-fetch if already cached
- Accept only HTTP/HTTPS URLs; reject private/internal IP ranges
- Solid Queue concurrency for AI jobs: max 2 (prevent llama-server OOM)
