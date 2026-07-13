# URLFavorites v3.0 프로덕션 배포 계획

- 작성일: 2026-07-12
- 범위: **문서만** (코드/config 실제 변경·git 커밋·배포 실행은 이 문서 범위 밖)
- 관련 설계: `docs/plans/2026-07-12-urlf2-v3-design.md`
- 로컬 참고: `.env` (배포 대상 **아님**)
- 기존 체크리스트: `docs/deploy/urlf2-vps-checklist.md`, `docs/deploy/git-based-workflow.md`

---

## 1. 변경 요약

v3.0은 두 기능을 프로덕션에 올린다.

| 기능 | 코드 변경 요약 | 프로덕션에서 작동하려면 |
|------|----------------|------------------------|
| **Feature 1 — X(트위터) 분석** | `content_type=twitter`, `Twitter::Extractor`(Jina 직행 + 동영상 시 yt-dlp), `AnalyzeTwitterJob` | 코드 배포 + VPS에 `yt-dlp` 권장(미설치 시 동영상은 텍스트 fallback) + Jina Reader 외부 접근 가능 |
| **Feature 2 — 멀티 LLM 라우팅** | `BackendRouter`(heavy/fast role), `LLM_BACKENDS` role 정렬 + failover, `EMBEDDING_URL`로 임베딩 오프로드 | **systemd `env.conf`에 `LLM_BACKENDS` + `EMBEDDING_URL` 설정** (아래 2절) |

### 핵심 주의: `.env`는 배포되지 않는다

로컬 `.env`에 이미 2백엔드 JSON과 `EMBEDDING_URL`이 있어도, **Git 배포(`bin/deploy`)는 애플리케이션 소스만 동기화**한다. Rails 프로덕션 프로세스는 systemd drop-in 환경변수를 읽는다.

```text
로컬 .env  ──(배포 경로에 포함 안 됨)──✗──► VPS Rails 프로세스
env.conf   ──(daemon-reload + restart)──✓──► VPS Rails 프로세스
```

따라서 **코드만 배포하고 `env.conf`를 갱신하지 않으면**:

- 멀티 LLM 라우팅(beacon=fast / synapse=heavy)이 **프로덕션에서 활성화되지 않는다**.
- 기존 `LLAMA_SERVER_URL` 단일 백엔드(또는 이전 설정)로만 동작할 수 있다.
- 임베딩이 `EMBEDDING_URL` 없이 `LLAMA_SERVER_URL`(synapse/heavy)을 공유해 분석과 자원 경쟁할 수 있다.

**결론:** v3.0 프로덕션 활성화 = (1) v3 코드 커밋 배포 + (2) `env.conf` 갱신 후 서비스 재시작. 둘 중 하나만으로는 라우팅이 완전하지 않다.

### 서버 인벤토리 (라우팅 대상)

| 호스트 | WireGuard IP:port | 모델 | 역할 |
|--------|-------------------|------|------|
| **beacon** | `10.10.0.4:8282` | Qwen3.6-35B-A3B-Kimi-K2.6-Reasoning-Distilled.IQ4_XS (A3B MoE) | `fast` — 짧은 webpage, 임베딩 |
| **synapse** | `10.10.0.5:8282` | Qwen3.6-40B-Deck-Opus-NEO-CODE-HERE-2T-OT-IQ4_XS (dense) | `heavy` — 긴 youtube/twitter 동영상·detail |

두 서버 모두 llama-server `-np 1`, GPU 여유 작음 → **Solid Queue AI 동시성 max 2 유지** (상향 금지, 별도 용량 검증 전까지).

---

## 2. env.conf 정확한 변경문

### 경로

```text
/etc/systemd/system/rails-puma@urlfavorites_2.0.service.d/env.conf
```

### 목표 전체 내용

기존 3줄을 **유지**하고, `LLM_BACKENDS`·`EMBEDDING_URL` 2줄을 **추가**(또는 동일 키면 갱신)한다.

```ini
[Service]
Environment=LLAMA_SERVER_URL=http://10.10.0.5:8282
Environment=PORT=3003
Environment=SOLID_QUEUE_IN_PUMA=1
Environment=LLM_BACKENDS=[{"url":"http://10.10.0.5:8282","model":"Qwen3.6-40B-Deck-Opus-NEO-CODE-HERE-2T-OT-IQ4_XS.gguf","role":"heavy","timeout":120},{"url":"http://10.10.0.4:8282","model":"Qwen3.6-35B-A3B-Kimi-K2.6-Reasoning-Distilled.IQ4_XS.gguf","role":"fast","timeout":120}]
Environment=EMBEDDING_URL=http://10.10.0.4:8282
```

### 필드 의미

| 변수 | 값 | 비고 |
|------|-----|------|
| `LLAMA_SERVER_URL` | `http://10.10.0.5:8282` | **유지**. 폴백/레거시 단일 엔드포인트(synapse). |
| `PORT` | `3003` | **유지**. 미설정 시 3000 충돌. |
| `SOLID_QUEUE_IN_PUMA` | `1` | **유지**. |
| `LLM_BACKENDS` | 2백엔드 JSON | synapse=`heavy`, beacon=`fast`. 로컬 `.env`와 동일 스키마. |
| `EMBEDDING_URL` | `http://10.10.0.4:8282` | beacon(fast). 인덱싱이 heavy 분석과 분리됨. |

JSON 배열 순서 권고: heavy(synapse) 먼저, fast(beacon) 다음 — 로컬 `.env`와 일치. 실제 호출 순서는 `BackendRouter`가 role로 재정렬한다.

### 적용 명령 (실행은 배포 담당자가 VPS에서)

변경 전 반드시 백업:

```bash
sudo cp /etc/systemd/system/rails-puma@urlfavorites_2.0.service.d/env.conf \
  /etc/systemd/system/rails-puma@urlfavorites_2.0.service.d/env.conf.bak.$(date +%Y%m%d%H%M%S)
```

파일 편집 후:

```bash
sudo systemctl daemon-reload
sudo systemctl restart rails-puma@urlfavorites_2.0
```

### SSH / 원격 작업 원칙

- VPS 조작은 **mcp-ssh**(또는 프로젝트 표준 SSH 경로 `vps-server`)로 수행한다.
- **이 문서 작성 단계에서는 실행하지 않는다.** 실제 편집·reload·restart는 배포 실행 단계에서만.
- 앱 소스(`/home/hwandam/services/rails/urlfavorites_2.0/` 아래 `.rb`/뷰 등)는 VPS에서 직접 수정하지 않는다. `env.conf`만 인프라 설정으로 별도 관리.

### 적용 확인 (배포 담당)

```bash
# 프로세스 환경에 반영됐는지 (또는 journal/서비스 status)
systemctl show rails-puma@urlfavorites_2.0 -p Environment
# 또는 앱 내부에서 ENV 확인용 one-off (운영 정책에 맞게)
```

`LLM_BACKENDS`와 `EMBEDDING_URL`이 보이면 라우팅 설정 로드 준비 완료.

---

## 3. 배포 절차 (순서)

`env.conf` 갱신과 코드 배포는 **별개 단계**다. 둘 다 필요하다.

### 권장 순서

```text
[A] env.conf 백업 + 갱신 준비 (아직 restart 안 해도 됨)
        │
        ▼
[B] Mac: 커밋된 v3 브랜치 push
        │
        ▼
[C] bin/deploy-doctor pre
        │
        ▼
[D] bin/deploy urlfavorites_2.0          ← 코드·migrate·assets·restart
        │
        ▼
[E] env.conf 최종 반영 + daemon-reload + restart
        │   (D의 restart만으로는 예전 env면 라우팅 비활성)
        ▼
[F] bin/deploy-doctor post
        │
        ▼
[G] §5 스모크 테스트
```

#### 왜 env를 배포 전·후에 둘 다 언급하나

| 시점 | 장점 | 단점 |
|------|------|------|
| **코드 배포 전**에 env 갱신+restart | 새 코드가 올라오는 순간부터 라우팅 env 사용 | 구코드가 multi-backend JSON을 아직 기대하지 않으면 무시되거나 무해한 미사용 env만 존재 |
| **코드 배포 후**에 env 갱신+restart | v3 코드가 확실히 로드된 뒤 라우팅 활성화 | 배포 직후~env 적용 전 창에서 단일 백엔드로 잠깐 동작 |

**권고:**

1. 배포 직전 `env.conf` 파일을 **백업하고 내용 작성**까지 해 둔다.
2. `bin/deploy urlfavorites_2.0`으로 코드 배포.
3. **즉시** `env.conf`를 목표 내용으로 맞춘 뒤 `daemon-reload` + `restart` (배포 스크립트가 이미 restart 했어도 env 변경 반영을 위해 **한 번 더** 필요).
4. `bin/deploy-doctor post` 및 스모크.

빠른 코드만 올릴 때(`bin/deploy --quick`)도 동일: **env 변경은 deploy 스크립트가 하지 않으므로 수동 단계 필수**.

### 단계별 명령 (Mac / VPS)

#### B–D. 코드 배포 (Mac)

```bash
# 1) 원격에 배포 가능 커밋이 있는지 확인 후 push (다른 워커/담당자)
git push

# 2) pre-check
bin/deploy-doctor pre

# 3) 전체 배포 (bundle + migrate + assets + restart, ~30초)
bin/deploy urlfavorites_2.0

# UI-only 후속이면 --quick 가능하나, v3.0 첫 반영은 전체 배포 권장
# bin/deploy --quick urlfavorites_2.0
```

#### E. env.conf (VPS, mcp-ssh)

```bash
# 백업 → 파일 편집(§2 목표 내용) →
sudo systemctl daemon-reload
sudo systemctl restart rails-puma@urlfavorites_2.0
```

#### F. post-check (Mac)

```bash
bin/deploy-doctor post
```

### 배포 전 사전 조건 체크리스트

- [ ] 로컬 배포 가능 소스가 커밋·upstream 동기화됨 (`deploy-doctor pre`가 검사)
- [ ] VPS worktree clean (소스 drift 없음). 필요 변경은 Mac 브랜치로 회수 후 커밋
- [ ] `storage/production.sqlite3`, `storage/production_queue.sqlite3` 존재·백업 정책 확인 — **절대 삭제/덮어쓰기 금지**
- [ ] WireGuard로 VPS → `10.10.0.4:8282`, `10.10.0.5:8282` 도달 가능
- [ ] (권장) VPS에 `yt-dlp` 설치: `which yt-dlp`

---

## 4. 롤백 계획

### 4.1 코드 롤백

1. 직전 정상 커밋 해시 확인 (배포 직전 `git rev-parse HEAD` 또는 VPS `git log -1`).
2. Mac에서 해당 커밋을 다시 배포 가능하게 맞춘 뒤:

   ```bash
   # 예: 이전 태그/커밋으로 체크아웃한 브랜치를 push 후
   bin/deploy-doctor pre
   bin/deploy urlfavorites_2.0   # 또는 정책에 맞는 롤백 배포 경로
   bin/deploy-doctor post
   ```

3. VPS 앱 소스를 손으로 되돌리지 않는다. **Git 커밋 단위 배포**가 정본.

### 4.2 env.conf 롤백

```bash
# 백업 파일이 있는 경우
sudo cp /etc/systemd/system/rails-puma@urlfavorites_2.0.service.d/env.conf.bak.<timestamp> \
  /etc/systemd/system/rails-puma@urlfavorites_2.0.service.d/env.conf

# v3 이전 최소 설정으로 수동 복구 시:
# [Service]
# Environment=LLAMA_SERVER_URL=http://10.10.0.5:8282
# Environment=PORT=3003
# Environment=SOLID_QUEUE_IN_PUMA=1
# (LLM_BACKENDS / EMBEDDING_URL 제거 또는 주석 불가 — Environment= 라인 삭제)

sudo systemctl daemon-reload
sudo systemctl restart rails-puma@urlfavorites_2.0
```

### 4.3 운영 DB 불가침

다음 경로는 롤백·재배포·rsync·수동 정리 **어떤 경우에도 삭제·덮어쓰기 금지**:

```text
/home/hwandam/services/rails/urlfavorites_2.0/storage/*.sqlite3*
/home/hwandam/services/rails/urlfavorites_2.0/db/*.sqlite3*
```

특히:

- `storage/production.sqlite3`
- `storage/production_queue.sqlite3`

마이그레이션 롤백(`db:rollback`)은 **가역 마이그레이션 + DB 백업 확인 후에만**. 의심되면 코드만 되돌리고 스키마는 유지.

### 4.4 부분 롤백 시나리오

| 증상 | 조치 |
|------|------|
| X 분석만 문제, 라우팅은 정상 | 코드 롤백 검토; env는 유지해도 무방한 경우가 많음 |
| 라우팅/LLM 오류, UI는 정상 | `env.conf`를 단일 `LLAMA_SERVER_URL`만으로 복구 후 restart (코드는 유지 가능) |
| 서비스 기동 실패 | `journalctl -u rails-puma@urlfavorites_2.0 -n 50`; env JSON 따옴표/문법 먼저 의심 |

---

## 5. 배포 후 스모크 테스트 체크리스트

VPS 또는 mcp-ssh 세션에서 수행. (이 문서 작성 시 실행하지 않음.)

### (a) 서비스 상태

```bash
systemctl status rails-puma@urlfavorites_2.0
```

- [ ] `active (running)`
- [ ] 최근 로그에 부팅 직후 fatal 없음

### (b) 로컬 헬스체크

```bash
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3003/favorites
```

- [ ] `200`
- [ ] (선택) 공개: `curl -s -o /dev/null -w "%{http_code}" https://urlf.hwandam.jp/favorites` → `200`

### (c) X(트위터) URL 분석

1. UI 또는 API로 X 트윗 URL 1개 추가.
2. 상태 전이 확인: **`pending` → `analyzing` → `done`** (실패 시 `failed` + 수동 재시도 노출).
3. 추출 경로:
   - [ ] `Twitter::Extractor` / Jina Reader 경유 (평문 GET 아님).
   - [ ] 분석 결과(summary/tags 등)가 패널에 표시.
4. 로그 힌트 (예):

   ```bash
   journalctl -u rails-puma@urlfavorites_2.0 -n 80 --no-pager | grep -iE 'twitter|jina|AnalyzeTwitter'
   ```

### (d) 멀티 LLM 라우팅 확인

| 시나리오 | 기대 role | 검증 방법 |
|----------|-----------|-----------|
| 긴 콘텐츠 (YouTube 자막 / 동영상 트윗 transcript 등) | **heavy** → synapse `10.10.0.5` | `analyses.model_used`가 heavy 모델명(`Qwen3.6-40B-...`)이거나, 로그/llama 측 요청이 synapse로 |
| 짧은 webpage | **fast** → beacon `10.10.0.4` | `model_used`가 fast 모델명(`Qwen3.6-35B-A3B-...`) 또는 beacon 요청 |
| 임베딩/인덱싱 | **beacon** (`EMBEDDING_URL`) | 인덱싱 중 synapse GPU 부하가 불필요하게 같이 안 오르는지 관찰 |

검증 예 (Rails console on VPS, 운영 정책에 맞게):

```ruby
# 최근 분석의 model_used
Analysis.order(created_at: :desc).limit(5).pluck(:id, :model_used, :created_at)
```

- [ ] 긴 영상/트윗 동영상 → heavy 모델
- [ ] 짧은 웹페이지 → fast 모델
- [ ] heavy 실패 시 fast로 failover (의도적 장애 주입은 선택; 평소에는 로그에 순차 시도 흔적)

### (e) yt-dlp 서버 설치

```bash
which yt-dlp
yt-dlp --version
```

| 결과 | 영향 |
|------|------|
| 설치됨 | 동영상 트윗 메타데이터·자막 추출 가능 |
| **미설치** | 동영상 트윗은 **Jina 텍스트 fallback**으로 분석 계속 (기능 전체 실패는 아님). YouTube 경로도 영향. README/체크리스트상 VPS 설치 권장. |

- [ ] 설치 여부 확인
- [ ] 미설치 시: 텍스트 트윗 스모크는 통과하는지 확인 후, 필요하면 `yt-dlp` 설치를 후속 작업으로 기록

### 추가 빠른 확인 (권장)

- [ ] 기존 YouTube URL 재분석 또는 신규 1건 → done
- [ ] 검색/최근 목록 정상
- [ ] `journalctl -u rails-puma@urlfavorites_2.0 -n 30 --no-pager` 에 `LLAMA_SERVER_URL is required` 없음

---

## 6. 리스크 / 주의

| 리스크 | 설명 | 완화 |
|--------|------|------|
| **WireGuard VPN 의존** | beacon·synapse 모두 `10.10.0.x` 사설망. VPN 끊기면 분석/임베딩 전면 실패 | 배포 전 VPS에서 양쪽 `:8282` health/`/v1/models` 확인; 장애 시 failover는 상대 서버가 살아 있을 때만 |
| **`-np 1` + 동시성 2** | 서버당 병렬 슬롯 1. Solid Queue AI concurrency **max 2 유지** (서버 2대여도 heavy 편중 시 OOM 가능) | 동시성 상향 금지(용량 재검증 전). OOM 시 동시성·배치 재검토 |
| **heavy 편중 지연** | 긴 youtube/twitter·detail이 synapse로 몰리면 큐 대기 증가 | 스모크에서 대기 시간 관찰; 필요 시 라우팅 임계값(문자 수) 추후 조정 |
| **env 미적용** | 코드만 배포 시 라우팅/임베딩 분리 비활성 | §2·§3 체크리스트 필수 |
| **Jina 의존 (X)** | X는 평문 GET 차단 → Jina Reader 필수 | Jina 장애 시 twitter 추출 실패 → Solid Queue 재시도/failed |
| **yt-dlp 미설치** | 동영상 트윗·YouTube 품질 저하 | 텍스트 fallback; VPS에 yt-dlp 설치 권장 |
| **env.conf JSON 문법** | 따옴표·이스케이프 오류 시 서비스/ENV 파싱 문제 | 백업 후 적용; `systemctl show`로 Environment 확인 |
| **운영 DB** | 잘못된 rsync/삭제 | `storage/*.sqlite3*` 절대 불가침 |

### 트러블슈팅 (기존 CLAUDE.md 표 + v3 보강)

| 증상 | 원인 | 해결 |
|------|------|------|
| `EADDRINUSE port 3000` | `PORT=3003` 누락 | drop-in에 `PORT=3003` |
| `LLAMA_SERVER_URL is required` | env.conf 없음/daemon-reload 누락 | drop-in 복구 후 reload+restart |
| 분석이 항상 한 서버만 사용 | `LLM_BACKENDS` 미설정 | §2 적용 후 restart |
| 임베딩이 느리고 heavy GPU 바쁨 | `EMBEDDING_URL` 미설정 | beacon URL 설정 |
| X URL이 webpage로 분류 | 구코드 배포 상태 | v3 코드 HEAD 배포 확인 |
| 동영상 트윗 자막 없음 | yt-dlp 없음/실패 | 설치 또는 텍스트 fallback 허용 |

---

## 7. 완료 정의 (이 문서 기준)

이 파일(`docs/deploy/urlf2-v3-deploy-plan.md`)이 작성되어 배포 담당자가 다음을 **실행 없이 읽고** 진행할 수 있으면 Task D 완료:

1. v3가 프로덕션에서 코드 배포만으로는 불충분하고 **`env.conf` 필수**임을 이해한다.
2. `env.conf` 목표 라인·적용 명령·mcp-ssh 원칙을 복사해 쓸 수 있다.
3. push → deploy-doctor pre → deploy → env 적용 → deploy-doctor post 순서를 따른다.
4. 롤백(코드 + env + DB 불가침)을 안다.
5. 스모크 (a)–(e)로 라우팅·X·yt-dlp를 검증한다.

**이 Task에서는 문서 생성만 수행한다. git add/commit, 실제 배포, VPS env 변경은 하지 않는다.**
