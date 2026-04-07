# URLFavorites 2.0 — Roadmap

## Milestone: v1.0 (초기 릴리즈)

- [ ] **Phase 1: Rails Bootstrap + 문서**
- [ ] **Phase 2: 코어 모델 + URL 서비스**
- [ ] **Phase 3: AI 추출 + 비동기 Job**
- [ ] **Phase 4: FTS5 검색 엔진**
- [ ] **Phase 5: 컨트롤러 + 라우트**
- [ ] **Phase 6: 아카이브 UI + 메모**
- [ ] **Phase 7: 컬렉션 UX**
- [ ] **Phase 8: PWA + 모바일 공유**
- [ ] **Phase 9: urlf 데이터 이관**
- [ ] **Phase 10: E2E 검증 + 릴리즈 준비**

### Phase 1: Rails Bootstrap + 문서

**Goal:** Rails 8 앱 골격을 생성하고, 프로젝트 문서를 urlf2 기준으로 정비한다.

**Requirements:** -

**Agent:** rails-core

**Plans:** 2 plans

Plans:
- [ ] 01-01-PLAN.md — Rails 8.1.x 앱 생성 + Gemfile, DB 설정, Solid Queue 동시성 제한
- [ ] 01-02-PLAN.md — README.md + VPS 배포 체크리스트 작성 + git 초기 커밋

**Success Criteria:**
1. `bin/rails --version`이 Rails 8.1.x를 출력한다
2. git 저장소가 초기화되고 첫 커밋이 존재한다
3. README.md에 로컬 실행 방법과 환경 변수 목록이 있다
4. docs/deploy/urlf2-vps-checklist.md가 존재한다

### Phase 2: 코어 모델 + URL 서비스

**Goal:** Favorite, Analysis, Collection, CollectionMembership 모델과 URL 정규화/안전성/타입감지 서비스를 TDD로 구현한다.

**Requirements:** R01, R02, R03

**Agent:** rails-test → rails-core

**Success Criteria:**
1. `bin/rails test test/models/` 전체 통과
2. `bin/rails test test/services/url_normalizer_test.rb test/services/url_safety_validator_test.rb test/services/url_type_detector_test.rb` 전체 통과
3. favorites.url에 unique 인덱스가 존재한다
4. 사설 IP/localhost URL이 차단된다

### Phase 3: AI 추출 + 비동기 Job

**Goal:** WebpageScraper, YoutubeExtractor, LlmAnalyzer 서비스와 AnalyzeWebpageJob, AnalyzeYoutubeJob을 TDD로 구현한다.

**Requirements:** R04, R05, R06, R07, R08

**Agent:** rails-test → rails-core

**Success Criteria:**
1. `bin/rails test test/services/webpage_scraper_test.rb test/services/youtube_extractor_test.rb test/services/llm_analyzer_test.rb` 전체 통과
2. `bin/rails test test/jobs/` 전체 통과
3. 상태 전이 pending→analyzing→done/failed이 테스트로 검증됨
4. raw_content 캐싱과 재시도 로직이 동작한다
5. llama-server 호출에 120초 timeout이 설정되어 있다

### Phase 4: FTS5 검색 엔진

**Goal:** SQLite FTS5 가상 테이블 기반 통합 검색과 자동 인덱스 갱신을 구현한다.

**Requirements:** R09, R10, R11

**Agent:** rails-test → rails-core

**Success Criteria:**
1. `bin/rails test test/services/favorite_search_test.rb test/services/favorite_search_indexer_test.rb test/jobs/reindex_favorite_job_test.rb` 전체 통과
2. title, summary, tags, note 검색이 동작한다
3. 태그/컬렉션/콘텐츠타입/상태 필터가 동작한다
4. 분석 완료, 메모 수정, 컬렉션 변경 시 인덱스가 자동 갱신된다

### Phase 5: 컨트롤러 + 라우트

**Goal:** FavoritesController, FavoriteNotesController, CollectionMembershipsController와 라우트를 TDD로 구현한다.

**Requirements:** R01, R09

**Agent:** rails-test → rails-core

**Success Criteria:**
1. `bin/rails test test/controllers/` 전체 통과
2. `bin/rails routes`에 favorites, notes, collections, memberships 라우트가 존재한다
3. 검색/필터/보기모드 파라미터가 동작한다
4. URL 저장 시 비동기 Job이 enqueue된다

### Phase 6: 아카이브 UI + 메모

**Goal:** 검색 중심 카드형 아카이브 홈, 독립 상세 페이지, 메모 편집 UI를 Hotwire + Tailwind로 구현한다.

**Requirements:** R12, R13, R14, R15, R17, R18

**Agent:** rails-ui

**Success Criteria:**
1. `bin/rails test:system test/system/archive_search_flow_test.rb test/system/favorite_note_flow_test.rb` 통과
2. 카드/리스트 보기 전환이 동작한다
3. 검색 입력 시 결과가 필터링된다
4. 상세 페이지에서 메모 편집이 가능하다
5. 모바일 1열 레이아웃이 적용된다
6. Turbo Stream으로 분석 상태가 실시간 갱신된다

### Phase 7: 컬렉션 UX

**Goal:** 컬렉션 CRUD UI와 즐겨찾기-컬렉션 연결 화면을 구현한다.

**Requirements:** R16

**Agent:** rails-ui

**Success Criteria:**
1. `bin/rails test test/controllers/collections_controller_test.rb` 통과
2. `bin/rails test:system test/system/collection_management_flow_test.rb` 통과
3. 컬렉션 생성/수정/삭제가 동작한다
4. 컬렉션 안에서 검색과 필터가 동작한다

### Phase 8: PWA + 모바일 공유

**Goal:** PWA manifest, service worker, 모바일 공유 시트 저장(share_target)을 구현한다.

**Requirements:** R19, R20

**Agent:** rails-ui

**Success Criteria:**
1. public/manifest.json에 share_target이 정의되어 있다
2. 공유 시트에서 URL 저장이 정상 동작한다 (controller test 통과)
3. 오프라인 fallback 화면이 존재한다

### Phase 9: urlf 데이터 이관

**Goal:** 기존 urlf SQLite 스냅샷을 urlf2로 1회 이관하는 importer와 rake task를 구현한다.

**Requirements:** R21, R22

**Agent:** rails-test → rails-core

**Success Criteria:**
1. `bin/rails test test/services/importers/urlf_snapshot_importer_test.rb` 통과
2. 중복 URL이 skip 처리된다
3. 재실행 시 멱등성이 보장된다
4. rake task `urlf:import`가 동작한다

### Phase 10: E2E 검증 + 릴리즈 준비

**Goal:** 전체 테스트 통과, 경계면 교차 비교, 검색 품질, 배포 준비 상태를 최종 검증한다.

**Requirements:** 전체

**Agent:** rails-qa

**Success Criteria:**
1. `bin/rails test` 전체 통과
2. `bin/rails test:system` 전체 통과
3. 앱이 로컬에서 정상 기동한다 (`bin/rails server`)
4. 시크릿 하드코딩 없음
5. LLAMA_SERVER_URL 환경 변수 필수 체크 로직 존재
6. docs/deploy/urlf2-vps-checklist.md가 완성되어 있다
