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
| 2026-07-25 | (후속 개선 항목) 재인덱싱 임베딩 400 — 통합 텍스트가 임베딩 입력 한도 초과 시 트렁케이션 필요 | `Search::Indexer`/`EmbeddingClient` | 비치명(FTS는 정상, 시맨틱 벡터만 누락). deploy 스크립트 기본 호스트 `vps-server`→`bastion` 정정도 후속 대상 |
