# URLFavorites v3.0 업그레이드 — 최종 완료 보고서

- 작성일: 2026-07-14
- 기간: 2026-07-12 ~ 2026-07-14 (설계 → 구현 → 배포 → 안정화)
- 상태: **완료** — 프로덕션 라이브 (`https://urlf.hwandam.kr/favorites`)
- 설계 문서: [`docs/plans/2026-07-12-urlf2-v3-design.md`](../plans/2026-07-12-urlf2-v3-design.md)
- 중간 기록: [`2026-07-13-v3-session-summary.md`](2026-07-13-v3-session-summary.md)

## 1. 목표 대비 결과

| # | 계획 항목 | 결과 |
|---|-----------|------|
| F1 | X(트위터) 콘텐츠 분석 | ✅ 완료 (syndication API 방식으로 1회 보정) |
| F2 | 멀티 LLM 태스크 라우팅 (beacon fast / synapse heavy) | ✅ 완료 (유튜브 fast-first로 1회 보정) |
| UI | X(트위터) 분류 노출 | ✅ 완료 (사이드바 탐색 + 타입 필터 툴바) |
| — | v3.0 버전 라벨 | ✅ 완료 (사이드바 `v3.0`) |

## 2. Feature 1 — X(트위터) 분석 (완료 매트릭스)

설계서 §Feature 1의 파일 단위 변경 목록 전체 구현·배포 완료.

| 설계 항목 | 상태 | 비고 |
|-----------|------|------|
| `TypeDetector` TWITTER_PATTERNS | ✅ | x.com / twitter.com / mobile |
| `Favorite::CONTENT_TYPES` "twitter" | ✅ | |
| `Integrations::Twitter::Extractor` | ✅ | **설계 변경**: Jina 무인증 tier가 x.com 403 → 개별 트윗은 X syndication API로 추출 (`38d6a68`) |
| `AnalyzeTwitterJob` + enqueue 라우팅 | ✅ | |
| `RunAnalysis` twitter 분기 | ✅ | |
| `twitter_prompt_rules` | ✅ | |
| `CategoryDetector` twitter → 뉴스/커뮤니티 | ✅ | |
| UI 분류 필터 | ✅ | `3c61b08` — 사이드바 "X" 항목 + index `["X","twitter"]` 필터 버튼 |

## 3. Feature 2 — 멀티 LLM 태스크 라우팅 (완료 매트릭스)

| 설계 항목 | 상태 | 비고 |
|-----------|------|------|
| `Domain::Analysis::BackendRouter` (순수 로직) | ✅ | content_type + content_length + style → role 우선순위 |
| `LLM_BACKENDS` role 스키마 (heavy/fast) | ✅ | beacon=fast(35B-A3B, ~62tok/s) / synapse=heavy(40B, ~13tok/s) |
| 임베딩 오프로드 `EMBEDDING_URL` | ✅ | beacon으로 분리 |
| 프로덕션 env.conf 반영 | ✅ | `\"` 이스케이프 필수 (트러블슈팅 표 참조) |
| 운영 보정: 유튜브 fast-first | ✅ | heavy가 5배 느려 timeout 경계 초과 → fast 우선 (`8dcfe67`) + timeout 240초 |

## 4. 안정화 수정 (2026-07-13 ~ 07-14 사후 세션)

배포 후 실사용에서 발견된 문제들. 전부 근본 원인 수정 + 테스트 추가 + 배포 완료.

| 증상 | 근본 원인 | 수정 | 커밋 |
|------|-----------|------|------|
| 분석 완료본이 있는데 "실패" 배지 | 재분석 실패 시 rescue가 status를 무조건 `failed`로 강등 | 완성 분석(summary) 존재 시 `done` 유지 | `e4fdd6a` |
| tistory 글 본문이 92자(제목+광고)만 추출 | `<article>`이 광고 껍데기인 사이트에서 article-우선 추출 | 본문 200자 미만이면 main → body 폴백 | `e4fdd6a` |
| 재분석해도 오염된 본문 재사용 | `raw_content` 캐시를 재분석에서도 그대로 사용 | 수동 재분석(RetryAnalysis) 시 `raw_content` 초기화 | `e4fdd6a` |
| **배포해도 잡이 옛 코드로 동작** | 이전 재시작에서 살아남은 **고아 solid-queue 트리(PPID=1)**가 같은 큐 DB의 잡을 선점 | 고아 트리 kill + CLAUDE.md 트러블슈팅 표에 진단법 기록 (`lsof production_queue.sqlite3`) | `4d5fc3a` (문서) |
| 블로그 글이 전부 카테고리 "기타" | `CategoryDetector`가 URL 문자열만으로 분류 | 분석 완료 시 제목+LLM 태그(내용 신호) 기반 분류, AI코딩 패턴에 codex/claude-code 등 추가 | `b3987c0` |
| share.google 단축링크가 "302 Moved"로 분석 | Faraday가 리다이렉트 미추적 → 302 본문(48자)을 분석 | 스크레이퍼에 리다이렉트 추적(최대 5회) + 잔여 3xx는 FetchError | `608b9fe` |
| (디자인 피드백) 사이드바 모바일 URL 폼 | — | 폼 블록 제거 (index 상단 폼 유지) | `13ef4c3` |
| (디자인 피드백) 버전 라벨 v2.0 | — | v3.0으로 변경 | `82292f1` |

## 5. 운영 검증 (evidence)

실제 프로덕션 데이터로 end-to-end 검증 완료 (2026-07-13 ~ 07-14 KST):

| 레코드 | 시나리오 | 결과 |
|--------|----------|------|
| id 309 (유튜브) | 재분석 실패가 완성본을 가리던 케이스 | `done` 원복, 완성 분석 보존 |
| id 191 (tistory /587) | 92자 껍데기 본문 → 재분석 | 본문 8,081자, 정상 요약, 카테고리 AI모델 |
| id 230 (share.google → /601) | "302 Moved" 분석 → 리다이렉트 수정 후 재분석 | 제목·본문 8,056자·요약 정상, 카테고리 AI코딩 |
| id 319 (/601 직접 URL) | 신규 추가 end-to-end | 정상 분석 (※ 230과 내용 중복 — 검증용 생성분) |

- 테스트: 스크레이퍼/분석/카테고리 신규 테스트 6건 포함 전체 통과, RuboCop 0 위반
- 배포: `bin/deploy --quick` + deploy-doctor pre/post green, health 302(로그인 리다이렉트) 정상
- 유튜브 분석(id 318, 123초 소요) heavy→fast 라우팅 포함 정상 완료 확인

## 6. 남은 과제 (v3.0 범위 외, 후속 검토)

1. **단축링크 타입 감지 한계** — share.google → YouTube 영상인 경우 저장 시점 타입 감지가 원본 URL 기준이라 `webpage`로 저장됨. 저장 시 최종 URL로 정규화(리다이렉트 해소)하는 개선 검토.
2. **기존 "기타" 항목 일괄 재분류** — 내용 기반 분류기는 신규 분석부터 적용. 기존 항목은 저장된 제목·태그로 일괄 재분류 가능하나 수동 지정 카테고리를 덮어쓸 위험이 있어 보류.
3. **id 319 중복 정리** — 230(사용자 북마크)과 내용 중복인 검증용 레코드. 삭제 여부 사용자 결정 대기.
4. **staging/prod 포트 분리** — 배포 가이드의 장기 과제 유지 (3003=prod).

## 7. 관련 문서

- 설계: [`docs/plans/2026-07-12-urlf2-v3-design.md`](../plans/2026-07-12-urlf2-v3-design.md)
- 배포 계획: [`docs/deploy/urlf2-v3-deploy-plan.md`](../deploy/urlf2-v3-deploy-plan.md)
- 세션 기록: [`2026-07-13-v3-session-summary.md`](2026-07-13-v3-session-summary.md) · [`x-syndication-fix`](2026-07-13-x-syndication-fix.md) · [`youtube-timeout-fastfirst`](2026-07-13-youtube-timeout-fastfirst.md)
- 변경 이력: [`docs/CHANGELOG.md`](../CHANGELOG.md)
- 트러블슈팅: `CLAUDE.md` § 트러블슈팅 (고아 워커 / env.conf 이스케이프 / timeout)
