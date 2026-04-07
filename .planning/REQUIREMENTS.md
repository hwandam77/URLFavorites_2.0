# URLFavorites 2.0 — Requirements

## v1 Scope (이번 마일스톤)

### Core
- [R01] URL 저장 (POST /favorites, 중복 방지, URL 정규화)
- [R02] URL 안전성 검증 (사설 IP/내부 주소 차단, HTTP/HTTPS만 허용)
- [R03] 콘텐츠 타입 감지 (webpage vs youtube)
- [R04] 웹페이지 스크래핑 (Nokogiri, 본문 8,000자 제한)
- [R05] YouTube 추출 (yt-dlp, 자막 fallback, 12,000자 제한)
- [R06] AI 비동기 분석 (Solid Queue, llama-server 120s timeout)
- [R07] 상태 머신 (pending → analyzing → done/failed, 자동 3회 재시도)
- [R08] raw_content 캐싱 (재시도 시 재활용)

### Search
- [R09] SQLite FTS5 통합 검색 (title, summary, tags, note)
- [R10] 필터 (태그, 컬렉션, 콘텐츠 타입, 분석 상태)
- [R11] 검색 인덱스 자동 갱신 (분석 완료, 메모 수정, 컬렉션 변경 시)

### UI
- [R12] 카드형 아카이브 홈 (검색바 + 필터 칩 + 카드 목록)
- [R13] 카드/리스트 보기 전환
- [R14] 독립 상세 페이지 (AI 요약, 핵심 포인트, 태그, 메모, 컬렉션)
- [R15] 메모 편집 (상세 화면, 검색 대상 포함)
- [R16] 컬렉션 CRUD + 즐겨찾기 연결
- [R17] 모바일 우선 반응형 (필터 바텀시트)
- [R18] 실시간 상태 갱신 (Turbo Stream + ActionCable)

### PWA
- [R19] PWA manifest + share_target (모바일 공유 저장)
- [R20] 오프라인 fallback 화면

### Migration
- [R21] urlf 스냅샷 1회 이관 (favorites + analyses)
- [R22] 이관 멱등성 (재실행 시 중복 방지)

## v2 Scope (후순위)
- 브라우저 확장 (Manifest V3) + Bearer token auth
- 컬렉션 커버 이미지
- 자동 컬렉션 추천
- 고급 추천 랭킹
- 외부 공유 링크
- 전문 검색 엔진 도입

## Out of Scope
- 멀티유저, 권한 체계
- 실시간 urlf ↔ urlf2 동기화
- 소셜 공유/공개 기능
