# URLFavorites v3.0 멀티 LLM 태스크 라우팅

- 날짜: 2026-07-12
- 범위: Feature 2 / Task A

## 서버 디스커버리

| 서버 | llama-server | 모델 | 용량 | 역할 |
|---|---|---|---|---|
| beacon (`10.10.0.4:8282`) | context 262,144, `-np 1` | Qwen3.6-35B-A3B Kimi K2.6 Reasoning Distilled IQ4_XS | 34.66B total / A3B MoE, GGUF 18.93GB, 2×RTX 3060 12GB | `fast` |
| synapse (`10.10.0.5:8282`) | context 131,072, `-np 1` | Qwen3.6-40B Deck Opus NEO CODE IQ4_XS | 39.07B dense, GGUF 22.07GB, 4×RTX 3070 8GB | `heavy` |

`/v1/models`, 리스닝 포트, 프로세스 인자와 GPU 구성을 직접 확인했다. 두 서버 모두 `-np 1`이고 모델 적재 후 GPU 메모리 여유가 작으므로 heavy 편중 시 OOM 위험을 늘리지 않도록 Solid Queue AI 동시성은 현행 2를 유지했다.

## 구현

- Domain `BackendRouter`가 긴 YouTube/Twitter 콘텐츠(6,000자 이상)와 상세 스타일을 `heavy → fast`, 그 외를 `fast → heavy`로 정렬한다.
- 기존 `LlamaServer::Client`의 순차 failover는 유지하고 role 정렬만 앞에 추가했다. role 미스매치나 라우팅 예외 시 기존 백엔드 순서를 그대로 사용한다.
- `RunAnalysis`가 캐시된 `raw_content.length`를 라우팅 힌트로 전달한다.
- 로컬 `.env`에 두 백엔드의 role과 fast 서버용 `EMBEDDING_URL`을 명시했다. 배포 systemd 설정은 변경하지 않았다.
- 프로젝트 문서가 지정한 로컬 LLM dispatch 경로(`/Users/hwandam/workspace/infrastructure/llm-orchestration`)는 머신에 없어 직접 구현으로 에스컬레이션했다.

## 검증

- `bundle exec rubocop -a`: 142 files, 자동수정 후 위반 0
- `bin/rails test`: 186 runs, 528 assertions, 0 failures, 0 errors, 0 skips
