# URLFavorites 2.0

Personal URL bookmark manager with automatic AI analysis. Saves URLs, extracts content, generates AI summaries/tags/key points using Qwen3-30B via llama-server.

## Tech Stack

- Rails 8.1.x, Ruby 3.4.x
- SQLite3 + Solid Queue
- Hotwire (Turbo + Stimulus) + Tailwind CSS
- AI: Qwen3-30B via llama-server (WireGuard VPN)
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
deploy urlfavorites
```

## Data Migration

One-time import from urlf:

```bash
bin/rails urlf:import URLF_SOURCE_DB_PATH=/path/to/urlf.sqlite3
```
