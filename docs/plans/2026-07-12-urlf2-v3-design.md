# URLFavorites v3.0 설계 — X(트위터) 분석 + 멀티 LLM 태스크 라우팅

- 작성일: 2026-07-12
- 상태: draft (구현 착수용)
- 상위 스펙: `docs/superpowers/specs/2026-04-15-ddd-refactor-architecture-design.md` (DDD 레이어 규칙 — **필수 준수**)
- 에이전트 지침: `AGENTS.md`

## 0. 배경 / 핵심 전제

현재 코드 조사 결과 두 목표 모두 **기존 인프라 재활용**이 정답이다. 새 스크래퍼·새 LLM 프레임워크를 만들지 않는다.

- **멀티 LLM 인프라는 이미 존재**한다. `UrlFavorites::Integrations::LlamaServer::Client`는 `LLM_BACKENDS`(JSON 배열)로 다중 백엔드를 지원하고, 백엔드별 `url/model/timeout` + 연결 캐시 + **순차 failover 루프**를 이미 구현했다. 현재 `.env`엔 서버 1개(`10.10.0.5:8282`)만 등록되어 있고 선택 로직이 항상 1번부터라 두 서버를 동시에 못 쓸 뿐이다.
- **X 분석은 새 스크래퍼 금지.** X DIY 스크래핑은 GraphQL query ID가 2~4주마다 바뀌고 TLS 핑거프린팅으로 유지보수 지옥이다. 이 프로젝트엔 이미 **Jina Reader(`r.jina.ai`)**(`Webpage::Scraper`의 CF 폴백)와 **yt-dlp**가 있다. 둘 다 SPA 렌더링·안티봇을 서버 측에서 처리해준다 → 재사용한다.
- `github`는 이미 "웹페이지 스크래퍼 + content_type 태그"만으로 붙어 있다. 이것이 새 타입 추가의 **정확한 템플릿**이다.

---

## Feature 1 — X(트위터) 콘텐츠 분석

### 현재 파이프라인 (진입점)
`create_favorite` → `TypeDetector.call` → `Favorite#content_type` → `enqueue_analysis`(youtube/webpage 분기) → `RunAnalysis#extract_content`(youtube=Extractor, else=Webpage::Scraper) → `LlamaServer::Client.call(raw_content, type:, analysis_style:)`(type별 system_prompt) → `upsert_analysis!`.

### 변경 목록 (파일 단위)

1. **`app/url_favorites/domain/urls/type_detector.rb`**
   - `TWITTER_PATTERNS` 추가: `x.com`, `twitter.com`, `mobile.twitter.com` (개별 트윗 `/status/…` 및 프로필 모두). YouTube/GitHub 판별 앞이든 뒤든 무방하나 명시적으로.
   - 반환 `content_type = "twitter"`.

2. **`app/models/favorite.rb`**
   - `CONTENT_TYPES`에 `"twitter"` 추가 (inclusion 검증 통과하도록).

3. **`app/url_favorites/integrations/twitter/extractor.rb`** (신규, Integrations 레이어)
   - 입력 URL → 다음을 반환: `{ title:, body_text:, author:, thumbnail_url:, is_video:, transcript: (동영상 시), raw_content: }`.
   - **텍스트/스레드**: Jina Reader(`https://r.jina.ai/<url>`)로 트윗 본문 + 작성자 스레드 추출. `Webpage::Scraper.fetch_via_jina`/`parse_jina_response` 로직을 공유(중복 방지 — 공통 Jina 헬퍼로 추출하거나 재사용). X는 평문 GET을 차단하므로 **Jina 직행**(plain Faraday GET 생략).
   - **동영상 트윗**: `is_video`면 yt-dlp로 메타데이터·자막 추출. `Integrations::Youtube::Extractor` 패턴을 참고하되 별 클래스로. 동영상 여부는 Jina 결과/URL 힌트로 판단하고, yt-dlp 실패 시 텍스트 분석으로 graceful fallback.
   - DDD: Integrations 레이어이므로 외부 호출(Jina/yt-dlp) 격리. Domain·UseCase는 이 클래스 인터페이스만 의존.

4. **`app/url_favorites/use_cases/analysis/enqueue_analysis.rb`**
   - `content_type == "twitter"` → `AnalyzeTwitterJob.perform_later(...)` 로 라우팅.

5. **`app/jobs/analyze_twitter_job.rb`** (신규)
   - `AnalyzeYoutubeJob` 패턴 복제. `RunAnalysis.call`로 위임. Solid Queue, 멱등.

6. **`app/url_favorites/use_cases/analysis/run_analysis.rb`**
   - `extract_content`에 `content_type == "twitter"` 분기 추가 → `Twitter::Extractor.call`. 반환 `raw_content` 구성(제목+본문+작성자+동영상 transcript). youtube처럼 title/thumbnail 업데이트.

7. **`app/url_favorites/integrations/llama_server/client.rb`**
   - `system_prompt(type, style)`에 `type == "twitter"`용 `twitter_prompt_rules` 추가: **핵심 주장, 스레드 구조(연속 트윗의 논리), 인용/외부 링크 리소스, 작성자·맥락**을 추출하도록. YouTube 규칙 블록이 패턴.
   - ⚠️ 이 파일은 Feature 2도 수정한다 → **Feature 2 완료 후 착수**(태스크 의존성 참조). Feature 1은 `system_prompt`/신규 `twitter_prompt_rules`만 건드리고 backend 선택 로직은 건드리지 않는다.

8. **`app/url_favorites/domain/urls/category_detector.rb`**
   - twitter 카테고리 매핑 추가.

### 테스트 (Minitest, WebMock)
- `type_detector` X 패턴 스펙.
- `twitter/extractor` — Jina 응답 stub, yt-dlp stub(동영상), 텍스트/동영상 경로.
- `run_analysis` twitter 분기 — LlamaServer stub.
- `enqueue_analysis` → AnalyzeTwitterJob enqueue 검증.

---

## Feature 2 — 멀티 LLM 태스크 라우팅 (beacon + synapse)

사용자 결정: **두 서버가 서로 다른 크기/모델 → 태스크 라우팅**.

### 0단계 — 서버 디스커버리 (구현 전 필수)
- beacon(`10.10.0.4`), synapse(`10.10.0.5`) 각각 `/v1/models` 조회 또는 `ssh beacon`/`ssh synapse`로 구동 모델·포트·크기 확인.
  - 현재 `.env`: `LLAMA_SERVER_URL=http://10.10.0.5:8282` (= synapse). beacon 포트/모델은 미확인 → 워커가 확인.
- 결과를 이 문서 하단 "서버 인벤토리"에 기록.

### 설계
1. **라우팅 정책은 Domain에** — `app/url_favorites/domain/analysis/backend_router.rb` (신규, 순수 로직)
   - 입력: `content_type`, `content_length`(대략 토큰/문자 수), (선택) `analysis_style`.
   - 출력: 백엔드 우선순위 배열(role 기반). 예: 긴 transcript(youtube/twitter 동영상)·detail 분석 → `heavy`(큰 모델), 짧은 webpage·임베딩 → `fast`(작은 모델).
   - Domain 규칙: 외부 의존 없음. 순수 함수. 단위 테스트 쉬움.

2. **`LLM_BACKENDS` 스키마 확장** — 각 백엔드에 `role` 필드 추가.
   - 예: `[{"url":"http://10.10.0.4:PORT","model":"<beacon-big>","role":"heavy","timeout":180},{"url":"http://10.10.0.5:8282","model":"<synapse-small>","role":"fast","timeout":120}]`
   - `.env`(로컬)와 배포 systemd drop-in(`env.conf`) 양쪽 갱신 대상 명시(구현은 로컬 `.env`만, 배포는 별도).

3. **`LlamaServer::Client` 변경**
   - `call(content, type:, analysis_style:, content_length: nil)` — 라우팅 힌트 전달(호출부 `RunAnalysis`에서 raw_content 길이 전달).
   - `resolve_backends` 결과를 `BackendRouter`로 **정렬**(선택된 role 우선) 후 기존 failover 루프 그대로 사용 → 라우팅 + 이중화 동시 확보.
   - 라우팅 실패/미스매치 시 기존 순차 전체 순회로 안전 폴백.

4. **임베딩 오프로드** — `app/url_favorites/integrations/search/embedding_client.rb`
   - `EMBEDDING_URL`을 `fast` 서버로 분리 가능하게(이미 `EMBEDDING_URL || LLAMA_SERVER_URL` 지원). `.env`에 `EMBEDDING_URL` 명시 → 인덱싱이 분석과 자원 경쟁하지 않도록.

5. **Solid Queue 동시성 재검토**
   - 서버가 2대가 됐으므로 AI job 동시성 상향 여지 검토(현재 max 2 = 단일 서버 OOM 회피값). 단, 라우팅상 heavy로 몰릴 수 있으니 **서버별 용량 확인 후 신중히**. 기본은 유지, 근거 있을 때만 상향하고 SUMMARY에 기록.

### 테스트
- `backend_router` 단위 테스트: content_type/length별 우선순위 반환.
- `LlamaServer::Client` 라우팅+failover: 라우팅으로 heavy 우선, heavy 실패 시 fast 폴백 stub.

---

## 실행 규칙 (워커 공통)

- **DDD 스펙 준수**: 신규 코드는 `app/url_favorites/{domain,integrations,use_cases}/`에 배치. Domain은 외부 의존 금지. Controller/Job은 UseCase 하나만 호출.
- 변경은 작고 단일 목적. LOC 가이드(Feature ≤300, 파일 ≤500) 준수, 초과 시 분할.
- 로컬에서 `bundle exec rubocop -a` + `bin/rails test` 통과까지. **실제 실행 판정은 VPS**(프로젝트 규칙) — 로컬 테스트는 참고용.
- 시크릿/운영 DB(`storage/*.sqlite3*`) 건드리지 않음.
- 완료 시 `docs/work-log/`에 결과 기록.

## 태스크 순서 (의존성)
1. **Task A — Feature 2** (서버 디스커버리 + 멀티 LLM 라우팅). `LlamaServer::Client` backend 로직 담당.
2. **Task B — Feature 1** (X 분석). Task A 이후 착수 — `LlamaServer::Client`의 prompt 메서드만 수정해 충돌 회피.

## 서버 인벤토리 (워커가 채움)
- beacon (10.10.0.4:8282): `Qwen3.6-35B-A3B-Kimi-K2.6-Reasoning-Distilled.IQ4_XS.gguf`, 34.66B total / A3B MoE, GGUF 18,928,323,072 bytes, 2×RTX 3060 12GB, `-np 1`, role=`fast`
- synapse (10.10.0.5:8282): `Qwen3.6-40B-Deck-Opus-NEO-CODE-HERE-2T-OT-IQ4_XS.gguf`, 39.07B dense, GGUF 22,066,217,984 bytes, 4×RTX 3070 8GB, `-np 1`, role=`heavy`

확인 근거: 2026-07-12 각 서버의 `/v1/models`, `ss -ltnp`, llama-server 실행 인자, `nvidia-smi` 조회. 두 프로세스 모두 병렬 슬롯이 1이고 GPU 메모리 여유가 작아 Solid Queue AI 동시성은 2로 유지한다.
