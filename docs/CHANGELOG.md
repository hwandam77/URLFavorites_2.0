# URLFavorites 2.0 변경 이력

| 날짜 | 변경 내용 | 대상 | 사유 |
|------|----------|------|------|
| 2026-04-07 | 초기 구성 — 4 에이전트 + 오케스트레이터 | 전체 | 하네스 신규 구축 |
| 2026-04-07 | GSD 통합 — .planning/ + ROADMAP 10 Phase | 전체 | GSD phase 관리 연결 |
| 2026-04-07 | tmux 2계층 병렬 — Claude Workers + Nexus LLM | 전체 에이전트 + 오케스트레이터 | Claude Workers + 30B/48B 코드 생성 조합 |
| 2026-04-10 | 배포 가이드 추가 — 서버 설정, 환경변수, 트러블슈팅 | CLAUDE.md | 첫 운영 배포 경험 문서화 |
| 2026-04-13 | Warm Archive 테마 전면 리디자인 | 전체 뷰 + 디자인 토큰 | Neo-Brutalist → Editorial Swiss |
| 2026-04-14 | UI 워크플로우 간소화 — 로컬 시각확인 제거 | CLAUDE.md | 로컬 빌드 후 서버 배포에서 바로 시각 확인 |
| 2026-04-15 | DDD 아키텍처 리팩토링 — app/services/ → app/url_favorites/ | 전체 백엔드 | 레이어 분리: Domain, Integrations, UseCases |
| 2026-04-16 | CSS 디자인 토큰 분리 — tokens.css, theme_controller 리팩토링 | 프론트엔드 | 다크/라이트 테마 구조화 |
| 2026-04-18 | PWA Share Target 구현 — manifest.json, share 액션, CSRF 예외 | PWA | 모바일 공유 타겟 등록 |
| 2026-04-27 | E2E 시스템 테스트 10개 추가 (전체 138개 통과) | 테스트 | favorites/collections flow, turbo-rails test config fix |
| 2026-07-12 | **v3.0** 멀티 LLM 태스크 라우팅 — `BackendRouter`(heavy/fast) + `LLM_BACKENDS`·`EMBEDDING_URL` | 백엔드/배포 | beacon=fast·synapse=heavy 콘텐츠별 라우팅 |
| 2026-07-12 | **v3.0** X(트위터) 분석 — `content_type "twitter"` + `Twitter::Extractor` + `AnalyzeTwitterJob` | 백엔드 | Jina/yt-dlp 재사용, 트윗 전용 프롬프트 |
| 2026-07-13 | 배포 파이프라인 하드닝 — `bin/deploy`(rbenv PATH·cd·sudo) + `deploy-doctor`(health 302·assets 제외·porcelain·폴링) 6버그 | 배포 도구 | 실전 배포 중 발견·수정, pre/post 전 항목 green |
| 2026-07-13 | X 분석 수정 — 개별 트윗을 X syndication API로 추출 | `Twitter::Extractor` | Jina 무인증 tier의 x.com 403 우회 |
| 2026-07-13 | detail_content 한국어 강제 (원문 언어 무관) | LLM 프롬프트 | 영어 원문에서 상세가 영문 출력되던 문제 |
| 2026-07-13 | 유튜브 분석 timeout 상향 120→240초 | VPS `env.conf` `LLM_BACKENDS` | 긴 자막 정상 생성(80~150초)이 120초 경계 초과로 간헐 `Net::ReadTimeout` 실패 |
| 2026-07-13 | `LLM_BACKENDS` JSON 큰따옴표 `\"` 이스케이프 | VPS `env.conf` | systemd가 따옴표 제거 → 무효 JSON → 재시작 시 전체 분석 `ParseError` 회귀 수정 |
| 2026-07-13 | 유튜브 LLM 라우팅 fast-first (`8dcfe67`) | `BackendRouter` | heavy 40B가 fast 35B보다 5배 느림 → fast 우선(상세 스타일은 heavy 유지), 타임아웃 마진 확보 |
| 2026-07-13 | **v3.0** X(트위터) 분류 필터 UI (`3c61b08`) | 사이드바 + index 필터 툴바 | 백엔드는 이미 twitter 지원 — UI 분류만 누락 |
| 2026-07-13 | 재분석 실패 시 완성 분석 보존 + 본문 추출 폴백 + 재분석 raw_content 초기화 (`e4fdd6a`) | `RunAnalysis`/`Scraper`/`RetryAnalysis` | 완성본이 "실패" 배지로 가려지고, tistory류 article 껍데기에서 92자만 추출되던 문제 |
| 2026-07-13 | 고아 solid-queue 워커 트리(PPID=1) 발견·제거 + 진단법 문서화 (`4d5fc3a`) | VPS 운영 / CLAUDE.md | 배포 후에도 잡이 옛 코드로 실행 — `lsof production_queue.sqlite3`로 이중 워커 확인 |
| 2026-07-13 | 내용 기반 카테고리 분류 — 분석 완료 시 제목+태그 신호 (`b3987c0`) | `CategoryDetector`/`RunAnalysis` | URL에 키워드 없는 블로그 글이 전부 "기타"로 분류되던 문제 |
| 2026-07-13 | 단축링크 302 리다이렉트 추적 (`608b9fe`) | `Webpage::Scraper` | share.google 링크가 "302 Moved" 본문으로 분석되던 문제 |
| 2026-07-13 | 디자인 피드백 — 사이드바 모바일 URL 폼 제거, 버전 라벨 v3.0 (`13ef4c3`, `82292f1`) | 사이드바 | |
| 2026-07-14 | **v3.0 업그레이드 최종 완료** — 완료 보고서 작성 | `docs/work-log/2026-07-14-v3-final-completion.md` | 계획 대비 완료 매트릭스 + 안정화 이력 + 운영 검증 evidence |
| 2026-07-15 | 디자인 피드백 — 사이드바 로고(URLFAV v3.0) 클릭 시 `/favorites` 이동 (`9385dc1`) | `shared/_sidebar.html.erb` | 브랜드 블록을 `link_to favorites_path`로 감쌈 (`display:block` inline으로 레이아웃 유지) |
| 2026-07-24 | Reddit 게시물 분석 지원 — `content_type "reddit"` + `Reddit::Extractor` (rdt-cli, `4a90b6d`/`1fc7154`) | 백엔드 | Agent-Reach 조사 결과 채택: 익명 API 전면 차단이라 rdt-cli+쿠키가 유일 경로. 실측 스키마 fixture 기반 파서. kimi+minimax 워커 병렬 발주 |
| 2026-07-24 | rdt-cli 설치·쿠키 운영 runbook (`cb1033c`) | `docs/runbooks/reddit-extraction.md` | 쿠키 7일 만료·headless 서버 credential 배치·PATH 함정 (yt-dlp 함정과 동일 클래스) |
| 2026-07-24 | **2단계 분석** — fast(35B) 즉시 제공 → heavy(40B) 정밀 갱신 (`e426e26`) | `RefineAnalysis`/`RefineAnalysisJob`/`Client`/`queue.yml`/뷰 배지 | Consensus 절차(sol 2회 검토 → grok·luna 병렬 구현 → grok 채택). `analysis_tier` 컬럼 추가, `limits_concurrency`로 정밀 전역 직렬화(요구: 순차+컨텍스트 리셋), CAS 재검사로 세대 역행 차단 |
| 2026-07-24 | **queue.yml 잠복 버그 수정** — 콤마 문자열 큐가 미소비되던 문제 (`e426e26` 포함) | `config/queue.yml` | Solid Queue 1.4는 `"a,b"`를 단일 큐 이름으로 해석 (QueueSelector 실증). 운영 실증: `default` 큐 잡 69개 완료 0 — 재인덱싱이 한 번도 실행된 적 없었음 |
| 2026-07-24 | **운영 배포** (Reddit + 2단계 분석, `648771f`) + 서버 정비 4건 | bastion | ① supervisor 단일화(`solid-queue@` stop+disable → puma 내장) ② `EMBEDDING_URL` 오설정 정정(8282→:8900, LLM 서버는 embeddings 501 — 큐 버그에 가려져 있던 2차 잠복 오류) ③ sqlite3 CLI 설치(deploy 백업 의존, 이관 누락) ④ rdt-cli를 uv `--python 3.12` 고정 설치(**Python 3.14에서 쿠키 인증 실패 함정** 실측) + credential 배치. 배포 후 default 큐 소비 0→14 실증, reddit 추출 운영 E2E 성공 |
| 2026-07-25 | **heavy 분석 전멸 회귀 수정** — system 메시지 2개 연속 → 단일 병합 (`8e36f08`) | `LlamaServer::Client` | heavy(40B Deck-Opus) chat template이 연속 system을 `raise_exception`으로 거부해 모든 heavy 호출이 500→fast 폴백. 2단계 분석의 "fast 위장 거부" 가드가 첫 실전에서 이 기왕 결함을 드러냄. reddit #334 실측 E2E로 fast(90초)→heavy(131초, 카테고리 재계산 포함) 전 구간 검증 완료 |
| 2026-07-25 | (후속 개선 항목) 재인덱싱 임베딩 400 — 통합 텍스트가 임베딩 입력 한도 초과 시 트렁케이션 필요 | `Search::Indexer`/`EmbeddingClient` | 비치명(FTS는 정상, 시맨틱 벡터만 누락). deploy 스크립트 기본 호스트 `vps-server`→`bastion` 정정도 후속 대상 (→ 2026-08-05 `4b86a53`에서 해결). ⚠️ **2026-08-03 정정**: 이 진단은 틀렸다. 트렁케이션은 이미 있었고(8000자) 실제 원인은 요청 키 `prompt`/`input` 불일치 + 응답 파싱 오류 2건이었다. "비치명"도 과소평가 — 벡터 보유 0행·`SemanticClient` 호출처 0곳으로 시맨틱 검색이 한 번도 동작한 적이 없었다. `f66e0c6` 참조. |
| 2026-07-30 | **온보딩 매뉴얼 섹션별 다중 패스 생성** (`3787fd1`) | `analysis_sections`/`Manual::PlanOutline`/`Manual::GenerateSection`/`LlamaServer::Client` | LLM이 8~10개 목차 설계(실패 시 기본 8개 폴백) 후 섹션별 개별 생성, 잡 2개. `Client.complete` 추가(JSON 강제 없는 raw-text 생성). 동시성 방어: `analysis.updated_at` 스냅샷 대조로 stale 발주 차단, 중단 재개 시 섹션 전량 삭제 후 재설계로 목차 어긋남 방지. 같은 커밋에 `REFINE_INPUT_LIMIT=8000` — 본문 상한 20,000자를 heavy(13tok/s)에 그대로 넣으면 `Net::ReadTimeout` 재발 |
| 2026-07-30 | **매뉴얼 렌더링** (`c3fdb2e`) | `MarkdownHelper`/`/favorites/:id/manual`/상세페이지 | `redcarpet` 도입 — LLM 출력은 신뢰경계 밖이라 sanitize 필수. `/favorites/:id/manual` 전용 페이지, 상세에 "매뉴얼 생성 중 (n/N 섹션)" 진행 표시 |
| 2026-07-30 | **structure.sql FTS5 섀도 테이블 DDL 제거** (`3a960a1`) | `db/structure.sql` | 신규 환경 스키마 로드가 'table already exists'로 실패 — FTS5 가상 테이블 생성 시 섀도 테이블이 자동 생성되므로 덤프에 있으면 안 됨 |
| 2026-07-30 | **Orca 워크트리 setup** (`c9ba56d`) | `orca.yaml`/`bin/orca-setup` | 새 워크트리에 gitignore된 `config/master.key`·`.env`를 메인 체크아웃에서 복사 후 `bin/setup` + tailwind 빌드 |
| 2026-07-31 | **분석 결과 뉴스레터 레이아웃** `/favorites/:id/brief` (`133f99b`) | brief 뷰 | 상세·매뉴얼·주간뉴스레터 세 뷰의 강점 합성(마스트헤드·콜로폰 / 목차 앵커·섹션 markdown / 리드 인용·key_points·같은 컬렉션). 화면 미노출이던 `analysis_sections.focus`를 섹션 부제로 사용 — 추가 LLM 호출 없이 상세도 상승. 기존 매뉴얼 페이지는 비교용 유지 |
| 2026-07-31 | **brief가 execution_brief 지원 + YouTube 케이스** (`5432b44`) | brief 뷰/`.section-body` CSS | brief는 `analysis_sections`가 있는 항목에서만 렌더돼 288개 중 1개에서만 동작(285개가 execution_brief) — 섹션 없으면 `detail_content`를 단일 longform 본문으로. `.section-body`에 h1~h4/blockquote/hr 규칙 추가(YouTube detail_content 105개 중 80개가 줄머리 마크다운 헤딩 보유) — `.section h2`와 명시도가 같아 반드시 뒤에 둬야 함. YouTube: 썸네일 리드 + 타임라인 자막 80구간, key_point 근거 링크가 YouTube에서 처음 살아남(timestamp 77/105 보유) |
| 2026-07-31 | **deploy-doctor 오판 수정** (`e6c0dc9`) | `bin/deploy-doctor` | `capture()`가 명령 성공 여부와 무관하게 stdout이 비면 stderr를 반환 — bastion은 로케일이 깨져 모든 ssh 명령이 setlocale 경고를 stderr로 출력. `git status --porcelain` 성공+빈출력(= clean worktree)일 때 그 경고가 "changed path 1건"으로 집계돼 서버가 깨끗할수록 pre/post 체크가 실패하는 뒤집힌 판정이었음. stderr 폴백을 실패한 명령으로만 한정 |
| 2026-08-03 | **임베딩 저장 복구** (`f66e0c6`) | `EmbeddingClient`/`favorite_embeddings`/`lib/tasks/fts_structure_dump.rake` | 2026-07-25 진단 정정분 반영 — 실제 원인은 요청 키 `prompt`→`input`, 응답 파싱 `parsed[:embedding]`→`data[0].embedding` 2건. 저장 위치를 FTS 밖 `favorite_embeddings` 테이블로 분리(FTS 재생성은 재적재 중 검색 공백·롤백 시 검색 전멸·structure.sql 섀도 DDL 재발 유발). `ON DELETE CASCADE` — 없으면 임베딩 행이 있는 즐겨찾기 삭제가 `InvalidForeignKey`로 실패(실측). 임베딩 입력에 tags·detail_content 추가(기존 title+summary+note는 평균 200자). 덤프 후 섀도 DDL 자동 제거 rake — `3a960a1`에 이은 두 번째 재발이라 수동 제거 대신 기계 강제로 승격 |
| 2026-08-03 | **시맨틱 검색 연결** (`59decac`) | `FavoriteSearch`/`SemanticClient` | `SemanticClient`는 코사인 유사도·필터까지 구현돼 있었으나 호출하는 코드가 한 곳도 없었음 — FTS 0건일 때만 폴백하도록 배선(기존 FTS 경로 불변). 무한재귀 차단: `SemanticClient`의 폴백이 `FavoriteSearch.call`을 다시 불러 연결하는 순간 상호 재귀 |
| 2026-08-03 | **시맨틱 유사도 하한 0.45** (`5ab7811`) | `SemanticClient` | 하한이 없어 무의미한 질의도 상위 50건을 반환. 운영 293건 전수 측정: 0.40이면 무의미 질의가 새고, 0.50이면 '컨테이너 오케스트레이션'이 0건. 임베딩 모델·코퍼스가 바뀌면 재측정 필요 |
| 2026-08-03 | **임베딩 백필 293/293** (391초, 전부 1024차원) | 운영 DB | 개념 검색 실증 — "토큰 비용을 줄이는 방법"→"클로드 토큰 아끼는 최고의 방법", "영상 자막을 텍스트로 뽑기"→"video-use". 셋 다 FTS로는 0건이던 질의 |
| 2026-08-04 | **github 리포 메타 + 브리프 리포 카드** (`382da8b`) | `Integrations::Github::RepoClient`/`favorites.source_metadata`/brief 뷰 | github은 144건으로 최대 content_type인데 전용 extractor가 없어 `Webpage::Scraper`로 HTML만 수집. REST `/repos/{owner}/{repo}` 사용, `source_metadata`는 github 외 타입도 쓸 수 있는 범용 JSON 이름(x/reddit의 `author`도 추출은 되나 저장할 자리가 없어 폐기 중). 실패는 전부 nil+로그 — API 장애가 분석 파이프라인을 막으면 안 됨. 브리프 리포 카드: ★·포크·언어·라이선스·이슈·최근푸시·토픽 8개, 보관/포크 배지 |
| 2026-08-04 | **301 리다이렉트 1회 추적** (`f48e98a`) | `Github::RepoClient` | GitHub은 리포 이름 변경/이전 시 301을 줌 — 미처리 12건 중 10건이 이 경우로 Location이 유효하게 도착(나머지 2건은 스폰서 페이지·검색 URL로 정당한 제외). 같은 호스트로만 1회 추적: 외부 호스트 Location 거부(열린 리다이렉트 방지), 연속 301은 실패 처리(무한루프 방지). `faraday-follow_redirects` 없이 5줄 |
| 2026-08-04 | **github 백필 142/144** | 운영 DB/`env.conf` | `GITHUB_TOKEN`을 systemd drop-in에 추가(비인증 60req/h → 5000). 리다이렉트로 회수된 예: `chopratejas/headroom`→`headroomlabs-ai/headroom`(★64,444) |
| 2026-08-05 | **배포 기본 호스트 vps-server → bastion** (`4b86a53`) | `bin/deploy`/`bin/deploy-doctor`/`AGENTS.md` | vps-server는 2026-07-22 해체됐는데 기본값이 그대로라 문서대로 치면 죽은 호스트로 배포를 시도 — 그동안 매번 `URLF_REMOTE_HOST=bastion`으로 우회. `AGENTS.md` SSH host 정정, usage·문서의 "VPS" 표현을 "the server"로, `llama_server_url` 10.10.0.5→10.10.0.4(실행 중 서비스 실측값). 환경변수 없이 `bin/deploy --quick urlfavorites_2.0` 배포 성공으로 검증 |
| 2026-08-30 | **테스트 부채 청산** (`956261e`) | 테스트 | multi-LLM 제거(`a888b5b`)·카테고리 개명(`dc1bdd4`) 커밋이 테스트 정리 없이 머지돼 12건 깨진 상태로 운영 — 기대값 갱신 + 폐기 테스트 정리로 283 runs 그린 복원 (AGENTS.md "완료 주장 전 증명 커맨드" 규칙 위반 상태였음) |
| 2026-08-30 | **LXC 이전 잔여 파이프라인 붕괴 발견·복구** | bastion PVE/LXC 101 | 8/20~21 인프라 재편(PVE+LXC)에서 **앱이 .git 없이 파일 복사**로 이전돼 commit-based 배포 불가 상태였음. 컨테이너에 git 저장소 복구(init+fetch+reset db1210e), github 리모트(이름 `github`)·credential(`/root/.git-credentials`) 구성. `bin/deploy`/`bin/deploy-doctor`를 LXC 대상으로 갱신: `pct_vmid=101` 래핑, 경로 `services/rails/urlfavorites`, 서비스 `rails-puma@urlfavorites` |
| 2026-08-30 | **시스템 의존성 전멸 복구** (LXC 101) | 운영 컨테이너 | yt-dlp·rdt-cli·sqlite3 CLI가 이전 때 전부 탈락 — YouTube/Reddit 추출·deploy 백업이 조용히 죽어 있었음. sqlite3 apt, yt-dlp·rdt-cli는 uv tool로 재설치, drop-in에 `PATH=/home/hwandam/.local/bin:...` 추가. ⚠️ 레딧 쿠키는 미배치 — `docs/runbooks/reddit-extraction.md` 따라 재배치 필요 |
| 2026-08-30 | **임베딩 서버 재구축 (bge-m3)** + **벡터 통일 재백필 377건** | LXC 101 `embeddings.service` | `EMBEDDING_URL=127.0.0.1:8900`이 가리키던 임베딩 서버가 이전 때 소실 — 8/26 이후 신규 favorite의 시맨틱 벡터가 유실(330/358). llama-cpp-python + GGUF로 재구축. 첫 시도 nomic-embed-text-v1.5는 한국어 무의미 질의 분리 불가(유효/무의미 최고 유사도 0.75 부근 겹침 — 영어 중심 모델 한계) → **bge-m3로 교체**: 1024차원(기존과 동일), 무의미 최고 0.454 vs 유효 최저 0.492로 분리 회복. 전체 377건 재백필로 차원 혼재(768/1024) 해소. E2E: "토큰 비용을 줄이는 방법"→"클로드 토큰 아끼는 최고의 방법" top-1 |
| 2026-08-30 | **시맨틱 하한 0.45→0.47** | `SemanticClient` | bge-m3 재측정: 무의미 최고 0.454, 유효 최저 0.492 — 중간값 0.47. `EmbeddingClient::EMBEDDING_MODEL`도 bge-m3로 |
| 2026-08-30 | **임베딩 누락 보강 태스크** (`8a2c4bf`) | `Indexer`/`urlf.rake` | `backfill_missing_embeddings` + `bin/rails urlf:backfill_embeddings` — 유실 복구를 일회성 runner가 아닌 재사용 태스크로. 테스트 스텁을 OpenAI 형식(`data[0].embedding`)으로 정정(f66e0c6 파싱 수정 후 스텁이 옛 형태로 방치) |
| 2026-08-30 | **2단계 분석(RefineAnalysis) 제거** (`8f62f5d`) | `RunAnalysis`/큐 | 단일 백엔드 전환 후 같은 모델·같은 프롬프트 2회 생성일 뿐 — 품질 근거 없음, LLM 시간 2배(최근 1주 실행 1건/26초). `RefineAnalysis`·`BackendRouter`·관련 잡/테스트 삭제, 큐 `ai_refine`→`ai_followup`, 직렬화 키 `refine_analysis`→`llm_serialization` 개명. `analysis_tier` 컬럼·배지는 기존 heavy 6건 표시용 유지 |
| 2026-08-30 | **graphify-out git 추적 제외** | `.gitignore` | 그래프 캐시 아티팩트(`.graphify_python`, `cache/`)가 저장소에 커밋돼 있었음 — untrack + gitignore |
| 2026-08-30 | **AGENTS.md 실상 반영** | `AGENTS.md` | 스택(Nexus vllm Qwen3.6-27B 단일), 인증(세션 토큰 이미 구현 — "Phase 1 VPN-only"는 허위), API(`/api/v1/` 미구현 명시), 배포(PVE LXC 구조·drop-in 실값·검증 커맨드), 임베딩(bge-m3) 갱신 |
