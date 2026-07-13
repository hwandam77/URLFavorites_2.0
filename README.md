# URLFavorites 2.0

Personal URL bookmark manager with automatic AI analysis. Saves URLs, extracts content, generates AI summaries/tags/key points/detail (Korean) using local Qwen3.x models via llama-server.

## Tech Stack

- Rails 8.1.x, Ruby 3.4.x
- SQLite3 + Solid Queue
- Hotwire (Turbo + Stimulus) + Tailwind CSS
- **Content types**: webpage, YouTube, GitHub, **X (Twitter)** — detected by `Domain::Urls::TypeDetector`
- **AI (multi-LLM routing)**: `LLM_BACKENDS` JSON로 여러 llama-server를 role별 라우팅. `Domain::Analysis::BackendRouter`가 긴 콘텐츠·detail 스타일 → `heavy`(예: synapse 40B), 짧은 콘텐츠·임베딩 → `fast`(예: beacon 35B A3B). 라우팅 실패 시 failover.
- **Extraction**: Nokogiri (web) · yt-dlp (YouTube/동영상 트윗) · X syndication API + Jina Reader (트윗 텍스트)

## Local Setup

```bash
bundle install
bin/rails db:prepare
bin/rails server
```

## Environment Variables

| Variable           | Required         | Description                                                        |
|--------------------|------------------|-------------------------------------------------------------------|
| LLAMA_SERVER_URL   | Yes (production) | llama-server endpoint URL (단일 백엔드 fallback)                  |
| LLM_BACKENDS       | No               | 멀티 LLM 라우팅 JSON 배열: `[{"url","model","role":"heavy\|fast","timeout"}]`. 미설정 시 LLAMA_SERVER_URL 단일 사용 |
| EMBEDDING_URL      | No               | 임베딩 전용 엔드포인트 (미설정 시 LLAMA_SERVER_URL 공유). 분석과 자원 경쟁 회피용 |
| RAILS_ENV          | Yes              | development/test/production                                        |
| SECRET_KEY_BASE    | Yes (production) | Rails secret key                                                  |
| RAILS_MASTER_KEY   | Yes (production) | Credentials decryption                                            |

> 프로덕션은 `.env`가 아닌 systemd drop-in `env.conf`로 주입. 배포 절차·정확한 값은 [`docs/deploy/urlf2-v3-deploy-plan.md`](docs/deploy/urlf2-v3-deploy-plan.md) 참조.

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
