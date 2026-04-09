# 06 — 화면 명세

## S01. 홈 화면 (`/favorites`)

### 컴포넌트 구성

| 컴포넌트 | 역할 | 구현 방식 |
|---------|------|----------|
| `_layout` | 사이드바 + 메인 영역 레이아웃 | ERB layout |
| `_sidebar` | 컬렉션 목록 + 새 컬렉션 버튼 | Turbo Frame: `sidebar_collections` |
| `_search_bar` | 통합 입력바 | Stimulus: `unified-input` |
| `_filter_bar` | 필터 칩 목록 | Turbo Frame: `filter_bar` |
| `_favorite_card` | 개별 카드 | Partial, Turbo Frame: `favorite_<id>` |
| `_empty_state` | 결과 없음 표시 | Partial |

### 통합 입력바 (`_search_bar`) 동작

```javascript
// unified-input Stimulus controller
// URL 패턴 감지: https?:// 포함 여부
// URL → form action: POST /favorites
// 키워드 → form action: GET /favorites?q=...
```

**상태**
- 기본: "URL 또는 검색어를 입력하세요..."
- URL 입력 감지 → "URL 저장" 버튼 표시
- 키워드 입력 감지 → "검색" 버튼 표시
- 저장 중: 버튼 비활성화, 로딩 인디케이터

### 필터 칩 (`_filter_bar`)

**필터 항목**
- `[전체]` — 필터 없음
- `[webpage]` — content_type=webpage
- `[youtube]` — content_type=youtube
- `[분석 중]` — status=analyzing
- `[실패]` — status=failed
- 태그 칩 — 상위 사용된 태그 최대 10개

**상태**: 선택된 칩 강조 (배경색/테두리)

### 카드 (`_favorite_card`)

**카드 표시 정보**
- 파비콘 (16x16, fallback: 기본 지구 아이콘)
- 제목 (최대 2줄, 초과 시 말줄임)
- 도메인 (URL에서 추출)
- AI 태그 (최대 3개, 나머지 "+N" 표시)
- 분석 상태 뱃지 (pending: 회색, analyzing: 파란 pulse, done: 숨김, failed: 빨간)
- 저장 날짜 (상대 시간: "3시간 전")

**카드 상호작용**
- 클릭 → `/favorites/:id` 이동
- 분석 상태 뱃지는 Turbo Stream으로 실시간 업데이트

**카드 vs 리스트 뷰**
- 카드: 썸네일 표시, 2-3열 그리드
- 리스트: 썸네일 없음, 1열, 조밀한 정보 표시

### 빈 상태 (`_empty_state`)

**케이스별 메시지**
- 전체 비어있음: "아직 저장된 URL이 없습니다. URL을 붙여넣어 시작하세요!"
- 검색 결과 없음: "'[검색어]'에 대한 결과가 없습니다."
- 필터 결과 없음: "해당 조건에 맞는 항목이 없습니다."

---

## S02. 상세 페이지 (`/favorites/:id`)

### 컴포넌트 구성

| 컴포넌트 | 역할 |
|---------|------|
| `_header` | 뒤로가기 + 액션 버튼(재분석/삭제) |
| `_meta` | 제목, 파비콘, 도메인, 날짜, 타입 뱃지 |
| `_summary` | AI 요약 (또는 pending/failed 상태 메시지) |
| `_key_points` | 핵심포인트 bullet list |
| `_tags` | AI 태그 (클릭 시 홈 필터) |
| `_collections` | 소속 컬렉션 + 추가 UI |
| `_note_form` | 메모 편집 폼 |
| `_original_link` | 원본 URL 링크 |

### 상태별 표시

| status | 요약 영역 표시 |
|--------|--------------|
| `pending` | "AI 분석 대기 중..." (스피너) |
| `analyzing` | "AI 분석 중입니다..." (pulse 애니메이션) |
| `done` | AI 요약, 핵심포인트, 태그 |
| `failed` | "분석에 실패했습니다. [재분석] 버튼으로 다시 시도하세요." |

### 메모 폼 (`_note_form`) 인터랙션

**Stimulus controller**: `note-form`
- 기본: 메모 텍스트 표시 (없으면 "메모 없음 — 클릭하여 추가")
- 클릭: 텍스트에어리어 활성화, 저장/취소 버튼 표시
- 저장: `PATCH /favorites/:id` (Turbo Stream 응답)
- 취소: 편집 모드 종료, 원래 값 복원

### 컬렉션 추가 UI

- 현재 소속 컬렉션 배지 목록 (X로 제거 가능)
- "컬렉션 추가" 드롭다운 → 전체 컬렉션 목록 표시
- 선택 시 `POST /collection_memberships`
- 제거 시 `DELETE /collection_memberships/:id`

### 재분석 버튼

- `pending` 또는 `analyzing` 상태일 때 비활성화
- 클릭: `POST /favorites/:id/reanalyze`
- 응답: Turbo Stream으로 상태 섹션 업데이트

---

## S03. 컬렉션 상세 (`/collections/:id`)

### 컴포넌트 구성

| 컴포넌트 | 역할 |
|---------|------|
| `_collection_header` | 컬렉션 이름, 설명, 편집/삭제 버튼 |
| `_collection_stats` | 항목 수 표시 |
| `_filter_bar` | S01과 동일한 필터 (컬렉션 내 필터) |
| `_favorite_card` | S01과 동일한 카드 (재사용) |

### 컬렉션 편집 인터랙션

- 편집 버튼 → 인라인 폼으로 이름/설명 수정
- `PATCH /collections/:id` (Turbo Frame 응답)
- 삭제 버튼 → 확인 모달 → `DELETE /collections/:id`
  - 컬렉션의 멤버십만 삭제, Favorite는 유지

---

## S04. PWA 공유 수신 (`/share`)

### 흐름

```
share_target POST 요청 수신
    ↓
URL 파라미터 추출
    ↓
favorites#create와 동일 로직 실행
    ↓
성공: "저장되었습니다 ✓" 확인 페이지 (2초 후 자동 닫힘)
실패: "저장에 실패했습니다" 오류 페이지
```

---

## 사이드바 (`_sidebar`)

### 데스크탑
- 고정 (sticky), 너비 240px
- "urlf2" 로고/제목 상단
- 컬렉션 목록: 각 항목 클릭 시 `/collections/:id`
- 선택된 컬렉션 강조 표시
- "+ 새 컬렉션" 버튼: 인라인 폼으로 이름 입력
- Turbo Frame: `sidebar_collections`으로 목록 갱신

### 모바일 드로어
- Stimulus controller: `sidebar`
- 햄버거 메뉴 클릭 → translate-x 트랜지션으로 슬라이드인
- 오버레이(반투명 배경) 클릭 → 닫힘
- 닫힘 버튼(×) 클릭 → 닫힘

---

## 공통 인터랙션 패턴

### Turbo Stream 업데이트 대상

| 이벤트 | 타겟 | 액션 |
|-------|------|------|
| Favorite 저장 완료 | `favorites_list` | prepend (신규 카드 추가) |
| 분석 상태 변경 | `favorite_<id>` | replace (카드 전체 교체) |
| 컬렉션 생성 | `sidebar_collections` | append |
| 메모 저장 | `favorite_note_<id>` | replace |

### 로딩 상태

- URL 저장: 입력바 버튼 `data-disable-with="저장 중..."` 또는 Stimulus
- AI 분석 중: 카드에 pulse 애니메이션 (Tailwind `animate-pulse`)
- 검색: Turbo Frame 자체 로딩 인디케이터

### 에러 처리

- 네트워크 오류: "저장에 실패했습니다. 다시 시도하세요." (토스트 알림)
- 유효성 오류: 입력바 아래 인라인 오류 메시지
- 분석 실패: 카드에 failed 뱃지 + 상세 페이지에서 재분석 안내
