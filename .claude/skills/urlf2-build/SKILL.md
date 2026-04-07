---
name: urlf2-build
description: "URLFavorites 2.0 구현 오케스트레이터. GSD phase 관리 위에 커스텀 에이전트(rails-core/ui/test/qa)를 연결한다. 'urlf2 구현', 'urlf2 빌드', '태스크 실행', '다음 태스크', '재실행', '이어서', '부분 수정', 'urlf2 업데이트' 요청 시 반드시 이 스킬을 사용."
---

# URLFavorites 2.0 Build Orchestrator

GSD의 phase lifecycle 위에 도메인 특화 에이전트를 연결하여 Rails 8 앱을 구현한다.

## 아키텍처: GSD + 커스텀 에이전트 + tmux 2계층 병렬

```
Layer 1: Claude Workers (omc-teams, tmux pane별 독립 인스턴스)
  Pane 1: Orchestrator (Opus) — GSD 명령, 조율, 검증
  Pane 2: rails-core (Sonnet) — 백엔드 구현
  Pane 3: rails-ui (Sonnet) — 프론트엔드 구현
  Pane 4: rails-test (Sonnet) — TDD RED 단계

Layer 2: Nexus LLM (dispatch.sh, 태스크 단위 코드 생성)
  30B ×2 병렬: 단일 메서드, 테스트, 마이그레이션, 파티셜 (max 512 tok)
  48B 단일: 서비스 클래스, 복합 뷰, 리팩토링 (max 2048 tok)

GSD Phase 관리 (discuss → plan → execute → verify → ship)
       ↓
Claude 워커가 Phase별 에이전트 정의를 로드
       ↓
태스크 단위 코드 생성은 Nexus LLM에 위임 (dispatch.sh)
       ↓
Claude 워커가 결과 검증 + 파일 배치 + 테스트 실행
```

**tmux 상세:** `references/tmux-orchestration.md` 참조

## 커스텀 에이전트 (역할 플레이북)

| 에이전트 | 역할 | GSD 연결 |
|---------|------|----------|
| rails-test | TDD 테스트 선행 작성, 커버리지 80%+ | gsd-executor가 구현 전 Read하여 RED 단계 선행 |
| rails-core | 모델, 서비스, Job, 컨트롤러, 이관 | gsd-executor가 Read하여 구현 원칙 준수 |
| rails-ui | 뷰, Stimulus, Tailwind, PWA | gsd-executor가 UI Phase에서 Read |
| rails-qa | 경계면 교차 비교, 검색 품질, E2E | gsd-verifier가 Read하여 검증 체크리스트 적용 |

## GSD 워크플로우 연결

### 표준 실행 경로

```
/gsd:discuss-phase N   → Phase 컨텍스트 캡처
/gsd:plan-phase N      → PLAN.md 생성 (에이전트 정의 참조 지시 포함)
/gsd:execute-phase N   → gsd-executor가 에이전트 플레이북대로 실행
/gsd:verify-work N     → rails-qa 체크리스트 기반 UAT
/gsd:ship N            → PR 생성
```

### 빠른 실행 경로

```
/gsd:autonomous        → 전체 Phase 자동 반복
/gsd:next              → 다음 단계 자동 감지
```

## Phase → 에이전트 매핑 (ROADMAP.md 기준)

| Phase | 이름 | 에이전트 | TDD |
|-------|------|---------|-----|
| 01 | Rails Bootstrap + 문서 | rails-core | X |
| 02 | 코어 모델 + URL 서비스 | rails-test → rails-core | O |
| 03 | AI 추출 + 비동기 Job | rails-test → rails-core | O |
| 04 | FTS5 검색 엔진 | rails-test → rails-core | O |
| 05 | 컨트롤러 + 라우트 | rails-test → rails-core | O |
| 06 | 아카이브 UI + 메모 | rails-ui | X (system test) |
| 07 | 컬렉션 UX | rails-ui | X (system test) |
| 08 | PWA + 모바일 공유 | rails-ui | X |
| 09 | urlf 데이터 이관 | rails-test → rails-core | O |
| 10 | E2E 검증 + 릴리즈 | rails-qa | 검증 전용 |

## gsd-executor를 위한 PLAN.md 작성 가이드

`/gsd:plan-phase N` 실행 시, PLAN.md에 다음을 포함하라:

### TDD Phase (02-05, 09)

```markdown
## 구현 지침
1. `.claude/agents/rails-test.md`를 Read하여 TDD 원칙 숙지
2. 테스트를 먼저 작성 (RED) → `bin/rails test` 실패 확인
3. `.claude/agents/rails-core.md`를 Read하여 구현 원칙 숙지
4. 구현 (GREEN) → `bin/rails test` 통과 확인
5. 완료 후 `.claude/agents/rails-qa.md`의 경계면 체크리스트로 자체 검증
```

### UI Phase (06-08)

```markdown
## 구현 지침
1. `.claude/agents/rails-ui.md`를 Read하여 UI 원칙 숙지
2. 모바일 우선 레이아웃, Turbo Stream target ID 컨벤션 준수
3. system test 통과 확인
```

### 검증 Phase (10)

```markdown
## 검증 지침
1. `.claude/agents/rails-qa.md`를 Read하여 전체 체크리스트 적용
2. `bin/rails test` + `bin/rails test:system` 전체 통과
3. 경계면 교차 비교, 검색 품질, 배포 준비 점검
4. VERIFICATION.md에 결과 기록
```

## Phase 병렬화

```
Phase 01 → Phase 02 → Phase 03 ─┐
                      Phase 04 ─┤ (병렬)
                      Phase 09 ─┘
                          ↓
                      Phase 05
                          ↓
                      Phase 06 ─┐
                      Phase 07 ─┤ (병렬)
                      Phase 08 ─┘
                          ↓
                      Phase 10
```

GSD의 `parallelization.enabled: true` 설정으로 Wave 그룹핑이 자동 적용된다.

## 커스텀 에이전트 단독 실행 (GSD 우회)

GSD 없이 커스텀 에이전트를 직접 서브에이전트로 호출할 수도 있다:

```
Agent(subagent_type: "rails-core", model: "sonnet", prompt: "Task 3 모델 구현...")
Agent(subagent_type: "rails-test", model: "sonnet", prompt: "Task 3 테스트 작성...")
```

이 경우 `.planning/` 상태 관리와 검증 루프는 적용되지 않는다.

## 참조 문서

| 문서 | 용도 |
|------|------|
| `.planning/PROJECT.md` | 프로젝트 비전, 제약, 결정 |
| `.planning/REQUIREMENTS.md` | 요구사항 (R01-R22) |
| `.planning/ROADMAP.md` | 10 Phase 로드맵 + 에이전트 매핑 |
| `.planning/STATE.md` | 세션 간 상태 추적 |
| `docs/plans/2026-04-07-urlf2-design.md` | 설계 문서 |
| `docs/plans/2026-04-07-urlf2-implementation.md` | 13개 태스크 상세 |
| `AGENTS.md` | 스키마, API, 코딩 규칙 |

## 테스트 시나리오

### 정상 흐름 (GSD 경유)
1. `/gsd:plan-phase 2` → PLAN.md 생성 (rails-test, rails-core 참조)
2. `/gsd:execute-phase 2` → gsd-executor가 TDD 사이클 실행
3. `/gsd:verify-work 2` → rails-qa 체크리스트 적용
4. `/gsd:ship 2` → 커밋 + PR

### 부분 재실행
1. "Phase 6 UI만 다시" → `/gsd:execute-phase 6`
2. gsd-executor가 rails-ui.md를 Read하여 재구현
3. `/gsd:verify-work 6` → system test 재검증

### 에러 흐름
1. Phase 3 실행 중 LlmAnalyzer 테스트 실패
2. gsd-executor가 1회 재시도 (에러 메시지 포함)
3. 재실패 시 `/gsd:debug`로 전환
