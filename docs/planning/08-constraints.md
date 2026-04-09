# 08 — 제약 조건

## C01. 사용자 규모: 1인 전용

**제약**
- 인증(로그인/회원가입) 없음
- 권한 분리 없음
- 멀티테넌시 없음

**의미하는 것**
- 세션 기반 인증 구현 불필요
- 모든 라우트 공개 (로컬 서버이므로 네트워크 수준에서 접근 제한)
- API 키, JWT 없음

**트레이드오프**
- 장점: 개발 속도, 유지보수 단순화
- 단점: 인터넷 노출 시 완전 공개 (네트워크 방화벽으로 보완)

---

## C02. AI: 로컬 llama-server 전용

**제약**
- OpenAI, Anthropic 등 외부 AI API 사용 안 함
- llama-server (HTTP, OpenAI 호환 API) 로컬 인스턴스만 사용
- 모델: 30B 또는 48B (환경변수로 설정)

**의미하는 것**
- 분석 속도는 하드웨어에 의존 (GPU 없으면 느릴 수 있음)
- 120초 타임아웃 필수 (느린 추론 대응)
- 네트워크 연결 없어도 동작
- API 비용 없음

**제약 처리 방식**
- `LLAMA_SERVER_URL` 환경변수로 URL 설정
- llama-server 다운 시 Job 실패 → 재시도 큐
- 재시도 3회 후 `failed` 상태, 나중에 수동 재분석

---

## C03. DB: SQLite 단일 파일

**제약**
- PostgreSQL, MySQL 없음
- SQLite 파일 1개 (`/data/urlf2.sqlite3`)
- 동시성 제한 (쓰기 잠금)

**의미하는 것**
- 단순 백업: 파일 복사 1개로 완료
- Rails 8 + Solid Queue + SQLite 조합 공식 지원
- 동시 쓰기 성능은 1인 사용자에 충분
- WAL 모드 활성화 (`PRAGMA journal_mode=WAL`)

**SQLite 특화 설정**
```ruby
# config/database.yml
production:
  adapter: sqlite3
  database: /data/urlf2.sqlite3
  pragmas:
    journal_mode: wal
    synchronous: normal
    cache_size: -10000
    foreign_keys: true
```

---

## C04. 분석 처리량: 순차 처리

**제약**
- AI 분석 Job: 최대 2 threads (llama-server 동시 요청 제한)
- 동시에 대량 저장 시 큐에 쌓여서 처리

**의미하는 것**
- 빠른 연속 저장 시 분석 완료까지 대기 발생
- Turbo Stream으로 완료 시점에 자동 업데이트되므로 UX에 허용 가능
- 백프레셔 필요 없음 (1인 사용자)

---

## C05. 스크래핑: 공개 웹페이지만

**제약**
- 로그인 필요한 페이지 스크래핑 불가
- JavaScript 렌더링 미지원 (Nokogiri는 정적 HTML만)
- 8000자 제한 (AI 컨텍스트 윈도우 고려)

**의미하는 것**
- SPA(React/Vue) 기반 사이트는 제목/OG 메타만 추출 가능 (본문 없음)
- 유료 콘텐츠 사이트 분석 제한적
- 허용 범위: HTTP/HTTPS, 공개 접근 가능한 URL

**회피 방법**
- YouTube: yt-dlp로 자막 추출 (OG 스크래핑 없이 풍부한 콘텐츠)
- SPA 사이트: OG 태그, meta description 기반으로 분석

---

## C06. 운영 단순화

**제약**
- 외부 서비스 의존 최소화 (Redis 없음, Elasticsearch 없음)
- 모니터링 도구: 최소한 (로그 파일 직접 확인)
- 배포: Kamal (단일 서버)

**의미하는 것**
- Solid Queue: Redis 없이 SQLite DB로 큐 관리
- Solid Cache: Redis 없이 SQLite DB로 캐시 (필요 시)
- ActionCable: Async 어댑터 (단일 서버, Redis 불필요)
- 검색: FTS5 (Elasticsearch 없이 SQLite 내장)

**백업 전략**
```bash
# 단순 파일 복사
cp /data/urlf2.sqlite3 /backup/urlf2-$(date +%Y%m%d).sqlite3
```

---

## C07. 외부 도구 의존

**허용된 외부 도구**
- `yt-dlp`: YouTube 자막/메타데이터 추출 (시스템 설치 필요)
- `nokogiri`: Ruby gem (bundler 관리)
- `llama-server`: 로컬 서버 (별도 설치 필요)

**설치 전제 조건 (운영 서버)**
```bash
# yt-dlp
pip install yt-dlp

# llama-server
# llama.cpp 빌드 또는 바이너리 다운로드
```

---

## C08. 네트워크 보안 (1인 사용)

**제약**
- 앱 자체는 인증 없음
- 네트워크 접근 제어는 서버 방화벽에 위임

**권장 운영 설정**
- 방화벽: 개인 IP만 허용 (또는 로컬 전용)
- HTTPS: Let's Encrypt (Kamal 자동 처리)
- 사설 IP URL 저장 차단 (F02): 내부 네트워크 SSRF 방지

---

## C09. 데이터 보존

**제약**
- 삭제된 Favorite는 즉시 DB에서 제거 (소프트 딜리트 없음)
- Analysis 레코드는 Favorite 삭제 시 함께 삭제 (CASCADE)
- raw_content: DB 내 텍스트 저장 (파일 저장 없음)

**이유**
- 1인 사용자, 복잡한 복구 기능 불필요
- 디스크 용량 관리 단순화

---

## 제약 요약표

| 제약 | 영향 | 대응 방식 |
|------|------|----------|
| 인증 없음 | 방화벽 의존 | 서버 레벨 IP 제한 |
| 로컬 AI | 분석 속도 변동 | 120s 타임아웃 + 재시도 |
| SQLite | 동시 쓰기 제한 | WAL 모드 + 1인 사용자 |
| 정적 HTML 스크래핑 | SPA 제한 | OG/meta 태그 fallback |
| 외부 서비스 없음 | 기능 단순함 | SQLite 기반 큐/캐시/검색 |
