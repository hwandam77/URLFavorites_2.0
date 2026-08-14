# Graph Report - .  (2026-08-13)

## Corpus Check
- 311 files · ~92,094 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1167 nodes · 1341 edges · 158 communities (84 shown, 74 thin omitted)
- Extraction: 93% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 32 edges (avg confidence: 0.84)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Backend Router
- Design System
- Twitter Analysis Jobs
- Authentication Concerns
- Application Controller
- Favorite Notes Controller
- Favorites & Newsletter
- Agent Architecture
- Analysis Model
- Twitter Extractor
- Search Embedding
- Cable Config
- GitHub Link Extractor
- Manual Section Jobs
- User & Auth
- Link Roundup Jobs
- Favorites Model & Controller
- Collection Memberships
- PWA Manifest
- GitHub Health Score
- Community 20
- Community 21
- Community 22
- Community 23
- Community 24
- Community 25
- Community 26
- Community 27
- Community 28
- Community 29
- Community 30
- Community 31
- Community 32
- Community 33
- Community 34
- Community 35
- Community 36
- Community 37
- Community 38
- Community 39
- Community 40
- Community 41
- Community 42
- Community 43
- Community 44
- Community 45
- Community 46
- Community 47
- Community 48
- Community 49
- Community 50
- Community 51
- Community 53
- Community 54
- Community 55
- Community 56
- Community 57
- Community 58
- Community 59
- Community 60
- Community 61
- Community 62
- Community 63
- Community 64
- Community 65
- Community 67
- Community 68
- Community 69
- Community 70
- Community 71
- Community 72
- Community 73
- Community 74
- Community 75
- Community 76
- Community 77
- Community 78
- Community 79
- Community 80
- Community 81
- Community 82
- Community 83
- Community 84
- Community 85
- Community 86
- Community 87
- Community 88
- Community 89
- Community 90
- Community 91
- Community 92
- Community 93
- Community 94
- Community 95
- Community 96
- Community 97
- Community 98
- Community 99
- Community 100
- Community 101
- Community 102
- Community 103
- Community 104
- Community 105
- Community 106
- Community 107
- Community 108
- Community 109
- Community 110
- Community 111
- Community 112
- Community 113
- Community 114
- Community 115
- Community 116
- Community 117
- Community 119
- Community 120
- Community 121
- Community 148

## God Nodes (most connected - your core abstractions)
1. `Favorite` - 43 edges
2. `UrlFavorites::Integrations::LlamaServer::Client` - 19 edges
3. `FavoritesController` - 16 edges
4. `URLFavorites 2.0` - 16 edges
5. `UrlFavorites::Integrations::LlamaServer::ClientTest` - 13 edges
6. `UrlFavorites::Integrations::Youtube::Extractor` - 12 edges
7. `ApplicationJob` - 12 edges
8. `UrlFavorites::Integrations::Webpage::Scraper` - 12 edges
9. `Component Stylings` - 12 edges
10. `Color Palette & Roles` - 12 edges

## Surprising Connections (you probably didn't know these)
- `Favorite` --calls--> `run()`  [EXTRACTED]
  app/models/favorite.rb → scripts/reclassify_categories.rb
- `Production Databases (primary + queue + cable)` --conceptually_related_to--> `Production SQLite Storage Protection`  [INFERRED]
  config/database.yml → README.md
- `SQLite3 Adapter (min 3.8.0)` --conceptually_related_to--> `SQLite3 + Solid Queue`  [INFERRED]
  config/database.yml → README.md
- `Solid Queue Configuration` --conceptually_related_to--> `SQLite3 + Solid Queue`  [INFERRED]
  config/queue.yml → README.md
- `Bundler Audit CVE Ignore List` --references--> `scan_ruby Job (brakeman + bundler-audit)`  [INFERRED]
  config/bundler-audit.yml → .github/workflows/ci.yml

## Import Cycles
- None detected.

## Communities (158 total, 74 thin omitted)

### Community 0 - "Backend Router"
Cohesion: 0.06
Nodes (19): UrlFavorites, UrlFavorites::Domain, UrlFavorites::Domain::Analysis, UrlFavorites::Domain::Analysis::BackendRouter, UrlFavorites, UrlFavorites::Domain, UrlFavorites::Domain::Analysis, UrlFavorites::Domain::Analysis::PromptStyle (+11 more)

### Community 1 - "Design System"
Cohesion: 0.05
Nodes (53): Accessibility & States, Active Blue, Agent Prompt Guide, Badge Typography, Body Typography, Border Philosophy, Border Radius Scale, Desktop Breakpoint (+45 more)

### Community 2 - "Twitter Analysis Jobs"
Cohesion: 0.06
Nodes (18): AnalyzeTwitterJob, AnalyzeWebpageAnalysisJob, AnalyzeWebpageJob, AnalyzeYoutubeJob, ApplicationJob, Base, RefineAnalysisJob, ReindexFavoriteJob (+10 more)

### Community 3 - "Authentication Concerns"
Cohesion: 0.05
Nodes (23): ApplicationController, Base, CollectionsController, FavoriteNotesController, Collection, UrlFavorites, UrlFavorites::UseCases, UrlFavorites::UseCases::Collections (+15 more)

### Community 4 - "Application Controller"
Cohesion: 0.05
Nodes (28): detect_from_text(), detect_github_category(), detect_youtube_category(), UrlFavorites, UrlFavorites::Domain, UrlFavorites::Domain::Urls, UrlFavorites::Domain::Urls::CategoryDetector, UrlFavorites (+20 more)

### Community 5 - "Favorite Notes Controller"
Cohesion: 0.05
Nodes (42): AGENTS.md, bastion (SSH 호스트), docs/CHANGELOG.md, 커스텀 에이전트 플레이북, DDD 아키텍처 스펙, Domain Layer, Integrations Layer, UseCases Layer (+34 more)

### Community 6 - "Favorites & Newsletter"
Cohesion: 0.09
Nodes (38): AI Analysis Pipeline, API Conventions (/api/v1/), Backend Models (Favorite, Analysis, Collection), Boundary Cross-Comparison Verification, Rails Core Agent, Rails QA Agent, Rails Test Agent, Rails UI Agent (+30 more)

### Community 7 - "Agent Architecture"
Cohesion: 0.06
Nodes (15): Authentication, SessionsController, Current, UrlFavorites, UrlFavorites::UseCases, UrlFavorites::UseCases::Authentication, UrlFavorites::UseCases::Authentication::DestroySession, UrlFavorites (+7 more)

### Community 8 - "Analysis Model"
Cohesion: 0.07
Nodes (12): WeeklyNewsletterJob, ApplicationMailer, Base, WeeklyNewsletterMailer, UrlFavorites, UrlFavorites::UseCases, UrlFavorites::UseCases::Newsletter, UrlFavorites::UseCases::Newsletter::SendWeeklyNewsletter (+4 more)

### Community 9 - "Twitter Extractor"
Cohesion: 0.07
Nodes (12): Analysis, AnalysisSection, ApplicationRecord, Base, Session, TagFeedback, UrlFavorites, UrlFavorites::UseCases (+4 more)

### Community 10 - "Search Embedding"
Cohesion: 0.09
Nodes (12): StandardError, UrlFavorites, UrlFavorites::Integrations, UrlFavorites::Integrations::Twitter, UrlFavorites::Integrations::Twitter::Extractor, UrlFavorites::Integrations::Twitter::Extractor::ExtractionError, StandardError, UrlFavorites (+4 more)

### Community 11 - "Cable Config"
Cohesion: 0.09
Nodes (12): UrlFavorites, UrlFavorites::Integrations, UrlFavorites::Integrations::Search, UrlFavorites::Integrations::Search::EmbeddingClient, UrlFavorites, UrlFavorites::Integrations, UrlFavorites::Integrations::Search, UrlFavorites::Integrations::Search::SemanticClient (+4 more)

### Community 12 - "GitHub Link Extractor"
Cohesion: 0.07
Nodes (30): Action Cable Configuration, Async Cable Adapter (development), Solid Cable Adapter (production), Test Cable Adapter (test), Connection Pooling (RAILS_MAX_THREADS), Database Configuration, Development Databases (primary + queue), Production Databases (primary + queue + cable) (+22 more)

### Community 13 - "Manual Section Jobs"
Cohesion: 0.08
Nodes (14): GenerateManualSectionJob, PlanLinkRoundupJob, UrlFavorites, UrlFavorites::Integrations, UrlFavorites::Integrations::Github, UrlFavorites::Integrations::Github::RepoClient, UrlFavorites, UrlFavorites::UseCases (+6 more)

### Community 14 - "User & Auth"
Cohesion: 0.12
Nodes (10): UrlFavorites, UrlFavorites::Domain, UrlFavorites::Domain::Content, UrlFavorites::Domain::Content::GithubLinkExtractor, StandardError, UrlFavorites, UrlFavorites::Integrations, UrlFavorites::Integrations::Youtube (+2 more)

### Community 15 - "Link Roundup Jobs"
Cohesion: 0.10
Nodes (12): User, UrlFavorites, UrlFavorites::UseCases, UrlFavorites::UseCases::Authentication, UrlFavorites::UseCases::Authentication::CreateSession, SystemTestCase, ApplicationSystemTestCase, CollectionsFlowTest (+4 more)

### Community 16 - "Favorites Model & Controller"
Cohesion: 0.12
Nodes (10): CollectionMembershipsController, CollectionMembership, UrlFavorites, UrlFavorites::UseCases, UrlFavorites::UseCases::Collections, UrlFavorites::UseCases::Collections::AddFavoriteToCollection, UrlFavorites, UrlFavorites::UseCases (+2 more)

### Community 17 - "Collection Memberships"
Cohesion: 0.12
Nodes (16): background_color, display, icons, name, text, title, url, scope (+8 more)

### Community 18 - "PWA Manifest"
Cohesion: 0.16
Nodes (5): UrlFavorites, UrlFavorites::Domain, UrlFavorites::Domain::Github, UrlFavorites::Domain::Github::HealthScore, UrlFavorites::Domain::Github::HealthScore::Result

### Community 19 - "GitHub Health Score"
Cohesion: 0.22
Nodes (6): StandardError, UrlFavorites, UrlFavorites::Integrations, UrlFavorites::Integrations::Reddit, UrlFavorites::Integrations::Reddit::Extractor, UrlFavorites::Integrations::Reddit::Extractor::ExtractionError

### Community 21 - "Community 21"
Cohesion: 0.16
Nodes (8): UrlFavorites, UrlFavorites::UseCases, UrlFavorites::UseCases::Analysis, UrlFavorites::UseCases::Analysis::EnqueueAnalysis, UrlFavorites, UrlFavorites::UseCases, UrlFavorites::UseCases::Favorites, UrlFavorites::UseCases::Favorites::CreateFavorite

### Community 22 - "Community 22"
Cohesion: 0.19
Nodes (5): PlanManualOutlineJob, UrlFavorites, UrlFavorites::UseCases, UrlFavorites::UseCases::Manual, UrlFavorites::UseCases::Manual::PlanOutline

### Community 23 - "Community 23"
Cohesion: 0.22
Nodes (5): UrlFavorites::Integrations::Search::Indexer, UrlFavorites, UrlFavorites::UseCases, UrlFavorites::UseCases::Search, UrlFavorites::UseCases::Search::ReindexFavorite

### Community 24 - "Community 24"
Cohesion: 0.22
Nodes (9): env_fetch(), remote_command(), remote_path(), remote_rails_env(), run_local(), run_remote(), shell_env(), sqlite_backup_command() (+1 more)

### Community 25 - "Community 25"
Cohesion: 0.22
Nodes (8): capture(), Check, local_git(), protected_runtime_path?(), remote_capture(), remote_git(), source_status(), status_paths()

### Community 26 - "Community 26"
Cohesion: 0.20
Nodes (11): Bundler Audit CVE Ignore List, CI Pipeline, libvips System Dependency, lint Job (RuboCop with GitHub format), RuboCop Cache Strategy, scan_js Job (importmap audit — skipped), scan_ruby Job (brakeman + bundler-audit), system-test Job (Capybara system tests) (+3 more)

### Community 27 - "Community 27"
Cohesion: 0.18
Nodes (11): collections/index.html.erb, collections/show.html.erb, favorites/_empty_state.html.erb, favorites/_favorite_card.html.erb, favorites/_favorite_row.html.erb, favorites/index.html.erb, favorites/show.html.erb, favorites/_filter_bar.html.erb (+3 more)

### Community 28 - "Community 28"
Cohesion: 0.25
Nodes (4): UrlFavorites, UrlFavorites::UseCases, UrlFavorites::UseCases::Favorites, UrlFavorites::UseCases::Favorites::DeleteFavorite

### Community 29 - "Community 29"
Cohesion: 0.29
Nodes (4): UrlFavorites, UrlFavorites::UseCases, UrlFavorites::UseCases::Favorites, UrlFavorites::UseCases::Favorites::TogglePin

### Community 30 - "Community 30"
Cohesion: 0.29
Nodes (4): UrlFavorites, UrlFavorites::UseCases, UrlFavorites::UseCases::Favorites, UrlFavorites::UseCases::Favorites::UpdateCategory

### Community 31 - "Community 31"
Cohesion: 0.33
Nodes (3): MarkdownHelper, MarkdownHelperTest, TestCase

### Community 33 - "Community 33"
Cohesion: 0.53
Nodes (4): close(), closeOnClickOutside(), connect(), disconnect()

### Community 34 - "Community 34"
Cohesion: 0.33
Nodes (4): UrlFavorites, UrlFavorites::Domain, UrlFavorites::Domain::Analysis, UrlFavorites::Domain::Analysis::RetryPolicy

### Community 35 - "Community 35"
Cohesion: 0.33
Nodes (5): StandardError, UrlFavorites, UrlFavorites::Domain, UrlFavorites::Domain::Errors, UrlFavorites::Domain::Errors::BaseError

### Community 36 - "Community 36"
Cohesion: 0.33
Nodes (5): UrlFavorites, UrlFavorites::Domain, UrlFavorites::Domain::Errors, UrlFavorites::Domain::Errors::UnsafeUrl, BaseError

### Community 40 - "Community 40"
Cohesion: 0.33
Nodes (5): TestCase, UrlFavorites, UrlFavorites::UseCases, UrlFavorites::UseCases::Authentication, UrlFavorites::UseCases::Authentication::CreateSessionTest

### Community 41 - "Community 41"
Cohesion: 0.33
Nodes (5): TestCase, UrlFavorites, UrlFavorites::UseCases, UrlFavorites::UseCases::Authentication, UrlFavorites::UseCases::Authentication::DestroySessionTest

### Community 42 - "Community 42"
Cohesion: 0.33
Nodes (5): TestCase, UrlFavorites, UrlFavorites::UseCases, UrlFavorites::UseCases::Authentication, UrlFavorites::UseCases::Authentication::ResumeSessionTest

### Community 43 - "Community 43"
Cohesion: 0.60
Nodes (3): close(), closeOnOverlayClick(), toggle()

### Community 44 - "Community 44"
Cohesion: 0.80
Nodes (4): connect(), switchToCard(), switchToList(), updateButtonStates()

### Community 45 - "Community 45"
Cohesion: 0.40
Nodes (4): UrlFavorites, UrlFavorites::UseCases, UrlFavorites::UseCases::Favorites, UrlFavorites::UseCases::Favorites::RetryAnalysis

### Community 53 - "Community 53"
Cohesion: 1.00
Nodes (3): copy(), fallbackCopy(), showToast()

### Community 54 - "Community 54"
Cohesion: 0.50
Nodes (3): UrlFavorites, UrlFavorites::Domain, UrlFavorites::Domain::Analysis

### Community 55 - "Community 55"
Cohesion: 0.50
Nodes (3): UrlFavorites, UrlFavorites::Integrations, UrlFavorites::Integrations::Search

### Community 56 - "Community 56"
Cohesion: 0.50
Nodes (3): Application, UrlFavorites20, UrlFavorites20::Application

### Community 83 - "Community 83"
Cohesion: 0.67
Nodes (3): Bundler Package Ecosystem Monitoring, Dependabot Auto-Updates, GitHub Actions Ecosystem Monitoring

## Knowledge Gaps
- **114 isolated node(s):** `UrlFavorites`, `UrlFavorites::Domain::Github::HealthScore::Result`, `UrlFavorites::UseCases`, `UrlFavorites::Domain::Analysis`, `application` (+109 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **74 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Favorite` connect `Community 20` to `Backend Router`, `Twitter Analysis Jobs`, `Authentication Concerns`, `Application Controller`, `Analysis Model`, `Twitter Extractor`, `Cable Config`, `Manual Section Jobs`, `Favorites Model & Controller`, `Community 21`, `Community 22`, `Community 23`, `Community 28`, `Community 29`, `Community 30`, `Community 31`, `Community 48`, `Community 61`, `Community 62`, `Community 63`, `Community 65`?**
  _High betweenness centrality (0.162) - this node is a cross-community bridge._
- **Why does `ApplicationRecord` connect `Twitter Extractor` to `Favorites Model & Controller`, `Authentication Concerns`, `Community 20`, `Link Roundup Jobs`?**
  _High betweenness centrality (0.051) - this node is a cross-community bridge._
- **Why does `Collection` connect `Authentication Concerns` to `Twitter Extractor`?**
  _High betweenness centrality (0.021) - this node is a cross-community bridge._
- **What connects `UrlFavorites`, `UrlFavorites::Domain::Github::HealthScore::Result`, `UrlFavorites::UseCases` to the rest of the system?**
  _114 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Backend Router` be split into smaller, more focused modules?**
  _Cohesion score 0.05589225589225589 - nodes in this community are weakly interconnected._
- **Should `Design System` be split into smaller, more focused modules?**
  _Cohesion score 0.054426705370101594 - nodes in this community are weakly interconnected._
- **Should `Twitter Analysis Jobs` be split into smaller, more focused modules?**
  _Cohesion score 0.05851063829787234 - nodes in this community are weakly interconnected._