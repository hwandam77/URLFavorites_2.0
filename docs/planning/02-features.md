# 02 — 기능 상세 명세

## P0 핵심 기능

### F01. URL 저장

**유저스토리**
"개발자로서, URL을 붙여넣기만 해서 즉시 저장하고 싶다. 나머지는 자동으로 처리되길 원한다."

**수락 기준**
- 홈 통합 입력바에 URL 입력 후 Enter 또는 저장 버튼으로 저장
- 저장 즉시 pending 상태 카드가 목록에 추가됨 (Turbo Stream)
- 동일 URL 재저장 시 "이미 저장된 URL입니다" 메시지 표시
- URL 정규화: 쿼리스트링 정리, 트레일링 슬래시 통일
- 저장 가능한 스킴: http, https만 허용

**기술 노트**
- `POST /favorites` — Turbo Frame 또는 JSON 응답
- `Favorite.find_or_initialize_by(normalized_url:)`
- `AnalyzeWebpageJob` 또는 `AnalyzeYoutubeJob` 큐잉

---

### F02. URL 안전성 검증

**유저스토리**
"개발자로서, 내부 네트워크 주소나 악의적 URL이 저장되지 않길 원한다."

**수락 기준**
- 사설 IP 범위 차단: 10.x.x.x, 172.16-31.x.x, 192.168.x.x, 127.x.x.x, ::1
- localhost, 0.0.0.0 차단
- file://, ftp:// 등 비허용 스킴 차단
- 차단된 URL 저장 시 명확한 오류 메시지 반환

**기술 노트**
- `UrlSanitizer` 서비스 클래스
- `Resolv.getaddress` 후 IP 범위 체크
- Model validation 레벨에서 처리

---

### F03. 콘텐츠 타입 감지

**유저스토리**
"개발자로서, YouTube URL과 일반 웹페이지를 자동으로 구분해서 처리하길 원한다."

**수락 기준**
- `youtube.com/watch`, `youtu.be/` 패턴 → `content_type: "youtube"`
- 그 외 → `content_type: "webpage"`
- 타입에 따라 적절한 Job 큐잉

**기술 노트**
- `Favorite#detect_content_type` — URL 패턴 매칭
- `before_create` 콜백으로 자동 설정

---

### F04. 웹페이지 스크래핑

**유저스토리**
"개발자로서, 저장한 웹페이지의 본문이 자동으로 추출되어 AI 분석에 사용되길 원한다."

**수락 기준**
- Nokogiri로 HTML 파싱, 본문 텍스트 추출
- 8000자 초과 시 앞 8000자만 사용
- 파비콘, OG 이미지(thumbnail), 페이지 타이틀 추출
- 추출 실패 시 `error_message` 기록 후 `failed` 상태

**기술 노트**
- `WebpageScraper` 서비스 클래스
- `Favorite#raw_content` 컬럼에 캐싱
- Timeout: 15초

---

### F05. YouTube 콘텐츠 추출

**유저스토리**
"개발자로서, YouTube 영상의 자막이나 설명을 자동으로 추출해서 AI가 분석할 수 있길 원한다."

**수락 기준**
- yt-dlp로 영상 메타데이터 + 자막 추출
- 한국어 자막 우선, 없으면 영어, 없으면 auto-generated
- 자막 없을 경우 description으로 fallback
- 12000자 초과 시 앞 12000자 사용
- `subtitle_source` 필드에 출처 기록 (subtitle_ko/subtitle_en/auto/description)

**기술 노트**
- `YoutubeExtractor` 서비스 클래스
- `Analysis#video_metadata` — JSON (duration, channel, view_count 등)
- `Analysis#transcript` 컬럼에 저장

---

### F06. AI 비동기 분석

**유저스토리**
"개발자로서, URL 저장 직후 AI가 백그라운드에서 자동으로 콘텐츠를 분석해주길 원한다."

**수락 기준**
- 저장 즉시 Solid Queue에 분석 Job 큐잉
- llama-server 로컬 API 호출 (120초 timeout)
- 분석 결과: summary, tags(JSON 배열), key_points(JSON 배열)
- YouTube는 추가로 sentiment, transcript 생성
- 분석 완료 시 `status: "done"`, 실패 시 자동 3회 재시도
- 3회 재시도 후 실패 시 `status: "failed"`, `error_message` 기록

**기술 노트**
- `AnalyzeWebpageJob`, `AnalyzeYoutubeJob`
- `LlmAnalyzer` 서비스 클래스 (llama-server 래퍼)
- `retry_on StandardError, wait: :exponentially_longer, attempts: 3`

---

### F07. 상태 머신

**유저스토리**
"개발자로서, 각 URL의 분석 상태를 명확하게 파악하고 싶다."

**수락 기준**
- 상태: `pending` → `analyzing` → `done` / `failed`
- `pending`: 저장됨, 분석 대기
- `analyzing`: Job 실행 중
- `done`: AI 분석 완료
- `failed`: 3회 재시도 후 실패
- 상태별 UI 표시 (뱃지/아이콘)

---

### F08. SQLite FTS5 검색

**유저스토리**
"개발자로서, 저장한 콘텐츠를 키워드로 빠르게 검색하고 싶다."

**수락 기준**
- 검색 대상: title, summary, tags, note
- FTS5 가상 테이블 활용
- 정확 일치 우선, 부분 일치 보조
- 검색어 입력 후 즉시 결과 갱신 (Turbo Frame)
- 검색 결과 없을 시 "검색 결과가 없습니다" 표시

**기술 노트**
- `FavoriteSearch` 서비스 클래스
- `favorites_fts` 가상 테이블 (FTS5)
- `FavoriteSearchIndexer` — 저장/수정 시 인덱스 갱신
- `ReindexFavoriteJob` — 비동기 재인덱싱

---

### F09. 카드형 홈 화면

**유저스토리**
"개발자로서, 저장한 모든 URL을 카드 형태로 한눈에 볼 수 있길 원한다."

**수락 기준**
- 통합 입력바: URL 입력 시 저장, 키워드 입력 시 검색으로 동작
- 필터 칩: 태그/콘텐츠타입/분석상태 필터
- 카드 목록: 최신순 정렬, 무한 스크롤 또는 페이지네이션
- 카드에 표시: 파비콘, 제목, 도메인, AI 태그, 분석 상태
- 카드/리스트 뷰 전환 버튼

---

### F10. 상세 페이지

**유저스토리**
"개발자로서, 특정 URL의 AI 분석 결과를 상세히 보고 싶다."

**수락 기준**
- AI 요약 (3-5문장)
- 핵심포인트 (bullet list)
- AI 태그 (클릭 시 해당 태그 필터)
- 메모 편집 (선택적)
- 컬렉션 추가/제거
- 재분석 버튼 (분석 재실행)
- 원본 URL 링크

---

## P1 중요 기능

### F11. 컬렉션 CRUD

**유저스토리**
"개발자로서, 관련 URL들을 컬렉션으로 그룹핑하고 싶다."

**수락 기준**
- 컬렉션 생성/이름 변경/삭제
- 사이드바에 컬렉션 목록 표시
- 상세 페이지에서 컬렉션 추가/제거
- 컬렉션 상세 페이지: 해당 컬렉션의 카드 목록

---

### F12. 필터

**유저스토리**
"개발자로서, 태그/타입/상태로 목록을 필터링하고 싶다."

**수락 기준**
- 태그 필터: AI 생성 태그로 필터
- 콘텐츠 타입 필터: webpage/youtube
- 분석 상태 필터: pending/done/failed
- 다중 필터 조합 가능
- 필터 초기화 버튼

---

### F13. Turbo Stream 실시간 갱신

**유저스토리**
"개발자로서, AI 분석이 완료되면 페이지 새로고침 없이 카드가 자동으로 업데이트되길 원한다."

**수락 기준**
- 분석 완료 시 해당 카드만 Turbo Stream으로 교체
- ActionCable WebSocket 연결
- 분석 실패 시 failed 뱃지로 업데이트

---

### F14. PWA + 공유 시트

**유저스토리**
"개발자로서, iOS/Android에서 공유 시트로 URL을 저장하고 싶다."

**수락 기준**
- PWA manifest.json 제공
- `share_target` 등록
- 공유 시트에서 urlf2로 URL 전달 및 저장
- 오프라인 fallback 페이지

---

## P2 추가 기능

### F15. urlf 데이터 이관

**수락 기준**
- 기존 urlf 시스템 데이터 1회 임포트
- 멱등성 보장 (중복 실행 안전)
- 이관 결과 리포트 출력

---

### F16. 메모 편집

**수락 기준**
- 상세 페이지에서 메모 추가/수정/삭제
- 메모는 FTS5 검색 인덱스에 포함
- 자동 저장 또는 명시적 저장 버튼
