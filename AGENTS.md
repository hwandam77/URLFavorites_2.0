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
- AI model: Qwen3.6-35B-A3B-Kimi-K2.6-Reasoning-Distilled.Q5_K_M through llama-server on `beacon`
- AI transport: HTTP over WireGuard VPN, configured by `LLAMA_SERVER_URL`
- Web scraping: Nokogiri for webpages, `yt-dlp` for YouTube subtitles and metadata
- Deployment: `deploy urlfavorites_2.0`

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

Base path: `/api/v1/`.

- Phase 1 auth: none, VPN-only access.
- Phase 2 auth: Bearer token.
- Main endpoints: favorites list/show/create/destroy, search, and recent.
- Responses should include favorite fields plus nested `analysis` when available.

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
4. Commit before deploy because the deploy script blocks untracked or staged files.
5. Deploy with `deploy --quick urlfavorites_2.0`.
6. Visually verify `https://urlf.hwandam.kr/ver2.0/favorites`.

## Deployment

Server details:

- SSH host: `vps-server`
- App path: `/home/hwandam/urlfavorites_2.0/`, symlinked to `/home/hwandam/services/rails/urlfavorites_2.0/`
- Service: `rails-puma@urlfavorites_2.0.service`
- Port: `3001`; port 3000 is occupied by the older URLFavorites app
- URL: `https://urlf.hwandam.kr/ver2.0/`
- nginx config: `/etc/nginx/sites-enabled/URLF.hwandam.kr`

Systemd drop-in:

```ini
[Service]
Environment=LLAMA_SERVER_URL=http://10.10.0.5:8282
Environment=PORT=3001
Environment=RAILS_RELATIVE_URL_ROOT=/ver2.0
Environment=SOLID_QUEUE_IN_PUMA=1
```

Drop-in path:

```text
/etc/systemd/system/rails-puma@urlfavorites_2.0.service.d/env.conf
```

Deploy commands:

- Full deploy: `deploy urlfavorites_2.0`
- Quick deploy: `deploy --quick urlfavorites_2.0`

Post-deploy verification:

- Service status: `systemctl status rails-puma@urlfavorites_2.0`
- Health check: `curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3001/ver2.0/favorites`
- Recent logs: `journalctl -u rails-puma@urlfavorites_2.0 -n 30 --no-pager`

Common production issues:

- `EADDRINUSE port 3000`: `PORT=3001` missing from drop-in.
- `LLAMA_SERVER_URL is required`: env drop-in missing or daemon reload omitted.
- 404 on `/ver2.0/favorites`: `RAILS_RELATIVE_URL_ROOT=/ver2.0` missing.
- ERB syntax errors: usually missing commas in `link_to` options.

## Harness / GSD Notes

The project has GSD planning files under `.planning/` and Claude role playbooks under `.claude/agents/`.

- Default lifecycle: plan phase, execute phase, verify work.
- Role playbooks: `rails-core`, `rails-ui`, `rails-test`, `rails-qa`.
- For Codex work, follow the architecture and verification rules in this file even when using GSD artifacts for context.

## Environment Variables

```bash
LLAMA_SERVER_URL=http://<beacon-wg-ip>:<port>
RAILS_ENV=production
SECRET_KEY_BASE=<generated>
RAILS_MASTER_KEY=<generated>
```

System dependency: `yt-dlp` must be installed on the production server.

## Change History

Project change history is maintained in `docs/CHANGELOG.md`.
