# URLFavorites 2.0

Personal URL bookmark manager with automatic AI analysis. Saves URLs, extracts content, generates AI summaries/tags/key points using Qwen3.6-35B via llama-server.

## Tech Stack

- Rails 8.1.x, Ruby 3.4.x
- SQLite3 + Solid Queue
- Hotwire (Turbo + Stimulus) + Tailwind CSS
- AI: Qwen3.6-35B via llama-server (WireGuard VPN)
- Current local llama-server model: `Qwen3.6-35B-A3B-Kimi-K2.6-Reasoning-Distilled.Q5_K_M.gguf`
- Scraping: Nokogiri (web), yt-dlp (YouTube)

## Local Setup

```bash
bundle install
bin/rails db:prepare
bin/rails server
```

## Environment Variables

| Variable           | Required         | Description                  |
|--------------------|------------------|------------------------------|
| LLAMA_SERVER_URL   | Yes (production) | llama-server endpoint URL    |
| RAILS_ENV          | Yes              | development/test/production  |
| SECRET_KEY_BASE    | Yes (production) | Rails secret key             |
| RAILS_MASTER_KEY   | Yes (production) | Credentials decryption       |

## Dependencies

- yt-dlp must be installed on the deployment server

## Tests

```bash
bin/rails test
bin/rails test:system
```

## Deployment

```bash
bin/deploy-doctor pre
bin/deploy urlfavorites_2.0
bin/deploy-doctor post
```

Development happens on macOS. The VPS is a deployment target only; do not edit
source files there except for emergency investigation. See
`docs/deploy/git-based-workflow.md`.

Production SQLite files live under `storage/` on the VPS and must never be
deleted or overwritten by source deploys.

## Data Migration

One-time import from urlf:

```bash
bin/rails urlf:import URLF_SOURCE_DB_PATH=/path/to/urlf.sqlite3
```
