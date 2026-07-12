# URLFavorites 2.0 — DDD Architecture Refactor Spec (Strong)

**Date:** 2026-04-15 (Asia/Seoul)  
**Status:** Approved (Chat)  
**Scope:** Global (entire app)  
**Refactor Style:** Clean cut (rename/move + update all callers, no wrappers)  
**Root Namespace:** `UrlFavorites::...`

---

## 1. 목적 (Goals)

- Rails 앱에서 “로직의 위치”를 고정해 AI/사람이 빠르게 찾고 고칠 수 있게 한다.
- 컨트롤러/잡은 얇게 유지하고, 모든 유스케이스를 **UseCase**에 집중시킨다.
- llama-server/yt-dlp/Nokogiri/임베딩/검색 인프라 등 외부 의존성을 **Integrations**로 격리한다.
- URL 안전성, 상태 전이, 재시도(backoff), raw_content 재사용 같은 규칙을 **Domain**에 고정한다.

## 2. 비목표 (Non-Goals)

- ActiveRecord를 순수 엔티티/리포지토리 패턴으로 분리하지 않는다. (Rails CoC 유지)
- DB 스키마 대수술은 하지 않는다. (필요 시 제약/인덱스는 별도 Phase)

---

## 3. 아키텍처 원칙 (Architecture Rules)

### 3.1 레이어와 의존성 방향

- `Domain` (규칙/값객체/정책/에러)
  - Rails/HTTP/CLI에 의존하지 않는다.
- `Integrations` (외부 시스템/인프라 어댑터)
  - HTTP 클라이언트, CLI 실행, 스크래핑, 임베딩/검색 드라이버 등.
  - 가능한 한 “입력 → 출력”만 제공하고 상태를 들지 않는다.
- `UseCases` (업무 흐름/오케스트레이션)
  - Domain 규칙을 사용하고 Integrations를 호출한다.
  - ActiveRecord 트랜잭션 경계를 명확히 한다.
  - 데이터 이관(Importers)은 별도 레이어가 아니라 UseCases 하위 컨텍스트로 둔다. (입력 포맷/파일/외부 리소스 접근은 Integrations로)
- Rails Adapters (Controllers/Jobs/Views/Models)
  - 컨트롤러/잡은 UseCase 하나만 호출한다.
  - 모델은 연관/검증 등 “데이터 모델” 중심(규칙은 Domain/UseCase로 이동).

의존성 방향:

`Rails(Controller/Job)` → `UseCases` → (`Domain` + `Integrations`)  
`Domain`은 어디에도 의존하지 않음.

### 3.2 네이밍/경로 규칙 (Zeitwerk)

새 코드의 루트는 `app/url_favorites/`이며, 상수명과 경로는 Zeitwerk 규칙을 따른다.

예:

- `UrlFavorites::UseCases::Analysis::RunAnalysis`
  - `app/url_favorites/use_cases/analysis/run_analysis.rb`
- `UrlFavorites::Integrations::LlamaServer::Client`
  - `app/url_favorites/integrations/llama_server/client.rb`
- `UrlFavorites::Domain::Urls::SafetyPolicy`
  - `app/url_favorites/domain/urls/safety_policy.rb`

---

## 4. 디렉토리 구조 (New Structure)

```
app/url_favorites/
  domain/
    errors/
    urls/
    favorites/
    analysis/
    search/
    collections/
    notes/
    newsletter/
  integrations/
    llama_server/
    youtube/
    webpage/
    search/
    importers/
      urlf_snapshot/
  use_cases/
    importers/
    favorites/
    analysis/
    search/
    collections/
    notes/
    newsletter/
```

> 바운디드 컨텍스트는 폴더로 고정하고, “어디에 어떤 코드가 있어야 하는지”를 강제한다.

---

## 5. 핵심 플로우 (Core Flows)

### 5.1 Favorite 생성

엔트리포인트:

- `FavoritesController#create`

흐름:

1. `UrlFavorites::UseCases::Favorites::CreateFavorite` 호출
2. Domain:
   - URL 정규화 (`Urls::Normalizer`)
   - URL 안전성 검사 (`Urls::SafetyPolicy`: http/https only + private/internal IP 차단)
   - 타입 판별 (`Urls::TypeDetector`: webpage|youtube)
3. `Favorite.create!` 후 분석 enqueue:
   - `UrlFavorites::UseCases::Analysis::EnqueueAnalysis`

규칙:

- 요청에서 절대 분석을 inline 수행하지 않는다. (항상 async)

### 5.2 분석 실행 (Webpage / YouTube)

엔트리포인트:

- `AnalyzeWebpageJob`
- `AnalyzeYoutubeJob`

잡 규칙:

- 잡은 공통으로 `UrlFavorites::UseCases::Analysis::RunAnalysis.(favorite_id:)`만 호출한다.

UseCase 내부 규칙:

- 상태 전이: `pending|failed → analyzing → done|failed`
- `favorite.raw_content`가 있으면 **재추출 금지** (raw_content 재사용)
- llama-server HTTP 호출은 **120s timeout**을 강제
- JSON 파싱 실패/타임아웃/추출 실패는 Domain 에러로 표준화하고 Solid Queue retry를 유발

### 5.3 재시도 정책

- max 3회
- backoff: 30s / 60s / 120s
- retry_count 증가, error_message 기록, 3회 초과 시 manual retry UI 노출

### 5.4 검색/인덱싱

엔트리포인트:

- `ReindexFavoriteJob` → `UrlFavorites::UseCases::Search::ReindexFavorite`
- 검색 API/화면 → `UrlFavorites::UseCases::Search::*`

### 5.5 Newsletter 발송

엔트리포인트:

- `WeeklyNewsletterJob`

잡 규칙:

- 잡은 `UrlFavorites::UseCases::Newsletter::*`만 호출한다.

UseCase 내부 규칙:

- 발송 대상 선정/콘텐츠 구성/발송 트리거를 유스케이스로 캡슐화한다.
- 실패 시 재시도/오류 기록 방식은 Domain 에러 및 Solid Queue 재시도 규칙에 맞춘다.

### 5.6 Collections 관리 (CRUD + Membership)

엔트리포인트:

- `CollectionsController`
- `CollectionMembershipsController`

컨트롤러 규칙:

- 컨트롤러는 `UrlFavorites::UseCases::Collections::*`만 호출한다.

UseCase 예시(가이드):

- `CreateCollection`, `UpdateCollection`, `DeleteCollection`
- `AddFavoriteToCollection`, `RemoveFavoriteFromCollection`

### 5.7 FavoriteNote 관리 (CRUD)

엔트리포인트:

- `FavoriteNotesController`

컨트롤러 규칙:

- 컨트롤러는 `UrlFavorites::UseCases::Notes::*`만 호출한다.

UseCase 예시(가이드):

- `CreateFavoriteNote`, `UpdateFavoriteNote`, `DeleteFavoriteNote` (또는 `UpsertFavoriteNote`)

---

## 6. Domain 규칙 (Policies / Value Objects)

### 6.1 URL Safety

- 허용: `http`, `https`
- 차단: `localhost`, private/internal IP ranges, link-local, 기타 내부망으로 해석되는 주소
- 모든 입력 URL은 `Normalizer`로 canonical form(트래킹 파라미터 제거 등)을 만든다.

### 6.2 Favorite Status State Machine

Domain에 상태 전이 규칙을 고정:

- `pending → analyzing → done`
- `pending|analyzing → failed` (예외 발생 시)
- `failed → analyzing` (재시도 시)

### 6.3 Raw Content Reuse

- `raw_content`가 존재하면 재시도/재분석 시에도 re-fetch 금지.
- 재추출이 필요한 경우(정책 변경 등)는 별도 유스케이스로 분리한다.

---

## 7. Integrations 인터페이스

### 7.1 Llama Server

- 책임: HTTP POST, 120s timeout, response body → JSON 파싱
- 기대 응답:
  - `summary`, `tags`, `key_points`, `sentiment`
- 실패는 Domain 에러로 변환:
  - timeout, non-200, invalid JSON, schema mismatch

### 7.2 Webpage Extraction

- 책임: Nokogiri 기반 title/OG/body 추출
- 추출 텍스트는 최대 8,000 chars

### 7.3 YouTube Extraction

- 책임: `yt-dlp --dump-json` 메타데이터 + 자막 추출
- 자막 fallback: manual → auto → description
- transcript는 최대 12,000 chars

### 7.4 Search / Embedding

- `UrlFavorites::Integrations::Search::EmbeddingClient`
  - 책임: 텍스트를 임베딩 벡터로 변환(외부 모델/서비스 호출 포함)
  - 인터페이스 예: `embed(texts:) -> vectors`
- `UrlFavorites::Integrations::Search::Indexer`
  - 책임: Favorite/Analysis 기반의 검색 인덱스 upsert/reindex/delete (저장소/인덱스 구현 세부사항을 은닉)
  - 인터페이스 예: `upsert_favorite(favorite_id:)`, `delete_favorite(favorite_id:)`, `reindex_all`
- `UrlFavorites::Integrations::Search::SemanticClient`
  - 책임: 벡터 검색/유사도 검색 실행 및 결과 스코어링/정렬(인덱스 구현 세부사항 은닉)
  - 인터페이스 예: `search(query:, limit:) -> results`

---

## 8. Clean Cut 마이그레이션 규칙

- 기존 `app/services/*` 코드는 새 구조로 **이동 + 네임스페이스 변경**한다.
- 모든 호출부(controllers/jobs/models/views)는 새 상수로 **전면 치환**한다.
- 기존 경로에 wrapper를 남기지 않는다.
- `.bak` 파일은 실행 경로에서 제외되지만, 혼선이 크면 별도 정리 Phase로 분리한다.

초기 매핑(가이드):

- URL 관련: `UrlNormalizer`, `UrlSafetyValidator`, `UrlTypeDetector`, `UrlCategoryDetector`
  - → `UrlFavorites::Domain::Urls::*`
- 추출/LLM: `WebpageScraper`, `YoutubeExtractor`, `LlmAnalyzer`
  - → `UrlFavorites::Integrations::*` (webpage/youtube/llama_server)
- 검색/임베딩: `EmbeddingService`, `FavoriteSearchIndexer`, `FavoriteSearch`, `SemanticSearch`
  - → `UrlFavorites::UseCases::Search::*` + `UrlFavorites::Integrations::Search::*`
- 학습/태깅: `TagLearning`
  - → `UrlFavorites::Domain::*` 또는 `UseCases::*` (업무 흐름 여부로 결정)
- 데이터 이관: `Importers::UrlfSnapshotImporter`
  - → `UrlFavorites::UseCases::Importers::ImportUrlfSnapshot` (필요 시 `UrlFavorites::Integrations::Importers::UrlfSnapshot::*`로 입력 포맷 읽기/파싱 분리)

---

## 9. 검증 기준 (Verification Criteria)

- Rails boot 시 Zeitwerk 상수 로딩 에러가 없다.
- Favorite 생성 → 분석 enqueue → status 전이/분석 저장까지 기존 동작이 유지된다.
- raw_content 재사용 규칙이 재시도에서 지켜진다.
- URL 안전성 정책이 “사설 IP/내부망”을 차단한다.
- Solid Queue retry/backoff가 정책대로 동작한다.
- Newsletter Job이 UseCase를 경유하여 정상 발송된다.
- Collection CRUD가 정상 동작한다.
- FavoriteNote CRUD가 정상 동작한다.
- Importer가 기존 데이터를 정상 이관한다.
- Search/Embedding 인덱싱 및 검색이 정상 동작한다.
