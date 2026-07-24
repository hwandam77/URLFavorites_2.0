# 2단계 분석 운영 가이드 (fast → heavy refine)

## 흐름

1. **1차 (fast)**: `RunAnalysis` 가 `backend_role: "fast"` 로 분석 → `status: done`, `analysis_tier: fast`
2. **2차 (heavy)**: 정밀 대상이면 `RefineAnalysisJob` (`ai_refine` 큐) 발주 → Analysis 조용히 갱신 (`analysis_tier: heavy`)

정밀 대상: `DETAILED_STYLES` 이거나 `raw_content.length >= BackendRouter::LONG_CONTENT_THRESHOLD` (6000).

## 배포 후 필수 검증

### 1. supervisor 단일화 (이중 소비 방지)

bastion 에 `SOLID_QUEUE_IN_PUMA=1` (puma 내장) 과 별도 `solid-queue@urlfavorites_2.0` 가 **공존하면** 이중 소비·동시성 초과가 난다.

```bash
# 큐 DB 를 여는 supervisor 트리가 1개인지 확인
lsof storage/production_queue.sqlite3
# puma MainPID 와 다른 PPID=1 고아 solid-queue 가 있으면 kill
```

둘 중 하나만 켜 둔다. 현재 권장: puma 내장 Solid Queue (`SOLID_QUEUE_IN_PUMA=1`) 또는 별도 서비스 — 둘 다 아님.

### 2. queue.yml 배열 변경 영향

`queues: "default,search,..."` 콤마 문자열은 Solid Queue 1.4 에서 **단일 큐 이름**으로 취급되어 미소비 버그가 있었다. 배열 `[default, search, mailers, reindex]` / `[ai, ai_refine]` 로 고쳤다.

운영에서 default 등 큐 소비 주체가 바뀔 수 있다. 배포 후 잡 적체·처리 지연을 한 번 확인한다.

### 3. refine 동시성

`RefineAnalysisJob` 은 `limits_concurrency key: "refine_analysis", to: 1, duration: 30.minutes`.  
duration 은 **lock 획득 시점**부터 계산되며 절대 보장이 아니다. 30분 후 세마포어가 풀리면 동시 실행이 생길 수 있으므로 모니터링한다.

## 실패 계약

refine 실패 시 `favorite.status` / `error_message` 는 바꾸지 않는다. 잡 재시도(최대 3회, 30/60/120s) 소진 후 fast 결과 보존이 의도된 종착이다.
