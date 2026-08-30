# URLFavorites 2.0 — Agent Instructions

## Communication

- Communicate with the user in Korean unless they explicitly ask for another language.
- Before claiming completion, run the command that proves the claim and state the evidence.

## Project Summary

Personal URL bookmark manager with automatic AI analysis. Rails 8 + SQLite + Solid Queue + Hotwire + Tailwind.

- Agent instruction source of truth: `AGENTS.md`
- Design document: `docs/plans/2026-04-07-urlf2-design.md`
- Implementation plan: `docs/plans/2026-04-07-urlf2-implementation.md`
- DDD architecture spec: `docs/superpowers/specs/2026-04-15-ddd-refactor-architecture-design.md`

## Tech Stack

- Framework: Rails 8.1.2, Ruby 3.4.9
- Database: SQLite3 main app database + Solid Queue database
- Background jobs: Solid Queue
- Frontend: Hotwire, Turbo Frames, Turbo Streams, Stimulus, ActionCable, Tailwind
- AI model: Qwen3.6-27B (alias of Qwen3.8-27B-FP8) on Nexus vllm — PVE LXC `300 (vllm)`, `10.10.0.3:8000`, single backend
- AI transport: HTTP over WireGuard VPN, configured by `LLM_BACKENDS` JSON (falls back to `LLAMA_SERVER_URL`); single-stage analysis (two-stage refine removed 2026-08-30)
- Embeddings: bge-m3 (1024-dim) via llama-cpp-python server on the rails LXC at `EMBEDDING_URL=http://127.0.0.1:8900` (service `embeddings.service`)
- Web scraping: Nokogiri for webpages, `yt-dlp` for YouTube subtitles and metadata
- Deployment: `bin/deploy urlfavorites`

## Mandatory DDD Architecture

New code must follow the DDD architecture spec. Do not add new code under the old `app/services/` pattern.

- Place application code under `app/url_favorites/{domain,integrations,use_cases}/`.
- Dependency direction is `Controller/Job -> UseCase -> Domain + Integrations`.
- Domain code must not depend on controllers, jobs, use cases, Rails persistence details, or integrations.
- Controllers and jobs call one use case and contain no business logic.
- Isolate external dependencies in the Integrations layer, including LLM calls, scraping, embedding, and command execution.
- Use the `UrlFavorites::` root namespace and follow Zeitwerk naming.
- Before creating a new service-like object, check spec sections 4 and 8 for directory placement and migration mapping.

## Coding Rules

- Keep changes small, focused, and single-purpose.
- Explore context before editing.
- All AI analysis must be async through Solid Queue. Never run analysis inline in a request.
- Reuse cached `raw_content` on retry. Never re-fetch content when `raw_content` is already present.
- Every llama-server HTTP call must use a 120 second timeout.
- Accept only HTTP/HTTPS URLs and reject private or internal IP ranges.
- Keep Solid Queue AI job concurrency at max 2 to avoid llama-server OOM.
- Keep naming consistent with the domain language in the DDD spec.

## Turbo Stream Conventions

Broadcast jobs must respect these targets:

```ruby
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

## AI Analysis Pipeline

State machine:

```text
pending -> analyzing -> done
                  -> failed
```

- Failed jobs auto-retry up to 3 times with exponential backoff: 30s, 60s, 120s.
- After 3 failures, keep failed status and show manual retry.
- Webpage extraction uses Nokogiri, saves title/OG/body text, and caps body text at 8,000 characters.
- YouTube extraction uses `yt-dlp --dump-json`, then subtitle fallback: manual captions, auto captions, then description/title.
- YouTube prompt content is capped at 12,000 characters.
- Qwen JSON output must include `summary`, `tags`, `key_points`, and `sentiment`.
- JSON parse failures must be captured in `error_message` and retried through Solid Queue.

## API Conventions

**`/api/v1/` is not implemented.** The JSON API in the original design doc was never built; the app is HTML/Turbo-only with session auth. Revisit this section only when an API is actually planned.

Auth for the web app: session-token authentication is already implemented (`Authentication` concern, `Session`/`User` models, `/session` routes) — not "Phase 1 VPN-only" as older docs claimed.

## PWA / Mobile

- `public/manifest.json` defines a `share_target` that posts to `/favorites`.
- Mobile share target and normal form submission should use the same create flow.
- The service worker provides an offline fallback screen.

## Search and Indexing

Project qmd collection: `urlfavorites`.

- Use `qmd search "keyword" -c urlfavorites`
- Use `qmd query "question" -c urlfavorites`
- Use `qmd vsearch "question" -c urlfavorites`

After code changes that should refresh the qmd index, run these as separate commands:

- `qmd update`
- `qmd embed`

## Codebase Knowledge Graph

This project uses codebase-memory-mcp. Prefer graph tools over grep/glob/file search for code discovery when those tools are available:

1. `search_graph` for functions, classes, routes, variables, and patterns
2. `trace_path` for inbound or outbound call tracing
3. `get_code_snippet` for specific function or class source
4. `query_graph` for complex Cypher queries
5. `get_architecture` for high-level project summary

Fall back to `rg` or qmd for string literals, error messages, config files, non-code files, or when graph results are insufficient.

## UI / Design System

Current theme: Warm Archive (Editorial Swiss).

- Design tokens are defined in `app/views/layouts/application.html.erb`.
- Use Tailwind utilities plus CSS custom properties.
- Route all colors, spacing, typography, and radius decisions through tokens.
- Dark mode is the default in `:root`.
- Light mode is implemented by `.light` class overrides.
- `theme_controller.js` toggles `html` classes using `localStorage.theme`.
- The head inline script prevents theme FOUC.

Token naming:

```text
Colors:  --color-{role}[-state]
Surface: --color-surface[-level]
Status:  --color-{status}-{prop}
Type:    --text-{size}
Space:   --space-{N}
Radius:  --radius-{size}
```

Status colors must be maintained as bg/text/border sets:

```text
--color-pending-bg / --color-pending-text / --color-pending-border
--color-analyzing-bg / --color-analyzing-text / --color-analyzing-border
--color-done-bg / --color-done-text / --color-done-border
--color-failed-bg / --color-failed-text / --color-failed-border
```

Tailwind `hover:` cannot directly use CSS variables in this project. Existing views use inline `onmouseover`/`onmouseout` handlers when variable-based hover styles are needed.

Avoid:

- Template-like uniform card grids
- Unmodified library defaults
- Same radius/spacing/shadow on every element
- Gray-only UI with a single decorative accent color
- Hard-coded colors in inline styles; use CSS variables

## View File Map

- `app/views/layouts/application.html.erb`: design tokens and app shell
- `app/views/shared/_sidebar.html.erb`: navigation and collection list
- `app/views/favorites/index.html.erb`: main page header, URL form, search, filters, grid
- `app/views/favorites/_favorite_card.html.erb`: card item
- `app/views/favorites/_favorite_row.html.erb`: list row
- `app/views/favorites/_search_bar.html.erb`: search input
- `app/views/favorites/_filter_bar.html.erb`: placeholder, currently integrated into index
- `app/views/favorites/show.html.erb`: detail page
- `app/views/favorites/_empty_state.html.erb`: empty state
- `app/views/collections/index.html.erb`: collection list
- `app/views/collections/show.html.erb`: collection detail

## UI Change Workflow

1. Modify view, Stimulus, or style files locally.
2. Run `bin/rails tailwindcss:build`.
3. Run `bin/rails assets:precompile`.
4. Commit and push before deploy. Git is the source of truth.
5. Run `bin/deploy-doctor pre`.
6. Deploy with `bin/deploy --quick urlfavorites`.
7. Run `bin/deploy-doctor post`.
8. Visually verify `https://urlf.hwandam.kr/favorites`.

## Deployment

Infrastructure (rebuilt 2026-08-20~21, PVE + LXC):

- PVE host: `bastion` (LAN `192.168.0.11`; WireGuard `10.10.0.1`, Tailscale `100.111.118.109` are alternates)
- App container: PVE LXC `101 (rails)` on bastion, IP `192.168.0.14` — access with `ssh bastion "sudo pct exec 101 -- bash -c '...'"` (runs as root inside)
- LLM container: PVE LXC `300 (vllm)` on nexus (`10.10.0.3:8000`)
- App path (inside LXC 101): `/home/hwandam/services/rails/urlfavorites/`
- Service: `rails-puma@urlfavorites.service` (active)
- Port: `3003`
- URL: `https://urlf.hwandam.kr/favorites`
- nginx runs on the bastion host (config: `/etc/nginx/sites-enabled/URLF.hwandam.kr`)
- Server source policy: do not edit source files on the server. Deploy committed changes only.
- Production DB policy: never delete or overwrite `storage/*.sqlite3*` inside the container.
- Current primary DB: `storage/production.sqlite3`; queue DB: `storage/production_queue.sqlite3`.

Systemd drop-in (inside LXC 101):

```ini
[Service]
Environment=LLAMA_SERVER_URL=http://10.10.0.4:8282
Environment=PORT=3003
Environment=SOLID_QUEUE_IN_PUMA=1
Environment=LLM_BACKENDS=[{"url":"http://10.10.0.3:8000","model":"Qwen3.6-27B","role":"default","timeout":240}]
Environment=EMBEDDING_URL=http://127.0.0.1:8900
Environment=GITHUB_TOKEN=<fine-grained PAT>
```

Drop-in path (inside LXC 101):

```text
/etc/systemd/system/rails-puma@urlfavorites.service.d/env.conf
```

Notes:

- `LLM_BACKENDS` (Nexus vllm) is the effective analysis backend; the legacy `LLAMA_SERVER_URL` (beacon 8282) is dead since the infra migration but kept because production.rb requires the variable to be set.
- Embeddings run on the same container: `embeddings.service` (llama-cpp-python, bge-m3 Q8_0 GGUF, `127.0.0.1:8900`, model dir `/home/hwandam/services/embeddings/`).
- The container git checkout fetches from GitHub over https using a stored credential (`/root/.git-credentials`, token same as `GITHUB_TOKEN`); remote name must stay `github` (bin/deploy expects it).

Deploy commands:

- Pre-deploy check: `bin/deploy-doctor pre`
- Full deploy: `bin/deploy urlfavorites`
- Quick deploy: `bin/deploy --quick urlfavorites`
- Post-deploy check: `bin/deploy-doctor post`

Deployment operating policy:

1. Server worktree cleanup
   - Separate useful server-side uncommitted changes from disposable artifacts.
   - Bring useful changes back into the local Mac branch, then commit them.
   - Return the server checkout to a clean worktree before the next deploy.
   - Never clean by deleting or overwriting `storage/*.sqlite3*` or `db/*.sqlite3*`.
2. Commit-based deployment only
   - `bin/deploy urlfavorites` and `bin/deploy --quick urlfavorites` must deploy a specific committed Git state.
   - Do not edit application source files directly on the server.
   - Emergency server edits must be copied back to the local branch, committed, and redeployed through the normal path.
3. Separate staging and production
   - Keep at least one staging port even for this personal app.
   - Target split: one environment on port `3003`, the other on port `3001`; document which is production before switching traffic.
   - Separate nginx routes with `/staging` or a staging subdomain.
   - Current state: `3003` is the live production Puma port until a separate staging/prod split is completed.
   - `bin/deploy --environment staging urlfavorites` must not be used until `URLF_STAGING_*` target variables and nginx routing are configured.
4. Longer-term deployment direction
   - For the current Rails + SQLite app, improving the existing Git-based deploy script is the lightest, highest-value path.
   - GitHub Actions or Kamal can be revisited later.
   - Docker/Kamal improves environment reproducibility but adds SQLite, Solid Queue DB, and persistent storage management overhead.

Post-deploy verification (inside LXC 101):

- Service status: `ssh bastion "sudo pct exec 101 -- systemctl status rails-puma@urlfavorites"`
- Health check: `curl -s -o /dev/null -w "%{http_code}" http://192.168.0.14:3003/favorites`
- Recent logs: `ssh bastion "sudo pct exec 101 -- journalctl -u rails-puma@urlfavorites -n 30 --no-pager"`

Common production issues:

- `EADDRINUSE port 3000`: `PORT=3003` missing from drop-in.
- `LLAMA_SERVER_URL is required`: env drop-in missing or daemon reload omitted.
- Dirty server worktree: stop and reconcile the server diff back into Git before deploying.
- Missing production DB: stop deploy; inspect `storage/production.sqlite3` backup/restore before any restart.
- ERB syntax errors: usually missing commas in `link_to` options.
- Embeddings silently missing (vectors stop growing): `embeddings.service` down inside LXC 101 — check `systemctl status embeddings` and backfill with `bin/rails urlf:backfill_embeddings`.
- Semantic search quality collapse after model change: re-measure the threshold (see `SemanticClient::SIMILARITY_THRESHOLD` comment) and re-embed everything.

## Harness / GSD Notes

The project has GSD planning files under `.planning/` and Claude role playbooks under `.claude/agents/`.

- Default lifecycle: plan phase, execute phase, verify work.
- Role playbooks: `rails-core`, `rails-ui`, `rails-test`, `rails-qa`.
- For Codex work, follow the architecture and verification rules in this file even when using GSD artifacts for context.

## Environment Variables

```bash
LLAMA_SERVER_URL=http://10.10.0.4:8282        # legacy, required to boot; analysis uses LLM_BACKENDS
LLM_BACKENDS=[{"url":"http://10.10.0.3:8000","model":"Qwen3.6-27B","role":"default","timeout":240}]
EMBEDDING_URL=http://127.0.0.1:8900           # bge-m3 via llama-cpp-python (embeddings.service)
GITHUB_TOKEN=<fine-grained PAT>
RAILS_ENV=production
SECRET_KEY_BASE=<generated>
RAILS_MASTER_KEY=<generated>
```

System dependencies on the production container: `yt-dlp` (YouTube) and `rdt-cli` (executable `rdt`, Reddit) are installed via `uv tool` under `/home/hwandam/.local/bin` (added to the service PATH via drop-in). Reddit cookie credentials were lost in the 2026-08 LXC migration and must be re-provisioned before Reddit extraction works (see `docs/runbooks/reddit-extraction.md`). `sqlite3` CLI is installed (deploy backups depend on it).

## Change History

Project change history is maintained in `docs/CHANGELOG.md`.
