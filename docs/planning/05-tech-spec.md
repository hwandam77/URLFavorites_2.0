# 05 — 기술 사양

## 기술 스택

### 백엔드
| 항목 | 선택 | 버전/이유 |
|------|------|-----------|
| 프레임워크 | Rails 8 | Solid Queue, SQLite 지원 강화 |
| 언어 | Ruby | 3.3+ |
| DB | SQLite | 단일 파일, 백업 단순, FTS5 내장 |
| 백그라운드 잡 | Solid Queue | DB 기반, 외부 의존 없음 |
| 실시간 | ActionCable | Turbo Stream 연동 |
| 스크래핑 | Nokogiri | HTML 파싱 |
| YouTube | yt-dlp | 자막/메타데이터 추출 |
| AI | llama-server | 로컬 LLM, 120s timeout |

### 프론트엔드
| 항목 | 선택 | 이유 |
|------|------|------|
| HTML 렌더링 | Hotwire (Turbo + Stimulus) | Rails 8 기본, SPA 없이 리액티브 UX |
| CSS | Tailwind CSS | 유틸리티 우선, 빠른 개발 |
| JS | Stimulus controllers | 최소한의 JS |
| 아이콘 | Heroicons | Tailwind 생태계 |

### 인프라
| 항목 | 선택 |
|------|------|
| 서버 | 개인 서버 (Kamal 배포) |
| 도메인 | urlf2.hwandam.kr |
| PWA | manifest.json + Service Worker |

---

## 아키텍처

```
[브라우저/PWA]
     │ HTTP/WebSocket
     │
[Rails 8 App]
     ├── Controllers (HTTP 요청 처리)
     ├── Views (ERB + Turbo Frames/Streams)
     ├── Stimulus Controllers (클라이언트 JS)
     │
     ├── Services
     │   ├── WebpageScraper (Nokogiri)
     │   ├── YoutubeExtractor (yt-dlp)
     │   ├── LlmAnalyzer (llama-server HTTP)
     │   ├── FavoriteSearch (FTS5)
     │   ├── FavoriteSearchIndexer
     │   └── UrlSanitizer
     │
     ├── Jobs (Solid Queue)
     │   ├── AnalyzeWebpageJob
     │   ├── AnalyzeYoutubeJob
     │   └── ReindexFavoriteJob
     │
     └── DB (SQLite)
         ├── favorites
         ├── analyses
         ├── collections
         ├── collection_memberships
         └── favorites_fts (FTS5 가상 테이블)

[llama-server] (로컬, HTTP API)
     └── POST /v1/chat/completions
```

---

## 데이터 모델

### favorites 테이블

```ruby
create_table :favorites do |t|
  t.string   :url,             null: false
  t.string   :normalized_url,  null: false, index: { unique: true }
  t.string   :title
  t.string   :favicon_url
  t.string   :thumbnail_url
  t.string   :content_type,    null: false, default: "webpage"
  t.string   :status,          null: false, default: "pending"
  t.text     :raw_content
  t.text     :note
  t.string   :error_message
  t.integer  :retry_count,     null: false, default: 0
  t.timestamps
end
```

**content_type**: `"webpage"` | `"youtube"`
**status**: `"pending"` | `"analyzing"` | `"done"` | `"failed"`

### analyses 테이블

```ruby
create_table :analyses do |t|
  t.references :favorite, null: false, foreign_key: true, index: { unique: true }
  t.text       :summary
  t.json       :tags,           default: []
  t.json       :key_points,     default: []
  t.string     :sentiment
  t.text       :transcript
  t.string     :subtitle_source  # "subtitle_ko" | "subtitle_en" | "auto" | "description"
  t.json       :video_metadata,  default: {}
  t.string     :model_used
  t.datetime   :analyzed_at
  t.timestamps
end
```

### collections 테이블

```ruby
create_table :collections do |t|
  t.string :name,        null: false
  t.text   :description
  t.timestamps
end
```

### collection_memberships 테이블

```ruby
create_table :collection_memberships do |t|
  t.references :favorite,   null: false, foreign_key: true
  t.references :collection, null: false, foreign_key: true
  t.timestamps
end
add_index :collection_memberships, [:favorite_id, :collection_id], unique: true
```

### FTS5 가상 테이블 (SQLite)

```sql
CREATE VIRTUAL TABLE favorites_fts USING fts5(
  favorite_id UNINDEXED,
  title,
  summary,
  tags,
  note,
  content='favorites',
  content_rowid='id'
);
```

---

## API 엔드포인트 명세

### POST /favorites

**Request**
```json
{ "url": "https://example.com/article" }
```

**Response 201**
```json
{
  "id": 42,
  "url": "https://example.com/article",
  "status": "pending",
  "content_type": "webpage"
}
```

**Response 422** (중복)
```json
{ "error": "이미 저장된 URL입니다." }
```

**Response 422** (안전성 위반)
```json
{ "error": "저장할 수 없는 URL입니다." }
```

---

### GET /favorites

**Query Parameters**
| 파라미터 | 타입 | 설명 |
|---------|------|------|
| `q` | string | 검색 키워드 (FTS5) |
| `tag` | string | 태그 필터 |
| `type` | string | `webpage` \| `youtube` |
| `status` | string | `pending` \| `done` \| `failed` |
| `collection_id` | integer | 컬렉션 필터 |
| `page` | integer | 페이지 번호 |

**Response 200** — HTML (Turbo Frame) 또는 JSON

---

### PATCH /favorites/:id

**Request**
```json
{ "note": "나중에 다시 읽기" }
```

**Response 200**
```json
{ "id": 42, "note": "나중에 다시 읽기" }
```

---

### POST /favorites/:id/reanalyze

**Response 200**
```json
{ "id": 42, "status": "pending" }
```

---

## llama-server 연동

**엔드포인트**: `http://localhost:8080/v1/chat/completions`  
**Timeout**: 120초  
**모델**: 환경변수 `LLAMA_MODEL`로 설정

**프롬프트 구조** (영어)
```
System: You are a content analyzer. Extract structured information from the given text.
User: Analyze this content and return JSON with: summary (3-5 sentences), tags (5-10 keywords), key_points (3-7 bullet points).

Content:
{raw_content}
```

**응답 파싱**: JSON 코드블록 추출 → `Analysis` 레코드 저장

---

## 환경변수

```bash
# llama-server
LLAMA_SERVER_URL=http://localhost:8080
LLAMA_MODEL=llama3-70b

# 앱 설정
RAILS_ENV=production
SECRET_KEY_BASE=...
DATABASE_PATH=/data/urlf2.sqlite3

# yt-dlp
YTDLP_PATH=/usr/local/bin/yt-dlp
```

---

## Solid Queue 설정

```yaml
# config/queue.yml
default:
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: analyze
      threads: 2
      processes: 1
    - queues: default
      threads: 5
```

**큐 우선순위**
- `analyze`: AI 분석 Job (2 threads, 순차 처리)
- `default`: 재인덱싱 등 기타 Job

---

## PWA 설정

**manifest.json 핵심 필드**
```json
{
  "name": "urlf2",
  "short_name": "urlf2",
  "start_url": "/",
  "display": "standalone",
  "share_target": {
    "action": "/share",
    "method": "POST",
    "enctype": "application/x-www-form-urlencoded",
    "params": {
      "url": "url",
      "title": "title"
    }
  }
}
```

**Service Worker**: 오프라인 fallback 페이지 캐싱
