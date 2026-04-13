# URLFavorites 2.0 — CLAUDE.md

## 프로젝트 개요

개인용 URL 북마크 매니저 + AI 자동 분석. Rails 8 + SQLite + Solid Queue + Hotwire + Tailwind.

- 에이전트 지침 정본: `AGENTS.md`
- 설계 문서: `docs/plans/2026-04-07-urlf2-design.md`
- 구현 플랜: `docs/plans/2026-04-07-urlf2-implementation.md`

---

## 하네스: GSD + 커스텀 에이전트 통합

**목표:** GSD의 phase lifecycle 위에 도메인 특화 에이전트 + tmux 2계층 병렬 실행으로 10개 Phase를 완성한다.

### tmux 2계층 병렬 실행

```
Layer 1: Claude Workers (tmux pane별)
  Pane 1: Orchestrator (Opus) — GSD 명령, 조율
  Pane 2: rails-core (Sonnet) — 백엔드
  Pane 3: rails-ui (Sonnet) — 프론트
  Pane 4: rails-test (Sonnet) — TDD

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

**Claude 직접 처리 (dispatch 안 함):**
- 아키텍처 결정, 파일 간 통합 로직
- 디버깅 (로그 분석 → 원인 추론 → 수정)
- GSD 상태 관리, git 커밋, 검증 명령

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
| 앱 경로 | `/home/hwandam/URLFavorites_2.0/` |
| 서비스 | `rails-puma@URLFavorites_2.0.service` |
| 포트 | `3001` (3000은 구버전 urlfavorites 점유) |
| URL | `https://urlf.hwandam.kr/ver2.0/` |
| nginx 설정 | `/etc/nginx/sites-enabled/URLF.hwandam.kr` |

### systemd 환경변수 (drop-in)

위치: `/etc/systemd/system/rails-puma@URLFavorites_2.0.service.d/env.conf`

```ini
[Service]
Environment=LLAMA_SERVER_URL=http://100.99.181.122:8282
Environment=PORT=3001
Environment=RAILS_RELATIVE_URL_ROOT=/ver2.0
```

변경 시: `sudo systemctl daemon-reload && sudo systemctl restart rails-puma@URLFavorites_2.0`

### 배포 명령

```bash
# 전체 배포 (bundle + migrate + assets + restart, ~30초)
deploy URLFavorites_2.0

# 빠른 배포 (코드 sync + restart만, ~5초)
deploy --quick URLFavorites_2.0
```

### 배포 후 검증

```bash
# 서비스 상태
systemctl status rails-puma@URLFavorites_2.0

# 헬스체크
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3001/ver2.0/favorites
# → 200 이면 정상

# 최근 로그
journalctl -u rails-puma@URLFavorites_2.0 -n 30 --no-pager
```

### 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| `EADDRINUSE port 3000` | PORT env 미설정 → 기본값 3000 충돌 | drop-in에 `PORT=3001` 확인 |
| `LLAMA_SERVER_URL is required` | env.conf 미존재 또는 daemon-reload 누락 | drop-in 재생성 후 daemon-reload |
| 404 `/ver2.0/favorites` | `RAILS_RELATIVE_URL_ROOT` 미설정 | drop-in에 `/ver2.0` 확인 |
| 500 ERB syntax error | 뷰 파일 `link_to` 옵션 쉼표 누락 | 해당 파일 수정 후 quick deploy |

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
4. `bin/rails server` 로 시각 확인
5. `git add` + `git commit` (deploy 스크립트가 untracked/staged 파일 차단)
6. `deploy --quick URLFavorites_2.0` 로 배포
7. https://urlf.hwandam.kr/ver2.0/favorites 에서 확인

### 디자인 금지 패턴

- 템플릿 느낌의 균일한 카드 그리드
- 라이브러리 기본값을 그대로 사용
- 모든 요소에 동일한 radius/spacing/shadow
- 장식용 액센트 컬러 하나만 던지는 gray-on-white/dark
- inline style에 하드코딩 색상 (반드시 CSS 변수 사용)

### 변경 이력

| 날짜 | 변경 내용 | 대상 | 사유 |
|------|----------|------|------|
| 2026-04-07 | 초기 구성 — 4 에이전트 + 오케스트레이터 | 전체 | 하네스 신규 구축 |
| 2026-04-07 | GSD 통합 — .planning/ + ROADMAP 10 Phase | 전체 | GSD phase 관리 연결 |
| 2026-04-07 | tmux 2계층 병렬 — Claude Workers + Nexus LLM | 전체 에이전트 + 오케스트레이터 | Claude Workers + 30B/48B 코드 생성 조합 |
| 2026-04-10 | 배포 가이드 추가 — 서버 설정, 환경변수, 트러블슈팅 | CLAUDE.md | 첫 운영 배포 경험 문서화 |
| 2026-04-13 | Warm Archive 테마 전면 리디자인 | 전체 뷰 + 디자인 토큰 | Neo-Brutalist → Editorial Swiss |
