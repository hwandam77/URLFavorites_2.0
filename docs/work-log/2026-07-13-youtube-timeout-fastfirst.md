# 유튜브 분석 실패 진단 + fast-first 라우팅

**날짜**: 2026-07-13
**프로젝트**: URLFavorites_2.0
**커밋**: `8dcfe67` (fast-first 코드 변경)

---

## 배경 / 증상

"최근 입력한 유튜브 주소 분석이 실패" 신고. 운영 DB 확인 결과 실패 4건이 있었고,
유튜브 3건(309·196·235)이 **모두 동일 에러**:

```
LlamaServer::Client::ServerError: All LLM backends failed.
Last error: HTTP server error: Net::ReadTimeout with #<TCPSocket:(closed)>
```

## 근본 원인 (진단)

yt-dlp 추출 문제가 **아님**. **LLM 분석 단계의 read timeout**이 원인.

- 클라이언트 read timeout = **120초** (`LLM_BACKENDS timeout:120`)
- 유튜브는 긴 자막(~10k자)이라 `BackendRouter`가 **느린 heavy 40B 백엔드에 먼저** 라우팅
- 실측: 309 재실행 = **113.3초** (120초 경계 바로 아래) → 정상 생성이 이미 타임아웃 경계에 붙어
  서버 부하만 조금 걸려도 초과 → **간헐적 실패**
- github/twitter/webpage는 짧아 경계 근처도 안 감 → **유튜브만 실패**한 이유

`Net::ReadTimeout`은 Faraday에서 `Faraday::ServerError`(TimeoutError는 그 하위)로 잡혀
`"HTTP server error:"` 로 기록됨.

## 작업 내역

1. **원인 확정** — 실패 3건 재실행하며 시간 측정
   - 309: 113.3초 → done / 235: 149.6초 → done / 196: 87.7초 → done (전부 240초 내 완주)
   - 두 백엔드(`10.10.0.5` heavy 40B, `10.10.0.4` fast 35B-A3B) 헬스 정상 확인
2. **수정 A — timeout 120 → 240** (`LLM_BACKENDS`, systemd 드롭인)
   - 정상 생성 80~150초의 약 2배 여유 확보
3. **수정 B — env.conf JSON 이스케이프 회귀 발견·수정** (아래 별도 섹션)
4. **수정 C — 유튜브 fast-first 라우팅** (rails-core Spoke 위임 → 커밋 `8dcfe67`)
   - `BackendRouter.LONG_CONTENT_TYPES`: `%w[youtube twitter]` → `%w[twitter]`
   - 상세 스타일(detail/qna/tutorial/prompt_extract)은 heavy-first 유지 (깊은 분석 opt-in 보존)
   - 테스트 4/4 green, rubocop clean, `bin/deploy --quick` 배포 (deploy-doctor 통과)
5. **좀비 레코드 150 삭제** — trendshift 북마크가 status만 `analyzing`에 멈춰 있던 것
   - 사용자 확인 후 `favorite.destroy` (analysis + collection_memberships + FTS cascade)
6. **복구** — 309/235/196(youtube) + 317(github) 전부 done, 좀비 150 제거 → failed/analyzing 0건

## 수정 B — systemd `LLM_BACKENDS` 이스케이프 회귀 (중요)

`timeout` 상향 후 재시작하니 **모든 신규 분석이 실패**:
```
ParseError: Invalid LLM_BACKENDS JSON: expected object key, got 'url:http://...'
```

- 원인: env.conf의 `LLM_BACKENDS`가 평범한 `"` 사용 → **systemd가 큰따옴표를 quoting으로 해석해 제거**
  → 무효 JSON → `resolve_backends`가 `ParseError` → 전체 분석 실패
- 이 줄은 이전엔 restart가 없어 **dormant**였고(11:12 프로세스는 단일 `LLAMA_SERVER_URL`=fast .4로
  정상 동작 중이었음), timeout 수정 재시작이 이 깨진 설정을 **활성화**시킨 것
- 수정: 큰따옴표를 `\"`로 이스케이프 → `daemon-reload` + restart
- **검증**: `/proc/$MainPID/environ`(이스케이프 없는 실제 바이트) + Ruby `JSON.parse`로
  프로세스가 유효 JSON을 받는지 ground truth 확인 (`systemctl show`는 표시용 재이스케이프라 신뢰 불가)

## 라이브 검증 — fast-first 실제 동작 증거

새 유튜브(`watch?v=hzoL3ZulM9g`)를 실제 등록 경로(`CreateFavorite`)로 투입 → 라이브 Puma 워커 처리.
백엔드 `/slots` 관측:

| | fast (.4) | heavy (.5) |
|---|---|---|
| 분석 중 `is_processing` | **true (0~119초 내내)** | **false (전 구간)** |
| `id_task` before→after | 278459 → **284333 (증가)** | 32747 → **32747 (불변)** |

→ **fast 백엔드 단독 처리, heavy는 요청 0건.** favorite 318 done(retry 0), ~119초 소요.

## 변경된 파일

| 파일 | 변경 내용 |
|------|----------|
| `app/url_favorites/domain/analysis/backend_router.rb` | `LONG_CONTENT_TYPES`에서 youtube 제거 (fast-first) |
| `test/url_favorites/domain/analysis/backend_router_test.rb` | 유튜브 fast-first 테스트 + 상세스타일 heavy-first 테스트 |
| `CLAUDE.md` | systemd `LLM_BACKENDS` 이스케이프 함정·timeout 240 근거·트러블슈팅 2행 |
| VPS: `.../env.conf` | `LLM_BACKENDS` timeout 120→240 + 큰따옴표 `\"` 이스케이프 |

## 백엔드 성능 프로파일 (참고)

동일 유튜브 입력(309, ~4900 prompt tokens) 풀 생성 실측:

| 백엔드 | 시간 | completion 토큰 | 비고 |
|--------|------|-----------------|------|
| fast .4 (35B-A3B MoE) | ~79초 | 5,866 (reasoning 13k자) | 토큰/초 ~5배 빠름, 사고 많음 |
| heavy .5 (40B dense) | ~103초 | 1,416 (reasoning 2k자) | 느림, 사고 적음 |

fast는 `Reasoning-Distilled` 모델이라 답 이전 사고 토큰을 대량 생성 → fast-first의 시간 단축은
~24초로 크지 않으나 **처리량 여유가 커 타임아웃 마진이 크고 heavy 폴백 없이 완주**하는 게 핵심 이득.
신뢰성의 주역은 **timeout 240초**.

## 백업 / 롤백

- env.conf 백업: VPS `.../env.conf.bak.20260713-173815` (변경 전)
- SQLite 배포 백업: VPS `/home/hwandam/backups/urlfavorites_2.0/20260713-090610-8dcfe67`
- 코드 롤백: `git revert 8dcfe67` 후 `bin/deploy --quick`
- 설정 롤백: 백업 env.conf 복원 후 `daemon-reload && systemctl restart`
  (단 이스케이프 수정은 유지할 것 — 미이스케이프 버전은 다음 restart 때 전체 분석 실패)

## 다음 단계 (선택)

- `youtube/extractor.rb`가 yt-dlp `_stderr`를 버려 향후 추출 실패 시 원인이 안 남음 → stderr를
  `error_message`에 실으면 진단성 개선
