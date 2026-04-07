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
Layer 1: Claude Workers (omc-teams, tmux pane별)
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

### 변경 이력

| 날짜 | 변경 내용 | 대상 | 사유 |
|------|----------|------|------|
| 2026-04-07 | 초기 구성 — 4 에이전트 + 오케스트레이터 | 전체 | 하네스 신규 구축 |
| 2026-04-07 | GSD 통합 — .planning/ + ROADMAP 10 Phase | 전체 | GSD phase 관리 연결 |
| 2026-04-07 | tmux 2계층 병렬 — omc-teams + Nexus LLM | 전체 에이전트 + 오케스트레이터 | Claude Workers + 30B/48B 코드 생성 조합 |
