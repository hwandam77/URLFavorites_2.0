# Work Log — URLFavorites v3.0 세션 종합 (2026-07-12 ~ 07-13)

> 기획 → 구현(Orca 오케스트레이션) → 배포 → 배포 도구 하드닝 → 사후 버그 수정까지의 전체 기록.
> 세부 문서: 각 항목의 개별 work-log / plans / deploy 문서 링크 참조.

## 0. 개요

| 구분 | 내용 |
|------|------|
| 목표 | URLFavorites 2.0 → **v3.0**: ① X(트위터) 콘텐츠 분석 추가, ② 멀티 LLM 태스크 라우팅 |
| 방식 | **Orca Hub & Spoke 오케스트레이션** — Hub(Opus): 계획·분해·검증, Spoke: codex(구현)·grok(배포계획)·kimi(정리) |
| 결과 | v3.0 프로덕션 배포 완료·라이브 정상 (`https://urlf.hwandam.kr`), 배포 파이프라인 6버그 수정, 사후 X/한글 버그 2건 수정 |

관련 문서:
- 설계: [`docs/plans/2026-07-12-urlf2-v3-design.md`](../plans/2026-07-12-urlf2-v3-design.md)
- 배포 계획: [`docs/deploy/urlf2-v3-deploy-plan.md`](../deploy/urlf2-v3-deploy-plan.md)
- 개별 로그: [`multi-llm`](2026-07-12-urlf2-v3-multi-llm.md) · [`x-analysis`](2026-07-12-urlf2-v3-x-analysis.md) · [`x-syndication-fix`](2026-07-13-x-syndication-fix.md)

---

## 1. Feature 2 — 멀티 LLM 태스크 라우팅

**전제:** `LlamaServer::Client`는 이미 `LLM_BACKENDS`(JSON 배열) 다중 백엔드 + 순차 failover를 지원하고 있었음. 서버 1개만 등록돼 라우팅이 없던 상태.

**서버 인벤토리 (실측):**
| 서버 | 모델 | 크기 | GPU | role |
|------|------|------|-----|------|
| beacon `10.10.0.4:8282` | Qwen3.6-35B-A3B-Kimi (MoE) | 34.66B / A3B active | 2×RTX 3060 12GB | **fast** |
| synapse `10.10.0.5:8282` | Qwen3.6-40B-Deck-Opus (dense) | 39.07B | 4×RTX 3070 8GB | **heavy** |

두 서버 모두 `-np 1`(병렬 슬롯 1)·GPU 여유 작음 → Solid Queue AI 동시성 2 유지.

**구현:**
- `Domain::Analysis::BackendRouter`(신규, 순수 로직): `content_type`+`content_length`(+style) → role 우선순위 반환. 긴 콘텐츠(youtube/twitter ≥6000자)·detail 스타일 → `heavy` 우선, 그 외 → `fast` 우선.
- `LlamaServer::Client`: `resolve_backends` 결과를 BackendRouter로 정렬 후 기존 failover 루프 유지(라우팅+이중화). 라우팅 실패 시 전체 순회 폴백.
- `RunAnalysis`가 `content_length` 힌트 전달.
- 임베딩 오프로드: `EMBEDDING_URL`을 beacon(fast)로 분리.
- 프로덕션 env.conf에 `LLM_BACKENDS`(2백엔드) + `EMBEDDING_URL` 반영.

---

## 2. Feature 1 — X(트위터) 분석

**설계 원칙:** 새 스크래퍼 금지(X DIY 스크래핑은 2~4주마다 깨짐). 기존 인프라 재사용.

- `TypeDetector`: `x.com`/`twitter.com` 패턴 → `content_type "twitter"`, `Favorite::CONTENT_TYPES`에 추가.
- `Integrations::Twitter::Extractor`(신규): 텍스트/스레드는 Jina Reader, 동영상은 yt-dlp(YouTube 경로 재사용), 실패 시 graceful fallback.
- `AnalyzeTwitterJob`(신규) + `enqueue_analysis` 라우팅 + `run_analysis` 분기.
- `LlamaServer::Client#twitter_prompt_rules`: 핵심 주장·스레드 구조·인용/링크·작성자 추출.
- `CategoryDetector` twitter 매핑.

**Task A/B 검증:** RuboCop 0, 197 tests 0 failures, Zeitwerk 통과. client.rb의 backend 로직(Task A)과 prompt 메서드(Task B) 파일 충돌 없이 격리.

---

## 3. 배포

- 커밋 단위 배포(`bin/deploy` git-based). 배포 전 운영 DB 자동 백업(production + queue).
- env.conf에 `LLM_BACKENDS`/`EMBEDDING_URL` 추가 → `daemon-reload` → 배포 → restart.
- 라이브 검증: service active, health 302(로그인 리다이렉트), 부팅 로그 정상, LLM_BACKENDS 반영.

---

## 4. 배포 파이프라인 하드닝 (실전 투입 중 발견한 6버그)

`bin/deploy` / `bin/deploy-doctor`를 실제 배포에 처음 투입하며 잠복 버그 6개를 발견·수정. 모두 검증됨(최종 full deploy 시 pre/post 전 항목 green).

| # | 파일 | 버그 | 수정 |
|---|------|------|------|
| 1 | `bin/deploy` | `bundle: command not found` (비대화형 SSH가 rbenv init 미로드) — **원배포 중단 원인** | Ruby 명령에 rbenv shims PATH prefix |
| 2 | `bin/deploy` | `No Rakefile found` (bin/rails를 앱 밖에서 실행) | `cd <app> &&` prefix |
| 3 | `bin/deploy` | system 서비스 restart에 `sudo` 누락 | `sudo systemctl restart` |
| 4 | `bin/deploy-doctor` | health check가 200만 정상 — 302 로그인 리다이렉트를 오탐 FAIL | 200/301/302 허용 |
| 5 | `bin/deploy-doctor` | `public/assets`(빌드 산출물) 소스-클린 오탐 → **근본 원인**: `capture`의 `stdout.strip`이 porcelain 선행 공백 제거 → `status_paths` 오프셋 오류로 protected 경로 제외가 조용히 깨짐 | `status_paths` 정규식화(strip 무관) + `public/assets` PROTECTED 추가 |
| 6 | `bin/deploy-doctor` | post health-check가 restart 직후 Puma 부팅 전 실행 → 매 배포 거짓 FAIL | `poll_healthy` 폴링(1.5s×12) |

---

## 5. 사후 버그 수정 (라이브 테스트 중 발견)

### 5.1 X 분석 실패 — Jina 403
- **증상:** 실제 트윗(`x.com/thsottiaux/status/2076119366647894371`) 분석 failed.
- **진단:** 타입감지·라우팅·재시도 정상. 원인은 **Jina 무인증 tier가 x.com 도메인을 abuse 차단(403 AbuseAlleviationError)**. yt-dlp는 동영상 전용이라 텍스트 트윗 폴백 불가.
- **수정:** 개별 트윗(`/status/<id>`)은 **X syndication API**(`cdn.syndication.twimg.com/tweet-result`, 키 불필요)로 1차 추출, 실패 시 Jina, 동영상 yt-dlp 폴백. (`Twitter::Extractor#fetch_via_syndication`)
- **검증:** 실패했던 그 트윗 재분석 → done + 정확한 요약·태그.

### 5.2 detail_content 영문 출력
- **증상:** 영어 원문(X 트윗) 분석 시 summary는 한글인데 `detail_content`가 영문.
- **원인:** 일반 detail_content 프롬프트 규칙에 언어 지시 없음(YouTube만 "Korean markdown" 강제).
- **수정:** detail_content 규칙에 "원문 언어와 무관하게 반드시 한국어로 서술" 강제 → webpage/github/twitter 전부 적용.
- **검증:** 314 재분석 → detail_content 한글 확인.

---

## 6. 오케스트레이션 요약 (Hub & Spoke)

| 역할 | 담당 | 산출 |
|------|------|------|
| Hub (Opus) | 계획·분해·독립검증·배포·git 커밋 | 설계문서, 게이트 검증, 프로덕션 배포 |
| codex (gpt-5.6-sol) | Feature 1/2 구현, X syndication 수정 | 소스 코드 + 테스트 |
| grok (4.5) | 배포 계획 문서 | `docs/deploy/urlf2-v3-deploy-plan.md` |
| kimi (K2.x) | 기존 WIP 정리 커밋 | housekeeping 커밋 |

Hub는 소스 코드를 직접 작성하지 않고 Spoke에 위임, 모든 결과를 독립 검증(rubocop·test·deploy-doctor) 후 채택.

---

## 7. 커밋 히스토리 (`feat/trend-features-2026`, 모두 push)

| 커밋 | 내용 |
|------|------|
| `bd70ca9` | feat: v3.0 — X 분석 + 멀티 LLM 태스크 라우팅 |
| `c521256` | chore: 배포 도구·문서·설정 정리 (housekeeping) |
| `4f5a932` | fix(deploy): rbenv PATH + cd app + sudo restart |
| `584b411` | fix(deploy-doctor): health-check 302 인정 |
| `bb2b640` | fix(deploy-doctor): public/assets 소스-클린 제외 |
| `03db51b` | fix(deploy-doctor): status_paths strip된 porcelain 처리 (근본원인) |
| `9a28467` | fix(deploy-doctor): health-check 폴링 (재시작 타이밍) |
| `38d6a68` | fix(twitter): 개별 트윗을 X syndication API로 추출 (Jina 403 우회) |
| `75e3041` | fix(analysis): detail_content 한국어 강제 |

---

## 8. 남은 후속 (follow-up)

1. **사이드바 X/트위터 필터 UI 누락** — 백엔드/분석은 완전 작동하나 `_sidebar.html.erb` nav(`전체/웹/YouTube/GitHub`)에 X 항목 없음. nav 배열에 twitter 추가 필요.
2. **기존 영어 detail_content 재분석** — 5.2 수정은 신규/재분석 항목부터 적용. 기존 영어 상세 항목은 일괄 재분석해야 한글화.
3. **X syndication token** — 현재 dummy token("a")이 200 반환. 엔드포인트 정책 변경 시 표준 토큰 산출 로직 필요(실패 시 Jina 폴백으로 graceful).
4. **`bin/deploy` PATH/서버 동기화** — 도구 커밋들은 Mac-local. 다음 코드 배포 시 서버로 자연 동기화됨.
