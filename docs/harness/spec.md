# urlf2 — Harness Spec

## 프로젝트 개요

**urlf2** = "저장하면 AI가 검색 가능하게 만들어주는 개인 지식 아카이브"

- URL을 붙여넣는 순간 AI가 콘텐츠를 분석하고, 태그/요약/핵심포인트를 자동 생성
- 사용자: 1인 (개발자 본인)
- 플랫폼: 웹 (PWA, 모바일 우선)
- 도메인: urlf2.hwandam.kr

## 핵심 원칙

1. **저장은 1초** — URL만 붙여넣으면 저장 완료
2. **AI가 자동 정리** — 백그라운드에서 요약/태그/핵심포인트 자동 생성
3. **검색이 강력** — FTS5 전문 검색 + AI 메타데이터
4. **메모는 선택적** — 필수 아님, 강화 레이어
5. **모바일 우선** — PWA share_target

---

## 기술 스택

| 계층 | 기술 |
|------|------|
| 백엔드 | Rails 8 / Ruby 3.3+ / SQLite + FTS5 / Solid Queue |
| 프론트엔드 | Hotwire (Turbo + Stimulus) / Tailwind CSS |
| AI | llama-server (local LLM, 120s timeout) |
| PWA | manifest.json + Service Worker |

---

## 데이터 모델

### favorites
| 필드 | 타입 | 설명 |
|------|------|------|
| url | string | 원본 URL |
| normalized_url | string | 정규화 URL (unique) |
| title | string | 페이지 제목 |
| favicon_url | string | 파비콘 URL |
| thumbnail_url | string | OG 이미지 |
| content_type | string | "webpage" / "youtube" |
| status | string | "pending" / "analyzing" / "done" / "failed" |
| raw_content | text | 스크랩된 본문 |
| note | text | 사용자 메모 |
| error_message | string | 실패 메시지 |
| retry_count | integer | 재시도 횟수 |

### analyses
| 필드 | 타입 | 설명 |
|------|------|------|
| favorite_id | ref | favorites FK |
| summary | text | AI 요약 3-5문장 |
| tags | json | 태그 배열 5-10개 |
| key_points | json | 핵심포인트 3-7개 |
| sentiment | string | YouTube 감정 |
| transcript | text | YouTube 자막 |
| subtitle_source | string | 자막 출처 |
| video_metadata | json | 영상 메타데이터 |

### collections / collection_memberships
- 컬렉션 CRUD + 다대다 관계

### favorites_fts (FTS5)
- title, summary, tags, note 통합 검색

---

## 라우트

| Method | Path | 설명 |
|--------|------|------|
| GET | `/` | 홈 (아카이브) |
| POST | `/favorites` | URL 저장 |
| GET | `/favorites/:id` | 상세 페이지 |
| PATCH | `/favorites/:id` | 메모 업데이트 |
| DELETE | `/favorites/:id` | 삭제 |
| POST | `/favorites/:id/reanalyze` | 재분석 |
| GET | `/collections` | 컬렉션 목록 |
| POST | `/collections` | 컬렉션 생성 |
| GET | `/collections/:id` | 컬렉션 상세 |
| PATCH | `/collections/:id` | 컬렉션 수정 |
| DELETE | `/collections/:id` | 컬렉션 삭제 |
| POST | `/collection_memberships` | 컬렉션에 추가 |
| DELETE | `/collection_memberships/:id` | 컬렉션에서 제거 |
| POST | `/share` | PWA share_target |

---

## 화면

### S01. 홈 (아카이브)
- 사이드바 (240px): 컬렉션 목록
- 메인: 통합 입력바 + 필터 칩 + 카드 그리드 (2-3열)
- 필터: 전체 / webpage / youtube / pending / failed
- 태그 칩 수평 스크롤
- 카드/리스트 뷰 전환

### S02. 상세 페이지
- AI 요약 / 핵심포인트 / 태그 / 메모 / 컬렉션
- 재분석 / 삭제 버튼
- 원본 보기 링크

### S03. 컬렉션 상세
- 컬렉션 정보 + 카드 목록

### S04. 공유 수신 (PWA)
- share_target 수신 화면

---

## 디자인 시스템

### 색상
| 용도 | 색상 |
|------|------|
| 배경 | #FAFAF8 (따뜻한 오프화이트) |
| accent | #2D6A4F (그린) |
| link | #2563EB (파랑) |
| pending | #9CA3AF (회색) |
| analyzing | #3B82F6 (파랑) |
| done | #10B981 (에메랄드) |
| failed | #EF4444 (빨강) |

### 타이포그래피
- Pretendard Variable (한국어 + Latin)
- 폰트 스케일: 12/14/16/18/20/24/30px

### 상태 뱃지
- pending: ⏳ 회색
- analyzing: ⚡ 파랑 pulse
- done: ✓ 에메랄드
- failed: ✗ 빨강

---

## 기능 우선순위

### P0 (핵심)
- F01 URL 저장
- F02 URL 안전성 검증
- F03 콘텐츠 타입 감지
- F04 웹페이지 스크래핑
- F05 YouTube 추출
- F06 AI 비동기 분석
- F07 상태 머신
- F08 FTS5 검색
- F09 카드형 홈
- F10 상세 페이지

### P1 (重要)
- F11 컬렉션 CRUD
- F12 필터
- F13 Turbo Stream 실시간 갱신
- F14 PWA + 공유 시트

### P2 (있으면 좋음)
- F15 urlf 데이터 이관
- F16 메모 편집

---

## Build-Eval 계약 (Round 1)

### 이번 라운드에서 완료해야 할 항목

**P0 기능 (반드시 동작해야 PASS):**
- URL 저장 → pending 카드 즉시 표시
- FTS5 검색 → 키워드 검색 결과
- 카드형 목록 → 파비콘/제목/도메인/태그/상태 표시
- 상세 페이지 → AI 요약/태그/핵심포인트
- 상태 머신 → pending → analyzing → done/failed
- 컬렉션 목록 → 사이드바 표시
- 필터 → 태그/타입/상태별 필터링

**UI/UX (만족해야 PASS):**
- 에디토리얼 스타일 (보라색 그라데이션 없음)
- 반응형 (모바일 1열, 데스크탑 2-3열)
- 상태 뱃지 명확히 구분
- 빈 상태 메시지
- 로딩 pulse 애니메이션

**데이터:**
- SQLite 영속 확인
- 새로고침 후 데이터 유지
- 중복 URL 차단
