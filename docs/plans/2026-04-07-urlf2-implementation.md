# URLFavorites 2.0 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** `https://urlf2.hwandam.kr`에서 동작할 독립형 Rails 8 앱을 구축한다. 기존 `urlf` 데이터를 1회 이관하고, 검색 중심 카드형 아카이브, 컬렉션, 메모, 모바일 공유 저장, AI 비동기 분석을 제공한다.

**Architecture:** Rails 8 모노리스로 시작한다. SQLite + Solid Queue를 유지하고, 웹 UI는 Hotwire + Stimulus + Tailwind로 구현한다. 검색은 SQLite FTS5 기반 인덱스로 강화하고, `favorites`, `analyses`, `collections`, `collection_memberships`를 중심으로 설계한다. `urlf` 이관은 읽기 전용 스냅샷 DB를 대상으로 별도 importer 서비스로 처리한다.

**Tech Stack:** Rails 8.1.x, Ruby 3.4.x, SQLite3, Solid Queue, Turbo, Stimulus, Tailwind CSS, Nokogiri, Faraday, yt-dlp, SQLite FTS5, Minitest, Capybara/System Tests

---

## Assumptions

- 현재 저장소에는 앱 코드가 없고 문서만 있다.
- `urlf2`는 기존 `urlf`와 코드/DB/도메인이 분리된 신규 서비스다.
- `urlf` 데이터는 1회만 이관한다.
- 초기 구현은 개인 전용 서비스 범위에 집중한다.
- 브라우저 확장, 공개 공유, 멀티유저는 이번 플랜 범위에서 제외한다.

---

## File Map

```text
# Docs
docs/plans/2026-04-07-urlf2-design.md
docs/plans/2026-04-07-urlf2-implementation.md
docs/deploy/urlf2-vps-checklist.md

# App bootstrap / config
Gemfile
config/routes.rb
config/database.yml
config/application.rb
config/environments/development.rb
config/environments/production.rb
config/initializers/content_security_policy.rb
config/initializers/solid_queue.rb
.gitignore
.ruby-version
README.md
AGENTS.md

# Database / models
db/migrate/*_create_favorites.rb
db/migrate/*_create_analyses.rb
db/migrate/*_create_collections.rb
db/migrate/*_create_collection_memberships.rb
db/migrate/*_create_favorite_search_index.rb
app/models/favorite.rb
app/models/analysis.rb
app/models/collection.rb
app/models/collection_membership.rb

# Services
app/services/url_normalizer.rb
app/services/url_safety_validator.rb
app/services/url_type_detector.rb
app/services/webpage_scraper.rb
app/services/youtube_extractor.rb
app/services/llm_analyzer.rb
app/services/favorite_search.rb
app/services/favorite_search_indexer.rb
app/services/importers/urlf_snapshot_importer.rb

# Jobs
app/jobs/analyze_webpage_job.rb
app/jobs/analyze_youtube_job.rb
app/jobs/reindex_favorite_job.rb

# Controllers
app/controllers/favorites_controller.rb
app/controllers/favorite_notes_controller.rb
app/controllers/collections_controller.rb
app/controllers/collection_memberships_controller.rb

# Views
app/views/favorites/index.html.erb
app/views/favorites/show.html.erb
app/views/favorites/_search_bar.html.erb
app/views/favorites/_filter_bar.html.erb
app/views/favorites/_favorite_card.html.erb
app/views/favorites/_favorite_row.html.erb
app/views/favorites/_empty_state.html.erb
app/views/favorites/_note_form.html.erb
app/views/collections/index.html.erb
app/views/collections/show.html.erb
app/views/collections/_form.html.erb

# Frontend
app/javascript/controllers/view_mode_controller.js
app/javascript/controllers/filter_sheet_controller.js
app/javascript/controllers/auto_submit_controller.js
app/assets/stylesheets/application.tailwind.css

# PWA
public/manifest.json
public/sw.js

# Tasks / import
lib/tasks/urlf_import.rake

# Tests
test/models/favorite_test.rb
test/models/analysis_test.rb
test/models/collection_test.rb
test/models/collection_membership_test.rb
test/services/url_normalizer_test.rb
test/services/url_safety_validator_test.rb
test/services/url_type_detector_test.rb
test/services/webpage_scraper_test.rb
test/services/youtube_extractor_test.rb
test/services/llm_analyzer_test.rb
test/services/favorite_search_test.rb
test/services/favorite_search_indexer_test.rb
test/services/importers/urlf_snapshot_importer_test.rb
test/jobs/analyze_webpage_job_test.rb
test/jobs/analyze_youtube_job_test.rb
test/jobs/reindex_favorite_job_test.rb
test/controllers/favorites_controller_test.rb
test/controllers/favorite_notes_controller_test.rb
test/controllers/collections_controller_test.rb
test/controllers/collection_memberships_controller_test.rb
test/system/archive_search_flow_test.rb
test/system/favorite_note_flow_test.rb
test/system/collection_management_flow_test.rb
```

---

### Task 1: Rails App Bootstrap

**Files:**
- Create: Rails 기본 파일 세트 (`Gemfile`, `config/*`, `app/*`, `bin/*`)
- Modify: [README.md](/Users/hwandam/workspace/URLFavorites_2.0/README.md)
- Modify: [AGENTS.md](/Users/hwandam/workspace/URLFavorites_2.0/AGENTS.md)

**Step 1: Rails 앱 골격 생성**

Run:
```bash
rails new /Users/hwandam/workspace/URLFavorites_2.0 --database=sqlite3 --skip-git --javascript=importmap --css=tailwind --skip-bundle --force
```

Expected: Rails 기본 파일이 생성되고 `docs/`, `AGENTS.md`, `CLAUDE.md`는 유지된다.

**Step 2: 필수 gem 추가**

Modify `Gemfile`:
```ruby
gem "nokogiri"
gem "faraday"
gem "faraday-retry"

group :test do
  gem "webmock"
end
```

**Step 3: 의존성 설치**

Run:
```bash
bundle install
```

Expected: `Bundle complete!` 출력과 함께 설치 성공.

**Step 4: git 저장소 초기화**

Run:
```bash
git init
```

Expected: `.git/` 생성.

**Step 5: 초기 앱 상태 스냅샷 커밋**

Run:
```bash
git add .
```

Run:
```bash
git commit -m "feat: bootstrap Rails 8 app for urlf2"
```

Expected: 초기 Rails 앱과 기존 문서가 함께 커밋된다.

---

### Task 2: Project Docs and Runtime Alignment

**Files:**
- Modify: [README.md](/Users/hwandam/workspace/URLFavorites_2.0/README.md)
- Modify: [AGENTS.md](/Users/hwandam/workspace/URLFavorites_2.0/AGENTS.md)
- Create: `/Users/hwandam/workspace/URLFavorites_2.0/docs/deploy/urlf2-vps-checklist.md`

**Step 1: README를 실제 프로젝트 설명으로 교체**

Add sections for:
- 서비스 개요
- 로컬 실행 방법
- 필수 환경 변수
- `yt-dlp` 의존성
- 테스트 명령
- `urlf` 이관 개요

**Step 2: AGENTS 문서의 스펙 참조 경로 수정**

Update spec references to:
- `docs/plans/2026-04-07-urlf2-design.md`
- `docs/plans/2026-04-07-urlf2-implementation.md`

**Step 3: VPS 배포 체크리스트 문서 추가**

Create `docs/deploy/urlf2-vps-checklist.md` with:
- DNS
- TLS
- env vars
- `yt-dlp` 설치
- DB 백업
- import 순서
- smoke test 순서

**Step 4: 문서 변경 검증**

Run:
```bash
rg -n "urlf2|LLAMA_SERVER_URL|yt-dlp" /Users/hwandam/workspace/URLFavorites_2.0/README.md /Users/hwandam/workspace/URLFavorites_2.0/AGENTS.md /Users/hwandam/workspace/URLFavorites_2.0/docs/deploy/urlf2-vps-checklist.md
```

Expected: 세 문서에 핵심 운영 정보가 모두 노출된다.

**Step 5: 커밋**

Run:
```bash
git add README.md AGENTS.md docs/deploy/urlf2-vps-checklist.md
```

Run:
```bash
git commit -m "docs: align urlf2 runtime and deployment docs"
```

---

### Task 3: Core Schema and Associations

**Files:**
- Create: `db/migrate/*_create_favorites.rb`
- Create: `db/migrate/*_create_analyses.rb`
- Create: `db/migrate/*_create_collections.rb`
- Create: `db/migrate/*_create_collection_memberships.rb`
- Create: `app/models/favorite.rb`
- Create: `app/models/analysis.rb`
- Create: `app/models/collection.rb`
- Create: `app/models/collection_membership.rb`
- Test: `test/models/favorite_test.rb`
- Test: `test/models/analysis_test.rb`
- Test: `test/models/collection_test.rb`
- Test: `test/models/collection_membership_test.rb`

**Step 1: Favorite/Analysis/Collection 모델 테스트 작성**

Write tests for:
- URL 필수
- URL unique
- `note` 허용
- `status` 기본값
- collection name 필수
- collection membership 중복 방지
- favorite has_one analysis
- favorite has_many collections through memberships

Example:
```ruby
test "favorite accepts long note text" do
  favorite = Favorite.new(url: "https://example.com", content_type: "webpage", note: "x" * 5_000)
  assert favorite.valid?
end
```

**Step 2: 테스트가 실패하는지 확인**

Run:
```bash
bin/rails test test/models/favorite_test.rb test/models/analysis_test.rb test/models/collection_test.rb test/models/collection_membership_test.rb
```

Expected: 모델/테이블 미정의로 실패.

**Step 3: 마이그레이션 작성**

Schema requirements:
- `favorites.url` unique index
- `favorites.note` text
- `favorites.status` default `pending`
- `collections.name` unique index
- `collection_memberships` unique composite index
- `analyses.favorite_id` unique index

**Step 4: 모델 최소 구현**

Implement:
```ruby
class Favorite < ApplicationRecord
  has_one :analysis, dependent: :destroy
  has_many :collection_memberships, dependent: :destroy
  has_many :collections, through: :collection_memberships

  validates :url, presence: true, uniqueness: true
  validates :content_type, inclusion: { in: %w[webpage youtube] }
  validates :status, inclusion: { in: %w[pending analyzing done failed] }
end
```

**Step 5: DB 생성과 마이그레이션 적용**

Run:
```bash
bin/rails db:prepare
```

Expected: SQLite DB와 schema 생성 성공.

**Step 6: 모델 테스트 재실행**

Run:
```bash
bin/rails test test/models/favorite_test.rb test/models/analysis_test.rb test/models/collection_test.rb test/models/collection_membership_test.rb
```

Expected: PASS.

**Step 7: 커밋**

Run:
```bash
git add app/models db/migrate test/models db/schema.rb
```

Run:
```bash
git commit -m "feat: add core models for favorites analyses and collections"
```

---

### Task 4: URL Normalization and Safety Guards

**Files:**
- Create: `app/services/url_normalizer.rb`
- Create: `app/services/url_safety_validator.rb`
- Create: `app/services/url_type_detector.rb`
- Test: `test/services/url_normalizer_test.rb`
- Test: `test/services/url_safety_validator_test.rb`
- Test: `test/services/url_type_detector_test.rb`

**Step 1: 서비스 테스트 작성**

Cover:
- 스킴 없는 URL 보정 여부 결정
- `http`/`https` 외 차단
- localhost, 사설 IP, loopback 차단
- YouTube URL 감지 (`youtube.com`, `youtu.be`)
- 정규화 후 동일 URL 중복 감소

**Step 2: 실패 확인**

Run:
```bash
bin/rails test test/services/url_normalizer_test.rb test/services/url_safety_validator_test.rb test/services/url_type_detector_test.rb
```

Expected: 상수 미정의로 실패.

**Step 3: 서비스 구현**

Recommended API:
```ruby
UrlNormalizer.call(raw_url)
UrlSafetyValidator.call!(normalized_url)
UrlTypeDetector.call(normalized_url) # => "webpage" or "youtube"
```

**Step 4: 서비스 테스트 재실행**

Run:
```bash
bin/rails test test/services/url_normalizer_test.rb test/services/url_safety_validator_test.rb test/services/url_type_detector_test.rb
```

Expected: PASS.

**Step 5: 커밋**

Run:
```bash
git add app/services test/services
```

Run:
```bash
git commit -m "feat: add URL normalization and safety services"
```

---

### Task 5: AI Extraction Services

**Files:**
- Create: `app/services/webpage_scraper.rb`
- Create: `app/services/youtube_extractor.rb`
- Create: `app/services/llm_analyzer.rb`
- Test: `test/services/webpage_scraper_test.rb`
- Test: `test/services/youtube_extractor_test.rb`
- Test: `test/services/llm_analyzer_test.rb`

**Step 1: 서비스 테스트 작성**

Cover:
- 웹페이지 본문 8,000자 제한
- OG/meta/title 우선 추출
- YouTube metadata + subtitle fallback
- llama-server 120초 timeout
- JSON parse failure 시 예외 처리

Use `WebMock` for HTTP and stub `yt-dlp` via `Open3.capture3`.

**Step 2: 실패 확인**

Run:
```bash
bin/rails test test/services/webpage_scraper_test.rb test/services/youtube_extractor_test.rb test/services/llm_analyzer_test.rb
```

Expected: 서비스 미구현으로 실패.

**Step 3: 최소 구현**

Implementation requirements:
- `WebpageScraper.call(url)` returns title, favicon_url, body_text
- `YoutubeExtractor.call(url)` returns metadata, transcript, subtitle_source
- `LlmAnalyzer.call(content:, metadata:)` returns parsed JSON hash

**Step 4: 서비스 테스트 재실행**

Run:
```bash
bin/rails test test/services/webpage_scraper_test.rb test/services/youtube_extractor_test.rb test/services/llm_analyzer_test.rb
```

Expected: PASS.

**Step 5: 커밋**

Run:
```bash
git add app/services test/services
```

Run:
```bash
git commit -m "feat: add extraction and LLM analysis services"
```

---

### Task 6: Async Analysis Jobs

**Files:**
- Create: `app/jobs/analyze_webpage_job.rb`
- Create: `app/jobs/analyze_youtube_job.rb`
- Test: `test/jobs/analyze_webpage_job_test.rb`
- Test: `test/jobs/analyze_youtube_job_test.rb`

**Step 1: job 테스트 작성**

Cover:
- `pending -> analyzing -> done`
- 실패 시 `error_message` 기록
- `retry_count` 증가
- `raw_content` 있으면 재사용
- analysis record 생성

**Step 2: 실패 확인**

Run:
```bash
bin/rails test test/jobs/analyze_webpage_job_test.rb test/jobs/analyze_youtube_job_test.rb
```

Expected: job 미구현으로 실패.

**Step 3: job 구현**

Recommended flow:
```ruby
favorite.update!(status: "analyzing")
content = favorite.raw_content.presence || ...
analysis_payload = LlmAnalyzer.call(...)
favorite.create_analysis!(...)
favorite.update!(status: "done", error_message: nil)
```

**Step 4: job 테스트 재실행**

Run:
```bash
bin/rails test test/jobs/analyze_webpage_job_test.rb test/jobs/analyze_youtube_job_test.rb
```

Expected: PASS.

**Step 5: queue 설정 검토**

Ensure:
- Solid Queue 활성화
- AI job concurrency target documented as max 2

**Step 6: 커밋**

Run:
```bash
git add app/jobs test/jobs config
```

Run:
```bash
git commit -m "feat: add async analysis jobs"
```

---

### Task 7: Search Index with SQLite FTS5

**Files:**
- Create: `db/migrate/*_create_favorite_search_index.rb`
- Create: `app/services/favorite_search.rb`
- Create: `app/services/favorite_search_indexer.rb`
- Create: `app/jobs/reindex_favorite_job.rb`
- Test: `test/services/favorite_search_test.rb`
- Test: `test/services/favorite_search_indexer_test.rb`
- Test: `test/jobs/reindex_favorite_job_test.rb`

**Step 1: 검색 테스트 작성**

Cover:
- title, summary, tags, note 검색
- collection filter 동작
- status/content_type filter 동작
- note 수정 후 검색 결과 반영

**Step 2: 실패 확인**

Run:
```bash
bin/rails test test/services/favorite_search_test.rb test/services/favorite_search_indexer_test.rb test/jobs/reindex_favorite_job_test.rb
```

Expected: 검색 인덱스 미구현으로 실패.

**Step 3: FTS5 마이그레이션 작성**

Recommended approach:
- virtual table `favorite_search_index`
- columns: `favorite_id UNINDEXED`, `title`, `summary`, `tags`, `note`, `content_type`, `status`, `collection_names`

Use raw SQL in migration:
```ruby
execute <<~SQL
  CREATE VIRTUAL TABLE favorite_search_index USING fts5(
    favorite_id UNINDEXED,
    title,
    summary,
    tags,
    note,
    content_type,
    status,
    collection_names
  );
SQL
```

**Step 4: 인덱서 구현**

Implement:
- create/update/delete sync
- initial full rebuild helper
- enqueue on favorite, analysis, collection membership changes

**Step 5: 검색 서비스 구현**

Recommended API:
```ruby
FavoriteSearch.call(query:, filters: {})
```

**Step 6: 테스트 재실행**

Run:
```bash
bin/rails test test/services/favorite_search_test.rb test/services/favorite_search_indexer_test.rb test/jobs/reindex_favorite_job_test.rb
```

Expected: PASS.

**Step 7: 커밋**

Run:
```bash
git add app/services app/jobs db/migrate test/services test/jobs db/schema.rb
```

Run:
```bash
git commit -m "feat: add SQLite FTS search index for favorites"
```

---

### Task 8: Favorites Routes and Controllers

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/favorites_controller.rb`
- Create: `app/controllers/favorite_notes_controller.rb`
- Create: `app/controllers/collection_memberships_controller.rb`
- Test: `test/controllers/favorites_controller_test.rb`
- Test: `test/controllers/favorite_notes_controller_test.rb`
- Test: `test/controllers/collection_memberships_controller_test.rb`

**Step 1: controller 테스트 작성**

Cover:
- favorites index search/filter/view_mode
- favorite create with URL normalize/safety/type detection
- favorite show
- favorite note update
- collection add/remove from favorite

**Step 2: 실패 확인**

Run:
```bash
bin/rails test test/controllers/favorites_controller_test.rb test/controllers/favorite_notes_controller_test.rb test/controllers/collection_memberships_controller_test.rb
```

Expected: 라우트 또는 컨트롤러 미정의로 실패.

**Step 3: routes 구현**

Recommended routes:
```ruby
root "favorites#index"
resources :favorites, only: %i[index create show destroy] do
  resource :note, only: %i[update], controller: "favorite_notes"
  resource :collection_membership, only: %i[create destroy]
  post :retry, on: :member
end
resources :collections, only: %i[index show create update destroy]
```

**Step 4: controller 최소 구현**

Key behaviors:
- create 시 job enqueue
- index 에서 `FavoriteSearch` 사용
- note update 후 상세 화면으로 redirect or turbo response
- retry 액션에서 failed item 재분석

**Step 5: controller 테스트 재실행**

Run:
```bash
bin/rails test test/controllers/favorites_controller_test.rb test/controllers/favorite_notes_controller_test.rb test/controllers/collection_memberships_controller_test.rb
```

Expected: PASS.

**Step 6: 커밋**

Run:
```bash
git add config/routes.rb app/controllers test/controllers
```

Run:
```bash
git commit -m "feat: add favorites notes and membership controllers"
```

---

### Task 9: Archive UI and View Modes

**Files:**
- Create: `app/views/favorites/index.html.erb`
- Create: `app/views/favorites/show.html.erb`
- Create: `app/views/favorites/_search_bar.html.erb`
- Create: `app/views/favorites/_filter_bar.html.erb`
- Create: `app/views/favorites/_favorite_card.html.erb`
- Create: `app/views/favorites/_favorite_row.html.erb`
- Create: `app/views/favorites/_empty_state.html.erb`
- Create: `app/views/favorites/_note_form.html.erb`
- Create: `app/javascript/controllers/view_mode_controller.js`
- Create: `app/javascript/controllers/filter_sheet_controller.js`
- Create: `app/javascript/controllers/auto_submit_controller.js`
- Modify: `app/assets/stylesheets/application.tailwind.css`
- Test: `test/system/archive_search_flow_test.rb`
- Test: `test/system/favorite_note_flow_test.rb`

**Step 1: system test 작성**

Cover:
- 홈 진입 시 카드 목록 표시
- 검색 입력 시 결과 축소
- 카드/리스트 전환
- 상세 진입
- 메모 작성 후 목록에서 메모 배지 표시

**Step 2: 실패 확인**

Run:
```bash
bin/rails test:system test/system/archive_search_flow_test.rb test/system/favorite_note_flow_test.rb
```

Expected: 뷰 미구현으로 실패.

**Step 3: index/show UI 구현**

Requirements:
- 검색바 + 필터 칩
- 카드와 리스트 전환
- 모바일 1열 우선 레이아웃
- 상세에서 메모 편집 가능
- empty state 제공

**Step 4: Stimulus 컨트롤러 구현**

Use controllers for:
- view mode persistence
- filter sheet open/close
- auto submit on search/filter changes

**Step 5: system test 재실행**

Run:
```bash
bin/rails test:system test/system/archive_search_flow_test.rb test/system/favorite_note_flow_test.rb
```

Expected: PASS.

**Step 6: 커밋**

Run:
```bash
git add app/views app/javascript app/assets test/system
```

Run:
```bash
git commit -m "feat: build searchable archive UI with notes"
```

---

### Task 10: Collections UX

**Files:**
- Create: `app/controllers/collections_controller.rb`
- Create: `app/views/collections/index.html.erb`
- Create: `app/views/collections/show.html.erb`
- Create: `app/views/collections/_form.html.erb`
- Test: `test/controllers/collections_controller_test.rb`
- Test: `test/system/collection_management_flow_test.rb`

**Step 1: collection 테스트 작성**

Cover:
- collection 생성/수정/삭제
- collection show 에 속한 favorites 노출
- favorite 상세에서 collection 연결
- collection filter 동작

**Step 2: 실패 확인**

Run:
```bash
bin/rails test test/controllers/collections_controller_test.rb
```

Run:
```bash
bin/rails test:system test/system/collection_management_flow_test.rb
```

Expected: controller/view 미구현으로 실패.

**Step 3: collection 구현**

Requirements:
- 이름/설명 입력
- collection index
- collection detail page
- collection 안 검색/필터 재사용

**Step 4: 테스트 재실행**

Run:
```bash
bin/rails test test/controllers/collections_controller_test.rb
```

Run:
```bash
bin/rails test:system test/system/collection_management_flow_test.rb
```

Expected: PASS.

**Step 5: 커밋**

Run:
```bash
git add app/controllers/collections_controller.rb app/views/collections test/controllers/collections_controller_test.rb test/system/collection_management_flow_test.rb
```

Run:
```bash
git commit -m "feat: add collection management flows"
```

---

### Task 11: PWA and Mobile Share Capture

**Files:**
- Create: `public/manifest.json`
- Create: `public/sw.js`
- Modify: `app/views/layouts/application.html.erb`
- Test: extend `test/controllers/favorites_controller_test.rb`

**Step 1: share target 테스트 추가**

Cover:
- `POST /favorites` with shared URL works
- mobile share params handled same as normal form

**Step 2: 실패 확인**

Run:
```bash
bin/rails test test/controllers/favorites_controller_test.rb
```

Expected: share target 관련 assertion 실패.

**Step 3: PWA 파일 구현**

Manifest requirements:
- `name`
- `short_name`
- `display`
- `icons`
- `share_target` -> `POST /favorites`

**Step 4: layout 연결**

Add:
- manifest link
- theme color
- service worker registration if used

**Step 5: 테스트 재실행**

Run:
```bash
bin/rails test test/controllers/favorites_controller_test.rb
```

Expected: PASS.

**Step 6: 수동 검증 메모 추가**

Document manual verification in `docs/deploy/urlf2-vps-checklist.md`:
- iOS share sheet
- Android share sheet
- home screen install

**Step 7: 커밋**

Run:
```bash
git add public app/views/layouts test/controllers/favorites_controller_test.rb docs/deploy/urlf2-vps-checklist.md
```

Run:
```bash
git commit -m "feat: add PWA share target support"
```

---

### Task 12: urlf Snapshot Importer

**Files:**
- Create: `app/services/importers/urlf_snapshot_importer.rb`
- Create: `lib/tasks/urlf_import.rake`
- Create: `test/services/importers/urlf_snapshot_importer_test.rb`

**Step 1: importer 테스트 작성**

Cover:
- source DB read
- favorites import
- analyses import
- duplicate URL skip/update policy
- note default blank
- idempotent re-run prevention

**Step 2: 실패 확인**

Run:
```bash
bin/rails test test/services/importers/urlf_snapshot_importer_test.rb
```

Expected: importer 미구현으로 실패.

**Step 3: importer 구현**

Recommended interface:
```ruby
Importers::UrlfSnapshotImporter.call(source_db_path:)
```

Import policy:
- old favorite -> new favorite
- old analysis -> new analysis
- no live sync
- preserve timestamps where possible

**Step 4: rake task 구현**

Example:
```ruby
namespace :urlf do
  desc "Import urlf snapshot into urlf2"
  task import: :environment do
    Importers::UrlfSnapshotImporter.call(source_db_path: ENV.fetch("URLF_SOURCE_DB_PATH"))
  end
end
```

**Step 5: importer 테스트 재실행**

Run:
```bash
bin/rails test test/services/importers/urlf_snapshot_importer_test.rb
```

Expected: PASS.

**Step 6: smoke import 문서화**

Add checklist items:
- source DB backup
- dry run
- row counts compare
- random sample compare

**Step 7: 커밋**

Run:
```bash
git add app/services/importers lib/tasks test/services/importers docs/deploy/urlf2-vps-checklist.md
```

Run:
```bash
git commit -m "feat: add one-time importer for urlf snapshot"
```

---

### Task 13: End-to-End Verification and Release Prep

**Files:**
- Modify: `README.md`
- Modify: `docs/deploy/urlf2-vps-checklist.md`

**Step 1: 전체 테스트 실행**

Run:
```bash
bin/rails test
```

Expected: all unit/controller/job tests pass.

**Step 2: 시스템 테스트 실행**

Run:
```bash
bin/rails test:system
```

Expected: core archive flows pass.

**Step 3: 앱 기본 동작 수동 확인**

Run:
```bash
bin/rails server
```

Expected: local app boots and `/` renders.

Manually verify:
- URL 저장
- 분석 대기 상태
- 검색
- 메모 편집
- 컬렉션 생성
- 상세 이동

**Step 4: import dry run**

Run:
```bash
bin/rails urlf:import URLF_SOURCE_DB_PATH=/absolute/path/to/urlf.sqlite3
```

Expected: sample import succeeds on local copy.

**Step 5: 릴리즈 체크리스트 확정**

Update docs with:
- production env vars
- first deploy order
- import order
- rollback notes

**Step 6: 최종 커밋**

Run:
```bash
git add .
```

Run:
```bash
git commit -m "chore: finalize urlf2 release readiness"
```

---

## Notes for Execution

- `Task 1`부터 `Task 4`까지는 기반 공사이므로 순차 실행한다.
- `Task 9`와 `Task 10`은 UI 단에서 일부 병렬화 가능하지만, `Task 8` 라우트/컨트롤러 이후에만 착수한다.
- `Task 12` importer는 핵심 앱 흐름이 안정화된 뒤 진행한다.
- 검색 품질이 기대에 못 미치면 `Task 7`에서 FTS tokenizer 옵션과 가중치 조정 단계를 추가한다.
- 모바일 UX는 반드시 실제 기기 또는 모바일 에뮬레이션으로 검증한다.

---

## Verification Checklist

- `bin/rails db:prepare`
- `bin/rails test`
- `bin/rails test:system`
- `bin/rails routes`
- `bin/rails urlf:import URLF_SOURCE_DB_PATH=/absolute/path/to/urlf.sqlite3`
- `bin/rails server`

---

Plan complete and saved to `docs/plans/2026-04-07-urlf2-implementation.md`. Two execution options:

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

Which approach?
