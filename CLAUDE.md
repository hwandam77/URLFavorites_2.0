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

## 모델 라우팅
- **Opus**: 분석/계획/아키텍처/사용자 대화
- **Sonnet**: 코드 구현/리팩토링/테스트
- **Haiku**: 파일 탐색/간단 조회

Opus는 설계/검증에 집중, 코드는 Sonnet에 위임.

---

## Multi-Agent Orchestration (Orca)

Hub & Spoke 원칙(Hub 직접 구현 금지, 탐색은 Hub·작성은 Spoke, 검토자≠구현자)과 Spoke 모델 라우팅(codex/grok/kimi/minimax)은 **workspace CLAUDE.md + `rules/15-hub-and-spoke.md`가 정본**. 여기엔 이 프로젝트의 델타만 적는다.

- 실행 기반: [Orca](https://github.com/stablyai/orca) ADE. 기존 claude-peers/tmux 기반 실행 구조는 이 프로젝트에서 폐기.
- Spoke 추가: `mimo (V2.5-Pro)` — 코드 구현 보조, 병렬 발주 시 추가 워커.
- 동급 코딩 태스크는 2개 에이전트 병렬 발주 → diff 비교 후 채택 (Orca 워크트리 격리가 이를 전제로 설계됨).
- 추가 금지: `Agent` 도구로 Claude 자체 서브에이전트 직접 스폰 (사용자 명시 요청 제외).

**핵심 플로우:**
1. `orca worktree create` — 에이전트별 격리 git 워크트리 생성
2. `orca terminal create` / `terminal send` — 워크트리에서 에이전트 CLI 기동·오더
3. `orca orchestration task-create` → `dispatch` — 태스크 발주
4. `orca orchestration check` / `inbox` — 결과 수신, `terminal wait` — 완료 대기
5. diff 리뷰(주석 → 에이전트 재발주) → 병합, `orca worktree rm` — 정리

명령 스키마 정본: `orca agent-context` (기계가독 스키마 출력)

---

## 하네스: Orca 기반 (GSD/tmux 대체)

기존 GSD phase lifecycle + tmux 2계층 구조는 폐기. 하네스 기능은 Orca 프리미티브로 대체한다.

| 하네스 요구 | Orca 대체 | 명령 |
|------------|-----------|------|
| 병렬 워커 실행 (구 tmux pane) | 워크트리별 에이전트 격리 실행 | `worktree create/ps`, `terminal create/send/read/wait` |
| Phase/태스크 관리 (구 GSD) | 태스크 생성·발주·상태 추적 + 코디네이터 루프 | `orchestration task-create/task-list/task-update/dispatch/run` |
| 검증 게이트 (구 verify-work) | 결정 게이트 — 승인 전 태스크 차단 | `orchestration gate-create/gate-resolve/gate-list` |
| 에이전트 간 보고/에스컬레이션 | 인터에이전트 메시지 (ask/reply 블로킹 지원) | `orchestration send/check/reply/inbox` |
| 정기 검증 (nightly E2E, 배포 후 체크) | 스케줄 자동화 | `automations create/run/runs` |
| UI/E2E 스모크 검증 | 내장 브라우저 자동화 + Design Mode | `tab create`, `goto`, `snapshot`, `click`, `fill` |
| 리뷰 루프 | diff 인라인 주석 → 에이전트 재발주 | Orca 앱 UI (diff annotate) |
| 관측성 (run 상태 요약) | 워크트리 오케스트레이션 대시보드 | `worktree ps`, `orchestration inbox` |

**운영 원칙:**
- 태스크 단위 = 워크트리 단위. 완료·병합 후 `worktree rm`으로 정리.
- Orca 게이트는 판정 결과를 승인하는 관문이지 판정 주체가 아니다. pass/fail 실행 위치는 workspace CLAUDE.md "검증 evidence 위치"를 따른다.
- 커스텀 에이전트 플레이북(`.claude/agents/rails-{core,ui,test,qa}.md`)은 역할 참고 문서로 유지 — Orca로 발주 시 태스크 명세에 해당 원칙을 포함시킨다.

---

## 배포 가이드

### 서버 정보

| 항목 | 값 |
|------|-----|
| SSH 호스트 | `bastion` (`~/.ssh/config`. **메인 주소 = LAN `192.168.0.11`**. WireGuard `10.10.0.1` / Tailscale `100.111.118.109`는 LAN 밖에서 들어올 때만 쓰는 대체 경로, 모두 같은 호스트) |
| 앱 경로 | `/home/hwandam/services/rails/urlfavorites_2.0/` |
| 서비스 | `rails-puma@urlfavorites_2.0.service` (Solid Queue는 `SOLID_QUEUE_IN_PUMA=1` 내장 단일 supervisor — 2026-07-24 `solid-queue@` 별도 서비스 stop+disable로 단일화. 이중 supervisor는 "배포 후 옛 코드 잡" 사고 클래스의 원인) |
| 포트 | `3003` (Puma loopback `127.0.0.1:3003`) |
| URL | `https://urlf.hwandam.kr/favorites` |
| nginx 설정 | `/etc/nginx/sites-enabled/URLF.hwandam.kr` (bastion 실측 미확정 — 변경 시 확인) |

> **이력 (2026-07-22 이관)**: `vps-server`(192.168.0.31, Tailscale `100.97.46.29`) → `bastion` 으로 이전. vps-server는 해체됨. **SSH/배포 대상은 반드시 `bastion`** (Tailscale에 vps-server가 offline 잔재로 남아 혼선 주의 — 2026-07-24 장애 진단 초기 혼선 원인). 이관 As-Built: `wiki/서버관리/VPS_server/리포트/서버-이전-완료-보고서-2026-07-22.md`.

운영 DB는 `/home/hwandam/services/rails/urlfavorites_2.0/storage/*.sqlite3*`에 있다. 특히
`storage/production.sqlite3`와 `storage/production_queue.sqlite3`는 삭제하거나 덮어쓰지 않는다.

### systemd 환경변수 (drop-in)

위치: `/etc/systemd/system/rails-puma@urlfavorites_2.0.service.d/env.conf`

```ini
[Service]
Environment=LLAMA_SERVER_URL=http://10.10.0.4:8282
Environment=PORT=3003
Environment=SOLID_QUEUE_IN_PUMA=1
Environment=EMBEDDING_URL=http://127.0.0.1:8900
# ⚠️ EMBEDDING_URL은 bastion 로컬 embedding-service(:8900). LLM 서버(8282)는 /v1/embeddings 미지원(501)
#    — 2026-07-24 이전 오설정이 큐 미소비 버그에 가려져 있었음
# LLM_BACKENDS: Nexus vllm Qwen3.6-27B (10.10.0.3:8000), single backend, timeout 240
# ⚠️ systemd Environment= 는 큰따옴표를 quoting 으로 해석해 벗겨낸다 → JSON 은 반드시 \" 로 이스케이프
Environment=LLM_BACKENDS=[{\"url\":\"http://10.10.0.3:8000\",\"model\":\"Qwen3.6-27B\",\"role\":\"default\",\"timeout\":240}]
```

**LLM 백엔드 (2026-08-12 변경):** Nexus 서버 `10.10.0.3:8000` — vllm 기반 `Qwen3.6-27B`(대소문자 구분), single backend. `max-num-seqs 4`로 동시성 처리. heavy/fast 분리 불필요(같은 GPU/프로세스).

**LLM_BACKENDS 이스케이프 함정 (2026-07-13 장애 원인):** `\"` 없이 평범한 `"` 로 넣으면 systemd 가 따옴표를 제거해 무효 JSON 이 되고, `resolve_backends` 가 `ParseError` 를 던져 **모든 분석이 실패**한다. 편집 후 `/proc/$(systemctl show ... -p MainPID --value)/environ` 로 실제 프로세스가 받는 값이 유효 JSON 인지 검증할 것. (드롭인 편집이 restart 전까지 dormant 라, 다음 restart 때 터진다.)

**timeout 240:** vllm Qwen3.6-27B에서는 256K 컨텍스트 prefill + 512 토큰 생성이 ~10초 내외로 처리되지만, 긴 유튜브 트랜스크립트 등을 여유 있게 처리하기 위해 240초 유지.

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
| youtube 분석만 `failed` (`yt-dlp failed` / `ExtractionError`) | **`yt-dlp` 바이너리 미설치 또는 구버전** (vps→bastion 이관 시 누락, 2026-07-24 장애). `extractor.rb`가 `Open3`로 yt-dlp를 외부 명령 호출 | `/usr/local/bin/yt-dlp --version` 확인 → 미설치 시 standalone 바이너리 설치 (systemd PATH에 `/usr/local/bin` 포함돼 Puma 재기동 불필요, ffmpeg 불필요). 재발 방지: 이관 체크리스트에 `Open3`/`system` 외부 바이너리 의존성 점검 추가 |
| youtube 분석만 `failed` (`Net::ReadTimeout`) | 긴 트랜스크립트 LLM 생성이 timeout 근접/초과 | `LLM_BACKENDS` timeout 확인 (현재 240초) |
| reddit 분석만 `failed` (`ExtractionError`) | **`rdt` CLI 미설치 또는 쿠키 만료(기본 7일)** — Reddit은 익명 API 전면 차단이라 로그인 쿠키 필수. yt-dlp와 같은 `Open3` 외부 바이너리 의존 클래스 | `rdt status --json` 으로 `authenticated` 확인 → 만료 시 Mac에서 `rdt login` 후 `~/.config/rdt-cli/credential.json` 재배치. 상세: `docs/runbooks/reddit-extraction.md` |
| reddit만 403/`authenticated: false` (쿠키·IP 정상인데) | **rdt가 Python 3.14로 구동** — 쿠키를 요청에 싣지 못함 (2026-07-24 실측: 같은 쿠키가 3.12에선 성공, 3.14에선 403) | `uv tool install --python 3.12 'git+…rdt-cli…@고정커밋'` 으로 3.12 고정 재설치 (bastion은 apt에 3.12 없어 uv 사용) + `/usr/local/bin/rdt` 심링크 |
| 모든 분석 `failed` (`ParseError: Invalid LLM_BACKENDS JSON`) | env.conf 의 `"` 미이스케이프 → systemd 가 따옴표 제거 | `\"` 로 이스케이프 후 `/proc/PID/environ` 로 유효 JSON 검증 |
| 배포했는데 잡이 옛 코드로 동작 (2026-07-13 발견) | 이전 재시작 때 죽지 않은 **고아 solid-queue 트리(PPID=1)**가 같은 큐 DB에서 잡을 선점 | `lsof storage/production_queue.sqlite3` 로 워커 트리 확인 → puma 기동 시각과 다른 supervisor `kill <PID>` |

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
