# 03 — 사용자 흐름

## 흐름 1: URL 저장 (핵심 흐름)

```
사용자
  │
  ├─ [홈 화면] 통합 입력바에 URL 붙여넣기
  │
  ├─ Enter 또는 저장 버튼 클릭
  │
  ├─ [클라이언트] URL 패턴 감지 (http/https 여부)
  │
  ├─ POST /favorites
  │   ├─ URL 정규화
  │   ├─ 중복 체크 → 중복 시 오류 메시지 표시 (흐름 종료)
  │   ├─ 안전성 검증 → 실패 시 오류 메시지 표시 (흐름 종료)
  │   ├─ 콘텐츠 타입 감지 (webpage/youtube)
  │   └─ DB 저장 (status: pending)
  │
  ├─ [Turbo Stream] 홈 카드 목록 상단에 pending 카드 추가
  │
  ├─ [Solid Queue] 분석 Job 큐잉
  │   ├─ webpage → AnalyzeWebpageJob
  │   └─ youtube → AnalyzeYoutubeJob
  │
  ├─ [백그라운드] 콘텐츠 추출
  │   ├─ webpage: Nokogiri 스크래핑 (8000자)
  │   └─ youtube: yt-dlp 자막/메타데이터 (12000자)
  │
  ├─ [백그라운드] llama-server AI 분석 (120s timeout)
  │   ├─ summary 생성
  │   ├─ tags 생성
  │   └─ key_points 생성
  │
  ├─ 성공 → status: done
  │   └─ [Turbo Stream] 카드 업데이트 (AI 태그, 요약 미리보기)
  │
  └─ 실패 → 재시도 (최대 3회)
      └─ 3회 실패 → status: failed
          └─ [Turbo Stream] 카드 업데이트 (failed 뱃지)
```

---

## 흐름 2: 검색

```
사용자
  │
  ├─ [홈 화면] 통합 입력바에 키워드 입력
  │   └─ URL 패턴이 아닌 경우 → 검색 모드
  │
  ├─ Enter 또는 검색 아이콘 클릭
  │
  ├─ GET /favorites?q=키워드
  │   └─ FTS5 검색 실행
  │       ├─ 정확 일치 우선 정렬
  │       └─ title, summary, tags, note 통합 검색
  │
  ├─ [Turbo Frame] 카드 목록 교체
  │
  ├─ 결과 있음 → 카드 목록 표시
  │
  └─ 결과 없음 → "검색 결과가 없습니다" 빈 상태 표시
```

---

## 흐름 3: 필터

```
사용자
  │
  ├─ [홈 화면] 필터 칩 클릭 (태그/타입/상태)
  │
  ├─ GET /favorites?tag=xxx 또는 ?type=youtube 등
  │
  ├─ [Turbo Frame] 카드 목록 교체
  │
  ├─ 다중 필터 조합 가능
  │   └─ GET /favorites?tag=rails&type=webpage
  │
  └─ 필터 초기화 → GET /favorites (전체 목록)
```

---

## 흐름 4: 컬렉션 관리

```
사용자
  │
  ├─ [사이드바] "새 컬렉션" 클릭
  │   ├─ 이름 입력 모달/인라인 폼
  │   └─ POST /collections
  │       └─ [사이드바] 컬렉션 목록 업데이트 (Turbo Stream)
  │
  ├─ [상세 페이지] 컬렉션 추가
  │   ├─ 컬렉션 선택 드롭다운
  │   └─ POST /collection_memberships
  │
  ├─ [사이드바] 컬렉션 클릭
  │   └─ GET /collections/:id
  │       └─ 해당 컬렉션의 카드 목록 표시
  │
  └─ [컬렉션 상세] 컬렉션 삭제
      ├─ DELETE /collections/:id
      └─ 해당 컬렉션의 멤버십만 삭제 (Favorite는 유지)
```

---

## 흐름 5: 메모 편집 (선택적)

```
사용자
  │
  ├─ [상세 페이지] "메모 추가" 클릭 (메모 없는 경우)
  │   또는 기존 메모 텍스트 클릭 (편집)
  │
  ├─ 텍스트 에어리어 활성화
  │
  ├─ 내용 입력
  │
  ├─ "저장" 클릭
  │   └─ PATCH /favorites/:id (note 필드 업데이트)
  │       └─ FTS5 인덱스 갱신
  │
  └─ "취소" 클릭 → 편집 취소, 원래 내용 유지
```

---

## 흐름 6: 모바일 공유 시트 저장 (PWA)

```
사용자 (iOS/Android)
  │
  ├─ 브라우저/앱에서 URL 공유 버튼 클릭
  │
  ├─ 공유 시트에서 "urlf2" 선택
  │
  ├─ PWA share_target → POST /favorites (URL 파라미터)
  │
  ├─ 저장 성공 → "저장되었습니다" 확인 화면
  │
  └─ 저장 실패 → 오류 메시지 표시
```

---

## 흐름 7: 상세 페이지 조회 및 재분석

```
사용자
  │
  ├─ [홈 화면] 카드 클릭
  │   └─ GET /favorites/:id
  │
  ├─ [상세 페이지] 내용 확인
  │   ├─ AI 요약
  │   ├─ 핵심포인트
  │   ├─ AI 태그 (클릭 시 해당 태그 필터)
  │   ├─ 메모
  │   └─ 컬렉션
  │
  └─ "재분석" 버튼 클릭 (분석 실패 또는 갱신 원할 때)
      ├─ POST /favorites/:id/reanalyze
      ├─ status → pending
      └─ 분석 Job 재큐잉 → 완료 시 Turbo Stream 업데이트
```

---

## 흐름 8: 모바일 사이드바 (드로어)

```
사용자 (모바일)
  │
  ├─ 햄버거 메뉴 아이콘 클릭
  │
  ├─ [드로어] 사이드바 슬라이드인
  │   ├─ 컬렉션 목록
  │   └─ 컬렉션 클릭 → 드로어 닫힘 + 컬렉션 필터 적용
  │
  └─ 드로어 외부 클릭 또는 X 버튼 → 드로어 닫힘
```
