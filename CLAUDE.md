# URLFavorites 2.0 — CLAUDE.md

## 프로젝트 개요

개인용 URL 북마크 매니저 + AI 자동 분석. Rails 8 + SQLite + Solid Queue + Hotwire + Tailwind.

- 에이전트 지침 정본: `AGENTS.md`
- 설계 문서: `docs/plans/2026-04-07-urlf2-design.md`
- 구현 플랜: `docs/plans/2026-04-07-urlf2-implementation.md`
- **DDD 아키텍처 스펙**: `docs/superpowers/specs/2026-04-15-ddd-refactor-architecture-design.md`

### DDD 아키텍처 개발 원칙 (MANDATORY)

신규 코드 작성 시 DDD 아키텍처 스펙을 준수한다. 기존 `app/services/` 패턴은 사용하지 않는다.

- **코드 배치**: `app/url_favorites/{domain,integrations,use_cases}/` 레이어에 맞게 배치
- **의존성 방향**: `Controller/Job → UseCase → Domain + Integrations` (Domain은 어디에도 의존하지 않음)
- **컨트롤러/잡**: UseCase 하나만 호출, 비즈니스 로직 금지
- **외부 의존성**: Integrations 레이어로 격리 (LLM, 스크래핑, 임베딩 등)
- **네이밍**: `UrlFavorites::` 루트 네임스페이스, Zeitwerk 규칙 준수
- **새 서비스 생성 전**: 스펙 §4(디렉토리), §8(매핑 가이드) 확인 필수

---

## Rules 우선순위
`Rules.md > CLAUDE.md > ~/.claude/CLAUDE.md`

---

## 모델 라우팅
- **Opus**: 분석/계획/아키텍처/사용자 대화
- **Sonnet**: 코드 구현/리팩토링/테스트
- **Haiku**: 파일 탐색/간단 조회

Opus는 설계/검증에 집중, 코드는 Sonnet에 위임.

---

## Multi-Agent Orchestration (Hub & Spoke)

**역할 구조:**
```
Main Claude (Hub, Opus) — 계획·분해·위임·검증만. 직접 구현 금지.
  ├── KIMI peer (K2.6) — 한국어/영문 코드 구현·리팩터링·테스트·문서
  ├── minimax peer (M2.7) — 영문 작업·시스템·인프라 (※ 한글 깨짐 — 한국어 발주 금지)
  ├── Sonnet sub-agent — backend/frontend/api/test specialist
  └── Haiku sub-agent — architecture/impact/dependency/docs analyst
```

**위임 라우팅:**
- 한국어 코드·주석·문서 → KIMI peer 또는 Sonnet sub-agent
- 영문 코드 구현·리팩터링 → KIMI peer 또는 minimax peer
- 시스템·인프라·MLOps → minimax peer
- FastAPI/React/DB 도메인 → Sonnet sub-agent
- 아키텍처 설계만 (코드 X) → Hub 자체 처리

**금지:** `Agent` 도구로 Claude 자체 서브에이전트 직접 스폰 (사용자 명시 요청 제외)

---

## 하네스: GSD + 커스텀 에이전트 통합

**목표:** GSD의 phase lifecycle 위에 도메인 특화 에이전트 + tmux 2계층 병렬 실행으로 10개 Phase를 완성한다.

> 이 프로젝트의 커스텀 에이전트 구조는 워크스페이스 전역 Hub & Spoke 규칙(`.claude/rules/15-hub-and-spoke.md`) 내에서 운영된다.
> 워크스페이스 룰과 충돌 시 워크스페이스 룰이 우선한다.

### tmux 2계층 병렬 실행

```
Layer 1: Claude Workers (tmux pane별) = Hub & Spoke
  Pane 1: Orchestrator (Opus) = Hub — 계획·분해·위임·검증
  Pane 2: rails-core (Sonnet) = Spoke — 백엔드
  Pane 3: rails-ui (Sonnet) = Spoke — 프론트
  Pane 4: rails-test (Sonnet) = Spoke — TDD

Layer 2: Nexus LLM (dispatch.sh, 태스크 단위)
  30B ×2: 단일 메서드/테스트/마이그레이션 (병렬)
  48B: 복잡한 서비스/복합 뷰 (단일)
```

상세: `.claude/skills/urlf2-build/references/tmux-orchestration.md`

### GSD 프로젝트 구조

```
.planning/
├── PROJECT.md          # 비전, 제약, 결정
├── REQUIREMENTS.md     # 요구사항 R01-R22
├── ROADMAP.md          # 10 Phase 로드맵 + 에이전트 매핑
├── STATE.md            # 세션 간 상태
├── config.json         # GSD 설정
└── phases/             # Phase별 산출물 (PLAN, SUMMARY, VERIFICATION)
```

### 커스텀 에이전트 (역할 플레이북)

| 에이전트 | 역할 | GSD 연결 |
|---------|------|----------|
| rails-core | 모델, 서비스, Job, 컨트롤러, 이관 | gsd-executor가 Read하여 구현 원칙 준수 |
| rails-ui | 뷰, Stimulus, Tailwind, PWA | gsd-executor가 UI Phase에서 Read |
| rails-test | TDD 테스트 선행 작성 | gsd-executor가 구현 전 RED 단계 선행 |
| rails-qa | 경계면 교차 비교, E2E 검증 | gsd-verifier가 Read하여 체크리스트 적용 |

### Nexus LLM 위임 규칙 (MANDATORY)

코드 생성 시 반드시 로컬 LLM(dispatch.sh)을 **먼저** 시도한다. Claude가 직접 코드를 작성하는 것은 dispatch 실패 시 에스컬레이션으로만 허용.

```bash
DISPATCH="/Users/hwandam/workspace/infrastructure/llm-orchestration/dispatch.sh"
```

**위임 대상 (dispatch.sh 필수):**
- 단일 메서드/함수 (< 50줄) → `$DISPATCH --model 30b --prompt "..." --project urlf2 --lang ruby`
- migration, factory, fixture → 30b
- 모델, 시리얼라이저, 라우트 boilerplate → 30b
- 테스트 스켈레톤 → 30b
- 서비스 클래스 전체 → `$DISPATCH --model 48b --prompt "..." --project urlf2 --lang ruby`
- 복잡한 리팩토링 → 48b

**Hub (Opus) 직접 처리 (dispatch 안 함):**
- 아키텍처 결정, 파일 간 통합 로직
- 디버깅 (로그 분석 → 원인 추론 → 수정)
- GSD 상태 관리, git 커밋, 검증 명령
- ※ Hub 코딩 절대 금지: 소스 코드 작성은 Sonnet sub-agent 또는 KIMI peer에게 위임

**호출 → 적용 패턴:**
1. `$DISPATCH --model 30b --prompt "영어 프롬프트" --project urlf2 --lang ruby` 실행
2. stdout에 출력된 result 파일 경로를 Read
3. 코드 블록 추출 → Write/Edit로 대상 파일에 적용
4. verify 명령으로 검증

**프롬프트 규칙:** 영어 전용, 입출력 스펙 명확, 30b는 100 tokens 이내, 48b는 300 tokens 이내.

**에스컬레이션:** dispatch 실패 → 프롬프트 개선 1회 재시도 → 재실패 시 Claude 직접 구현 + SUMMARY.md에 기록.

**서킷 확인:** 코드 생성 전 `/Users/hwandam/workspace/infrastructure/llm-orchestration/circuit.sh status` 로 모델 상태 확인. OPEN이면 해당 모델 건너뛰기.

### 실행 규칙

- **GSD 경유 (기본):** `/gsd:plan-phase N` → `/gsd:execute-phase N` → `/gsd:verify-work N`
- **자동 모드:** `/gsd:autonomous` 또는 `/gsd:next`
- **직접 호출 (GSD 우회):** `urlf2 구현/빌드/태스크 실행` → `urlf2-build` 스킬
- gsd-executor는 Phase에 따라 `.claude/agents/rails-{core,ui,test,qa}.md`를 Read하여 역할/원칙 준수
- 서브에이전트는 `model: "sonnet"` (워크스페이스 모델 라우팅 정책)

### Phase 로드맵 (v1.0)

| Phase | 이름 | 에이전트 | 상태 |
|-------|------|---------|------|
| 01 | Rails Bootstrap + 문서 | rails-core | pending |
| 02 | 코어 모델 + URL 서비스 | rails-test → rails-core | pending |
| 03 | AI 추출 + 비동기 Job | rails-test → rails-core | pending |
| 04 | FTS5 검색 엔진 | rails-test → rails-core | pending |
| 05 | 컨트롤러 + 라우트 | rails-test → rails-core | pending |
| 06 | 아카이브 UI + 메모 | rails-ui | pending |
| 07 | 컬렉션 UX | rails-ui | pending |
| 08 | PWA + 모바일 공유 | rails-ui | pending |
| 09 | urlf 데이터 이관 | rails-test → rails-core | pending |
| 10 | E2E 검증 + 릴리즈 | rails-qa | pending |

### 디렉토리 구조

```
.claude/
├── agents/
│   ├── rails-core.md
│   ├── rails-ui.md
│   ├── rails-test.md
│   └── rails-qa.md
└── skills/
    └── urlf2-build/
        └── SKILL.md         # GSD 브릿지 오케스트레이터
```

---

## 배포 가이드

### 서버 정보

| 항목 | 값 |
|------|-----|
| SSH 호스트 | `vps-server` (`~/.ssh/config`) |
| 앱 경로 | `/home/hwandam/services/rails/urlfavorites_2.0/` |
| 서비스 | `rails-puma@urlfavorites_2.0.service` |
| 포트 | `3003` (3000은 구버전 urlfavorites 점유) |
| URL | `https://urlf.hwandam.kr/favorites` |
| nginx 설정 | `/etc/nginx/sites-enabled/URLF.hwandam.kr` |

운영 DB는 `/home/hwandam/services/rails/urlfavorites_2.0/storage/*.sqlite3*`에 있다. 특히
`storage/production.sqlite3`와 `storage/production_queue.sqlite3`는 삭제하거나 덮어쓰지 않는다.

### systemd 환경변수 (drop-in)

위치: `/etc/systemd/system/rails-puma@urlfavorites_2.0.service.d/env.conf`

```ini
[Service]
Environment=LLAMA_SERVER_URL=http://10.10.0.4:8282
Environment=PORT=3003
Environment=SOLID_QUEUE_IN_PUMA=1
Environment=EMBEDDING_URL=http://10.10.0.4:8282
# LLM_BACKENDS: heavy(40B, 느림 ~13tok/s) + fast(35B-A3B, 빠름 ~62tok/s), 둘 다 timeout 240
# ⚠️ systemd Environment= 는 큰따옴표를 quoting 으로 해석해 벗겨낸다 → JSON 은 반드시 \" 로 이스케이프
Environment=LLM_BACKENDS=[{\"url\":\"http://10.10.0.5:8282\",\"model\":\"...heavy.gguf\",\"role\":\"heavy\",\"timeout\":240},{\"url\":\"http://10.10.0.4:8282\",\"model\":\"...fast.gguf\",\"role\":\"fast\",\"timeout\":240}]
```

**LLM_BACKENDS 이스케이프 함정 (2026-07-13 장애 원인):** `\"` 없이 평범한 `"` 로 넣으면 systemd 가 따옴표를 제거해 무효 JSON 이 되고, `resolve_backends` 가 `ParseError` 를 던져 **모든 분석이 실패**한다. 편집 후 `/proc/$(systemctl show ... -p MainPID --value)/environ` 로 실제 프로세스가 받는 값이 유효 JSON 인지 검증할 것. (드롭인 편집이 restart 전까지 dormant 라, 다음 restart 때 터진다.)

**timeout 240 인 이유:** youtube 등 긴 콘텐츠 분석은 heavy 백엔드에서 정상 생성만으로 ~110–150초가 걸려 기존 120초로는 경계에서 간헐 `Net::ReadTimeout` 실패가 났다.

변경 시: `sudo systemctl daemon-reload && sudo systemctl restart rails-puma@urlfavorites_2.0`

### 배포 명령

```bash
# 전체 배포 (bundle + migrate + assets + restart, ~30초)
bin/deploy urlfavorites_2.0

# 빠른 배포 (코드 sync + restart만, ~5초)
bin/deploy --quick urlfavorites_2.0
```

### 배포 운영 원칙

1. 서버 작업트리 정리
   - 서버의 미커밋 변경 중 필요한 것과 버릴 것을 분리한다.
   - 필요한 것은 Mac 로컬 브랜치에 반영한 뒤 커밋한다.
   - 다음 배포 전 서버는 clean worktree로 되돌린다.
   - `storage/*.sqlite3*`, `db/*.sqlite3*`는 삭제하거나 덮어쓰지 않는다.
2. 배포는 커밋 단위로만
   - `bin/deploy urlfavorites_2.0` 또는 `bin/deploy --quick urlfavorites_2.0`는 특정 커밋 상태를 서버에 반영해야 한다.
   - 서버에서 애플리케이션 소스 파일을 직접 수정하지 않는다.
   - 긴급 서버 수정이 필요했던 경우, 변경을 로컬 브랜치로 가져와 커밋한 뒤 정상 배포 경로로 다시 반영한다.
3. staging/prod 분리
   - 개인 앱이라도 최소한 staging 포트 하나를 별도로 둔다.
   - 목표 구조는 `3003`과 `3001`을 staging/prod로 분리하는 것이다. 트래픽 전환 전 어느 포트가 production인지 문서화한다.
   - nginx 경로는 `/staging` 또는 별도 staging 서브도메인으로 분리한다.
   - 현재 상태에서는 `3003`이 live production Puma 포트다.
   - `bin/deploy --environment staging urlfavorites_2.0`는 `URLF_STAGING_*` 대상 변수와 nginx 라우팅을 먼저 구성한 뒤 사용한다.
4. 장기 배포 방향
   - 현재 Rails + SQLite 구조에서는 기존 Git 기반 deploy 스크립트 개선이 비용 대비 효과가 가장 크다.
   - GitHub Actions 또는 Kamal은 장기 검토 대상으로 둔다.
   - Docker/Kamal은 환경 재현성을 높이지만 SQLite 파일, Solid Queue DB, persistent storage 관리 부담이 추가된다.

### 배포 후 검증

```bash
# 서비스 상태
systemctl status rails-puma@urlfavorites_2.0

# 헬스체크
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3003/favorites
# → 200 이면 정상

# 최근 로그
journalctl -u rails-puma@urlfavorites_2.0 -n 30 --no-pager
```

### 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| `EADDRINUSE port 3000` | PORT env 미설정 → 기본값 3000 충돌 | drop-in에 `PORT=3003` 확인 |
| `LLAMA_SERVER_URL is required` | env.conf 미존재 또는 daemon-reload 누락 | drop-in 재생성 후 daemon-reload |
| 404 `/ver2.0/favorites` | nginx redirect/proxy 규칙 변경 | 현재 Rails route는 `/favorites` |
| DB 파일 누락 | 운영 DB 삭제/동기화 사고 가능성 | 배포 중단 후 `storage/production.sqlite3` 백업/복구 확인 |
| 500 ERB syntax error | 뷰 파일 `link_to` 옵션 쉼표 누락 | 해당 파일 수정 후 quick deploy |
| youtube 분석만 `failed` (`Net::ReadTimeout`) | 긴 트랜스크립트 LLM 생성이 timeout 근접/초과 (heavy 40B 느림) | `LLM_BACKENDS` timeout 상향(240) / heavy·fast 라우팅 점검 |
| 모든 분석 `failed` (`ParseError: Invalid LLM_BACKENDS JSON`) | env.conf 의 `"` 미이스케이프 → systemd 가 따옴표 제거 | `\"` 로 이스케이프 후 `/proc/PID/environ` 로 유효 JSON 검증 |

---

## UI/디자인 시스템

### 현재 테마: Warm Archive (Editorial Swiss)

디자인 토큰은 `app/views/layouts/application.html.erb`의 `<style>` 블록에 정의.
Tailwind 유틸리티 + CSS 커스텀 프로퍼티 혼용. 모든 색상/스페이싱/타이포그래피는 토큰 경유.

### CSS 토큰 네이밍 규칙

```
색상:     --color-{역할}[-상태]          예: --color-accent, --color-accent-hover
서피스:   --color-surface[-레벨]         예: --color-surface, --color-surface-raised
상태:     --color-{status}-{prop}        예: --color-done-bg, --color-failed-text
타이포:   --text-{사이즈}                예: --text-xs, --text-base, --text-2xl
스페이스: --space-{N}                    예: --space-2, --space-4, --space-8
라운드:   --radius-{사이즈}              예: --radius-sm, --radius-md, --radius-full
```

### 다크/라이트 모드

- 다크 모드가 기본 (`:root`에 정의)
- 라이트 모드는 `.light` 클래스 오버라이드
- `theme_controller.js`가 `localStorage.theme` 기반으로 `html` 클래스 토글
- FOUC 방지: `<head>` 내 인라인 스크립트로 초기화

### 상태 색상 패턴

각 상태(pending/analyzing/done/failed)별로 bg/text/border 3종 세트:
```css
--color-pending-bg / --color-pending-text / --color-pending-border
--color-analyzing-bg / --color-analyzing-text / --color-analyzing-border
--color-done-bg / --color-done-text / --color-done-border
--color-failed-bg / --color-failed-text / --color-failed-border
```

뷰에서는 Hash 맵으로 매핑:
```erb
<% status_map = {
  "pending" => { bg: "var(--color-pending-bg)", text: "var(--color-pending-text)", ... },
  ...
} %>
```

### hover/focus 패턴

CSS 변수는 Tailwind `hover:` 프리픽스에서 직접 사용 불가하므로 인라인 `onmouseover`/`onmouseout` 사용:
```erb
onmouseover="this.style.borderColor='var(--color-accent-muted)'"
onmouseout="this.style.borderColor='var(--color-border)'"
```

### 뷰 파일 구조

| 파일 | 역할 |
|------|------|
| `layouts/application.html.erb` | 디자인 토큰 + 앱 셸 |
| `shared/_sidebar.html.erb` | 네비게이션 + 컬렉션 리스트 |
| `favorites/index.html.erb` | 메인: 헤더 + URL 추가 + 검색 + 필터 툴바 + 그리드 |
| `favorites/_favorite_card.html.erb` | 카드뷰 아이템 |
| `favorites/_favorite_row.html.erb` | 리스트뷰 행 |
| `favorites/_search_bar.html.erb` | 돋보기 검색 인풋 |
| `favorites/_filter_bar.html.erb` | index에 통합됨 (placeholder) |
| `favorites/show.html.erb` | 상세페이지 |
| `favorites/_empty_state.html.erb` | 빈 상태 |
| `collections/index.html.erb` | 컬렉션 목록 |
| `collections/show.html.erb` | 컬렉션 상세 |

### UI 변경 시 워크플로우

1. 로컬에서 뷰 파일 수정
2. `bin/rails tailwindcss:build` 로 CSS 빌드
3. `bin/rails assets:precompile` 로 에셋 검증
4. `git add` + `git commit` + `git push`
5. `bin/deploy-doctor pre`
6. `bin/deploy --quick urlfavorites_2.0` 로 배포
7. `bin/deploy-doctor post`
8. https://urlf.hwandam.kr/favorites 에서 시각 확인

### 디자인 금지 패턴

- 템플릿 느낌의 균일한 카드 그리드
- 라이브러리 기본값을 그대로 사용
- 모든 요소에 동일한 radius/spacing/shadow
- 장식용 액센트 컬러 하나만 던지는 gray-on-white/dark
- inline style에 하드코딩 색상 (반드시 CSS 변수 사용)

### 변경 이력

별도 관리: `docs/CHANGELOG.md`
