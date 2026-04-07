# URLFavorites AI 분석 게시판 — 설계 스펙

**날짜**: 2026-03-25
**상태**: 승인됨
**버전**: 1.1 (스펙 리뷰 반영)

---

## 1. 개요

개인용 URL 즐겨찾기 저장 및 AI 자동 분석 게시판.
저장된 URL(웹페이지 / YouTube 영상)을 로컬 LLM(Qwen3-30B-A3B)이 자동으로 요약·분류·인사이트 추출하여 리스트+상세 패널 형태로 제공한다.

### 레퍼런스 프로젝트

- **karakeep** (GitHub, 24k★) — AI 자동 태깅 + 셀프호스팅 북마크
- **Siftly** (GitHub, 2k★) — AI 분류 + 시각화 대시보드

---

## 2. 기술 스택

| 항목          | 선택                              | 비고                          |
| ------------- | --------------------------------- | ----------------------------- |
| 프레임워크    | Rails 8.1.2                       | Ruby 3.4.9                    |
| 데이터베이스  | SQLite3 (최신, 메인)              |                               |
| 잡 큐 DB      | SQLite3 (별도 `queue.sqlite3`)    | Solid Queue 기본값            |
| 백그라운드 잡 | Solid Queue                       | Rails 8 기본 내장             |
| 프론트엔드    | Hotwire (Turbo + Stimulus)        | ActionCable로 실시간 갱신     |
| AI 모델       | Qwen3-30B-A3B-Instruct-2507 (MoE) | beacon 서버 llama-server      |
| AI 연결       | HTTP (WireGuard VPN)              | `LLAMA_SERVER_URL` 환경변수   |
| 크롤링        | Nokogiri                          | 일반 웹페이지 본문 추출       |
| YouTube       | yt-dlp (자막 + 메타데이터 통합)   | `--write-sub` + `--dump-json` |
| 배포          | VPS_server                        | `deploy urlfavorites`         |

> **YouTube API 미사용**: `yt-dlp --dump-json`이 메타데이터(제목, 채널, 조회수, 길이, 게시일, 썸네일)를 모두 제공하므로 YouTube Data API v3 불필요.

---

## 3. 데이터 모델

### favorites

| 컬럼          | 타입     | 설명                                                  |
| ------------- | -------- | ----------------------------------------------------- |
| id            | integer  | PK                                                    |
| url           | string   | 원본 URL (unique 제약)                                |
| title         | string   | 페이지/영상 제목 (자동 추출)                          |
| favicon_url   | string   | 파비콘 URL (nullable)                                 |
| thumbnail_url | string   | YouTube 썸네일 (nullable)                             |
| content_type  | string   | `webpage` \| `youtube` (enum)                         |
| status        | string   | `pending` \| `analyzing` \| `done` \| `failed` (enum) |
| raw_content   | text     | 추출된 본문/자막 캐시 (재시도 시 재활용)              |
| error_message | text     | 실패 시 에러 메시지 (nullable)                        |
| retry_count   | integer  | 재시도 횟수 (기본값 0)                                |
| created_at    | datetime |                                                       |
| updated_at    | datetime |                                                       |

> **중복 URL**: `url` 컬럼에 unique 제약. 동일 URL 제출 시 기존 항목으로 안내.

### analyses

| 컬럼            | 타입        | 설명                                            |
| --------------- | ----------- | ----------------------------------------------- |
| id              | integer     | PK                                              |
| favorite_id     | integer     | FK → favorites (dependent: :destroy)            |
| summary         | text        | AI 요약 (2~5문장)                               |
| tags            | text (JSON) | 자동 분류 태그 배열                             |
| key_points      | text (JSON) | 핵심 포인트 배열 (YouTube: 타임스탬프 포함)     |
| sentiment       | string      | `positive` \| `neutral` \| `negative`           |
| transcript      | text        | YouTube 자막 원문 (nullable)                    |
| subtitle_source | string      | `manual` \| `auto` \| `description` (YouTube만) |
| video_metadata  | text (JSON) | 채널명, 조회수, 게시일, 길이 (YouTube만)        |
| model_used      | string      | 사용된 AI 모델명                                |
| analyzed_at     | datetime    |                                                 |

---

## 4. 화면 구조

### 메인 보드 (`/`)

```
┌─────────────────────────────────────────────────────────────┐
│  [URLFavorites]              [URL 입력창................] [저장] │
├─────────────────────────┬───────────────────────────────────┤
│  즐겨찾기 목록 (B형)      │  상세 분석 패널 (C형)              │
│                         │                                   │
│  ● GitHub - karakeep    │  📌 GitHub - karakeep             │
│    AI 자동 태깅과 전문    │     [원본 링크 열기]               │
│    검색을 지원하는...     │                                   │
│    [개발] [AI] [오픈소스] │  📝 요약                          │
│                         │     AI 자동 태깅과 전문 검색을...   │
│  ○ McKinsey AI 트렌드    │                                   │
│    분석 중...            │  🏷 태그                          │
│                         │     [개발] [AI] [오픈소스]         │
│  ○ Next.js 14 문서       │                                   │
│    Next.js App Router의  │  💡 핵심 인사이트                 │
│    기본 사용법을...       │     • 셀프호스팅 지원             │
│    [개발] [문서]          │     • AI 자동 태깅                │
│                         │     • 24k 스타 인기 프로젝트       │
│                         │                                   │
│                         │  🎭 감정: 긍정적                  │
│                         │  📅 저장: 2025-07-22              │
│                         │  🤖 Qwen3-30B-A3B                 │
└─────────────────────────┴───────────────────────────────────┘
```

### YouTube 항목 상세 패널

```
🎬 [YouTube 배지] 영상 제목
   [썸네일]  채널명 · 조회수 · 길이 · 게시일
   [자막 출처: 자동생성]  ← subtitle_source 표시

📝 요약 (자막 기반)
🏷 태그
💡 핵심 포인트 (타임스탬프 포함)
🎭 감정 분석
```

---

## 5. AI 분석 파이프라인

### 상태 머신

```
pending → analyzing → done
              ↓
           failed (retry_count < 3 → 자동 재시도)
           failed (retry_count >= 3 → UI에 재시도 버튼 표시)
```

- **자동 재시도**: Solid Queue 내장 재시도, 지수 백오프 (30s, 60s, 120s)
- **최대 재시도**: 3회. 이후 `failed` 확정, UI에 재시도 버튼 노출
- **수동 재시도**: 버튼 클릭 → `retry_count` 리셋 → `pending`으로 복귀
- **타임아웃**: 120초 → 자동 `failed` 처리 + `error_message` 기록
- **llama-server 다운 시**: `failed` + "AI 서버 연결 실패" 메시지. 서버 복구 후 수동 재시도 가능 (저장은 유지됨)

### 공통 흐름

```
URL 입력 (중복 체크 → 이미 있으면 기존 항목으로 이동)
  → favorite 레코드 생성 (status: pending)
  → URL 타입 감지 (YouTube 패턴 매칭: youtu.be, youtube.com/watch)
  → Solid Queue 잡 큐잉
  → [create 액션] Turbo Stream append: 목록 상단에 "분석 중..." 항목 즉시 추가
```

### 웹페이지 처리 (AnalyzeWebpageJob)

```
1. favorite.update(status: 'analyzing') → ActionCable broadcast
2. Nokogiri HTTP 요청 → title, og:title, og:description 추출
3. 본문 텍스트 추출 (article, main, p 태그 우선, 최대 8,000자 truncate)
4. favorite.update(raw_content: text) → 이후 재시도 시 재활용
5. 파비콘 URL 추출 (실패 시 nil 허용)
6. URL 검증: HTTP/HTTPS만 허용, 내부 IP 차단
7. Qwen3 HTTP POST → JSON 구조화 응답 (JSON 파싱 실패 시 재시도)
8. analyses 레코드 생성
9. favorite.update(status: 'done') → ActionCable broadcast
```

### YouTube 처리 (AnalyzeYoutubeJob)

```
1. favorite.update(status: 'analyzing') → ActionCable broadcast
2. yt-dlp --dump-json → 메타데이터 (제목, 채널, 조회수, 길이, 게시일, 썸네일)
3. 자막 추출 폴백 체인:
   ① yt-dlp --write-sub (수동 자막)         → subtitle_source: 'manual'
   ② yt-dlp --write-auto-sub (자동생성 자막) → subtitle_source: 'auto'
   ③ description + title 텍스트             → subtitle_source: 'description'
4. 자막/콘텐츠 최대 12,000자 truncate (MoE 컨텍스트 한계 고려)
5. favorite.update(raw_content: subtitle_text)
6. Qwen3 HTTP POST (자막 + 메타데이터) → JSON 구조화 응답
   (타임스탬프 기반 핵심 포인트 포함)
7. analyses 레코드 생성 (subtitle_source 포함)
8. favorite.update(status: 'done') → ActionCable broadcast
```

### Turbo Stream + ActionCable 구현

```ruby
# 잡에서 브로드캐스트
Turbo::StreamsChannel.broadcast_replace_to(
  "favorites",
  target: "favorite_#{favorite.id}",
  partial: "favorites/favorite",
  locals: { favorite: favorite }
)

Turbo::StreamsChannel.broadcast_replace_to(
  "favorites",
  target: "analysis_panel",
  partial: "favorites/analysis_panel",
  locals: { favorite: favorite }
)

# 뷰에서 구독
<%= turbo_stream_from "favorites" %>

# DOM 타겟 ID 규칙
- 목록 항목:  id="favorite_<%= favorite.id %>"
- 상세 패널: id="analysis_panel"
- 사이드 패널 컨테이너: turbo_frame_tag "analysis_panel"
```

**동시 요청 제한**: llama-server 동시 요청 최대 2개 (Solid Queue concurrency 설정). 이 이상 요청 시 큐에서 대기.

### Qwen3 프롬프트 구조 (JSON 출력 강제)

```json
{
  "summary": "2~5문장 요약",
  "tags": ["태그1", "태그2", "태그3"],
  "key_points": [{ "point": "핵심 내용", "timestamp": "00:05:30" }],
  "sentiment": "positive|neutral|negative"
}
```

JSON 파싱 실패 시: `error_message` 기록 후 Solid Queue 자동 재시도.

### llama-server 연동

- 엔드포인트: `LLAMA_SERVER_URL` 환경변수 (beacon WireGuard IP)
- WireGuard VPN 연결 필수 (VPS_server ↔ beacon)
- 모델: Qwen3-30B-A3B-Instruct-2507 (MoE)
- 타임아웃: 120초
- Content-Type: `application/json`

---

## 6. 모바일 PWA + Web Share Target

스마트폰에서 브라우저의 "공유" 메뉴로 바로 URL 등록 가능.

### PWA 구성 (`/public/manifest.json`)

```json
{
  "name": "URLFavorites",
  "short_name": "URLFav",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#1d4ed8",
  "share_target": {
    "action": "/favorites",
    "method": "POST",
    "enctype": "application/x-www-form-urlencoded",
    "params": {
      "title": "title",
      "url": "url"
    }
  },
  "icons": [...]
}
```

- Service Worker: 오프라인 기본 화면 제공
- 홈 화면 추가(A2HS) 지원
- `FavoritesController#create`가 Web Share Target 요청도 동일하게 처리

---

## 7. REST API (외부 AI 접근용)

다른 AI 도구(Claude Desktop, Cursor, GPT 등)가 HTTP로 분석 데이터를 조회·등록할 수 있는 범용 API.

### 엔드포인트

| Method   | Path                              | 설명                                |
| -------- | --------------------------------- | ----------------------------------- |
| `GET`    | `/api/v1/favorites`               | 목록 (페이지네이션, 태그/상태 필터) |
| `GET`    | `/api/v1/favorites/:id`           | 단일 항목 + 분석 결과               |
| `POST`   | `/api/v1/favorites`               | 새 URL 등록                         |
| `DELETE` | `/api/v1/favorites/:id`           | 삭제                                |
| `GET`    | `/api/v1/favorites/search?q=`     | 키워드/태그 검색                    |
| `GET`    | `/api/v1/favorites/recent?limit=` | 최근 분석 완료 항목                 |

### 응답 형식

```json
{
  "id": 1,
  "url": "https://example.com",
  "title": "페이지 제목",
  "content_type": "webpage",
  "status": "done",
  "created_at": "2026-03-25T10:00:00Z",
  "analysis": {
    "summary": "요약 내용...",
    "tags": ["개발", "AI"],
    "key_points": [{ "point": "핵심 내용" }],
    "sentiment": "positive",
    "analyzed_at": "2026-03-25T10:01:30Z",
    "model_used": "Qwen3-30B-A3B"
  }
}
```

### 인증

- Phase 1: VPN/내부망 접근 전제, 인증 없음
- Phase 2: Bearer 토큰 (`Authorization: Bearer <token>`)

### AI 활용 예시 (외부 AI 프롬프트)

```
GET /api/v1/favorites/search?q=AI&limit=5
→ AI가 최근 저장한 AI 관련 URL의 요약과 인사이트를 반환
```

---

## 8. 라우팅

```ruby
root 'favorites#index'
resources :favorites, only: [:index, :create, :show, :destroy] do
  member do
    post :retry  # 분석 재시도
  end
end

namespace :api do
  namespace :v1 do
    resources :favorites, only: [:index, :show, :create, :destroy] do
      collection do
        get :search
        get :recent
      end
    end
  end
end
```

---

## 7. 환경 변수

```bash
LLAMA_SERVER_URL=http://<beacon-wg-ip>:<port>  # beacon WireGuard IP
RAILS_ENV=production
SECRET_KEY_BASE=<generated>
RAILS_MASTER_KEY=<generated>
```

> **yt-dlp**: VPS_server에 시스템 패키지로 설치 필요 (`apt install yt-dlp` 또는 pip).

---

## 9. 환경 변수

```bash
LLAMA_SERVER_URL=http://<beacon-wg-ip>:<port>  # beacon WireGuard IP
RAILS_ENV=production
SECRET_KEY_BASE=<generated>
RAILS_MASTER_KEY=<generated>
```

> **yt-dlp**: VPS_server에 시스템 패키지로 설치 필요 (`apt install yt-dlp` 또는 pip).

---

## 10. 구현 단계

### Phase 0 — 프로젝트 클린업 (우선)

- [ ] 기존 Next.js 삭제 파일들 커밋 (`chore: remove Next.js files`)
- [ ] 깨끗한 git 상태 확인

### Phase 1 — 웹앱 핵심 기능

- [ ] Rails 프로젝트 초기화 (SQLite, Solid Queue, Hotwire, ActionCable)
- [ ] favorites / analyses 모델 + 마이그레이션
- [ ] URL 입력 + 타입 감지 + 중복 체크 로직
- [ ] AnalyzeWebpageJob (Nokogiri + Qwen3 연동, 재시도 전략 포함)
- [ ] AnalyzeYoutubeJob (yt-dlp + Qwen3 연동, 자막 폴백 체인 포함)
- [ ] 메인 보드 UI (B+C: 리스트 + 사이드 패널, Turbo Frame + ActionCable)
- [ ] Turbo Stream 실시간 갱신 (ActionCable 브로드캐스트)
- [ ] PWA 설정 (manifest.json, service worker, Web Share Target)
- [ ] REST API `/api/v1/` (search, recent, CRUD)
- [ ] VPS 배포 설정 (yt-dlp 설치, env 설정, Puma systemd)

### Phase 2 — 브라우저 확장

- [ ] Chrome/Firefox Manifest V3 확장
- [ ] 확장에서 현재 탭 URL → `/api/v1/favorites` 전송
- [ ] Bearer 토큰 인증 추가

---

## 11. 비기능 요구사항

- 개인용 단일 사용자 (VPN/내부망 접근, 별도 인증 불필요 — Phase 1)
- AI 분석 비동기 처리 (UI 블로킹 없음)
- llama-server 다운 시 저장 유지 + 나중에 재시도 가능
- YouTube 자막 없는 영상도 대체 처리 (자동생성 → description)
- 동시 llama-server 요청 최대 2개로 제한
- REST API: 외부 AI가 HTTP로 분석 데이터 검색·조회·등록 가능
- PWA: 모바일 홈 화면 추가 + Web Share Target으로 공유 등록
