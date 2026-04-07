# tmux 오케스트레이션 가이드

URLFavorites 2.0 프로젝트의 tmux 기반 병렬 실행 전략.

## 아키텍처: 2계층 병렬 실행

```
┌─────────────────────────────────────────────────────────┐
│ Layer 1: Claude Workers (omc-teams, Phase 단위)         │
│                                                         │
│  Pane 1: Orchestrator (Opus)                            │
│  Pane 2: rails-core worker (Sonnet)                     │
│  Pane 3: rails-ui worker (Sonnet)                       │
│  Pane 4: rails-test worker (Sonnet)                     │
│                                                         │
│ Layer 2: Nexus LLM (dispatch.sh, Task 단위 코드 생성)   │
│                                                         │
│  Slot A: Qwen 30B (port 8081) — 메서드/테스트 1개씩     │
│  Slot B: Qwen 30B (port 8081) — 병렬 2슬롯             │
│  Slot C: Qwen 48B (port 8082) — 복잡한 서비스 클래스    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Layer 1: Claude Workers (omc-teams)

### 세션 시작

```bash
# omc-teams로 tmux 세션 구성
# Pane 1: orchestrator (메인 Claude)
# Pane 2-4: 역할별 Claude Sonnet 워커
```

### 워커 역할 배정

| Pane | 워커 | 에이전트 정의 | 담당 Phase |
|------|------|-------------|-----------|
| 1 | orchestrator | (메인) | GSD 명령, 조율, 검증 |
| 2 | rails-core | `.claude/agents/rails-core.md` | 02-05, 09 |
| 3 | rails-ui | `.claude/agents/rails-ui.md` | 06-08 |
| 4 | rails-test | `.claude/agents/rails-test.md` | 02-05 (TDD RED) |

### 병렬 실행 패턴

**순차 Phase (01, 02, 05, 09, 10):**
```
Pane 4 (rails-test): 테스트 작성 → 완료 신호
Pane 2 (rails-core): 구현 → 완료 신호
Pane 1 (orchestrator): 검증
```

**병렬 Phase (03+04, 06+07+08):**
```
Pane 2 (rails-core): Phase 03 실행
Pane 4 (rails-test): Phase 04 테스트 작성 (동시)
--- 또는 ---
Pane 3 (rails-ui): Phase 06 + 07 + 08 (순차)
Pane 2 (rails-core): Phase 09 (동시)
```

## Layer 2: Nexus LLM (dispatch.sh)

### 태스크 라우팅 기준

| 태스크 유형 | 모델 | max_tokens | 예시 |
|------------|------|-----------|------|
| 단일 메서드/함수 | 30B ×2 병렬 | 512 | `UrlNormalizer.call`, `valid_url?` |
| 단일 테스트 파일 | 30B ×2 병렬 | 512 | `url_normalizer_test.rb` |
| 서비스 클래스 전체 | 48B 단일 | 2048 | `WebpageScraper`, `LlmAnalyzer` |
| 마이그레이션 | 30B | 512 | `create_favorites` |
| 뷰 파티셜 | 30B | 512 | `_favorite_card.html.erb` |
| Stimulus 컨트롤러 | 30B | 512 | `view_mode_controller.js` |
| 복잡한 뷰 레이아웃 | 48B | 2048 | `index.html.erb` (검색+필터+카드) |

### dispatch.sh 사용 패턴

```bash
ORCH="infrastructure/llm-orchestration/dispatch.sh"

# 30B 병렬: 간단한 메서드 2개 동시 생성
$ORCH --model 30b --prompt "Write Ruby module UrlNormalizer with .call(raw_url) method. Strips fragments, downcases host, removes trailing slash. Returns normalized URL string." --project urlfavorites --lang ruby &
$ORCH --model 30b --prompt "Write Ruby module UrlTypeDetector with .call(url) method. Returns 'youtube' for youtube.com/youtu.be URLs, 'webpage' for all others." --project urlfavorites --lang ruby &
wait

# 48B 단일: 복잡한 서비스 클래스
$ORCH --model 48b --prompt-file tasks/webpage_scraper_spec.txt --project urlfavorites --lang ruby
```

### Claude 워커 ↔ Nexus LLM 연결

Claude 워커가 Nexus LLM에 코드 생성을 위임하는 흐름:

```
1. Claude 워커가 태스크 분석 → 프롬프트 작성
2. dispatch.sh로 Nexus LLM 호출
3. 출력 검증 (validate.sh 자동)
4. 실패 시 자동 재시도 (circuit breaker 포함)
5. 성공 시 Claude 워커가 Write/Edit로 파일 배치
6. bin/rails test로 검증
```

## 모델 상태 확인

```bash
infrastructure/llm-orchestration/status.sh
```

서킷 브레이커 상태:
```bash
infrastructure/llm-orchestration/circuit.sh status
```

## Phase별 tmux 실행 계획

### Phase 01: Bootstrap (순차)
```
Pane 2 (rails-core): rails new + bundle install + git init
→ 30B로 Gemfile 수정, .ruby-version 생성 병렬
→ 48B로 README.md 전체 생성
```

### Phase 02-04: 코어 구현 (TDD 파이프라인 + 병렬)
```
Pane 4 (rails-test):
  → 30B ×2: test 파일 병렬 생성 (모델 테스트 2개씩)
  → 실패 확인

Pane 2 (rails-core):
  → 30B ×2: 마이그레이션 + 모델 병렬 생성
  → 48B: 복잡한 서비스 (WebpageScraper, LlmAnalyzer)
  → 테스트 통과 확인

Phase 03과 04는 Pane 2와 Pane 4에서 동시 실행 가능
```

### Phase 05-08: 웹 계층 (팬아웃)
```
Pane 2 (rails-core): Phase 05 컨트롤러
  → 30B ×2: 컨트롤러 액션 병렬 생성

Pane 3 (rails-ui): Phase 06-08 UI (동시 시작)
  → 30B ×2: 뷰 파티셜 병렬 생성
  → 48B: index.html.erb (검색+필터 복합 뷰)
  → 30B: Stimulus 컨트롤러, manifest.json 병렬

Pane 4 (rails-test): system test 작성 (동시)
```

### Phase 09: 이관 (순차)
```
Pane 2 (rails-core):
  → 48B: UrlfSnapshotImporter (복잡한 로직)
  → 30B: rake task
```

### Phase 10: 검증 (순차)
```
Pane 1 (orchestrator): 전체 테스트 + QA 리포트
```

## 세션 모니터링

tmux 세션 시작 후:
```bash
infrastructure/llm-orchestration/session.sh start urlfavorites /Users/hwandam/workspace/URLFavorites_2.0
```

5 pane 레이아웃:
```
┌───────────────┬───────────────┐
│               │ 30B Slot A    │
│  Claude Main  ├───────────────┤
│               │ 30B Slot B    │
├───────────────┼───────────────┤
│  48B Slot     │   Results     │
└───────────────┴───────────────┘
```
