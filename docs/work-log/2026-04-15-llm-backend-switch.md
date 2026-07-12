# LLM 백엔드 서버 변경

**날짜**: 2026-04-15
**프로젝트**: URLFavorites_2.0

---

## 변경 사항

LLM 백엔드를 beacon 서버에서 synapse 서버로 전환.

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| 서버 | beacon (100.99.181.122) | synapse (10.10.0.5) |
| 모델 | (beacon llama-server) | supergemma4-26b-uncensored-fast-v2 |
| 포트 | 8282 | 8282 (동일) |

## 작업 내역

1. synapse 서버 llama-server 상태 확인
   - 모델: `supergemma4-26b-uncensored-fast-v2-Q4_K_M.gguf`
   - 포트: 8282, GPU 4장 분산 추론 (`-ts 6,9,9,8`)
2. VPS systemd drop-in 백업
   - `env.conf.backup.20260415`
3. `LLAMA_SERVER_URL` 변경
   - `http://100.99.181.122:8282` → `http://10.10.0.5:8282`
4. daemon-reload + 서비스 재시작
5. 서비스 정상 확인 (Puma active, Solid Queue 정상)
6. CLAUDE.md 문서 동기화

## 변경된 파일

| 파일 | 변경 내용 |
|------|----------|
| VPS: `/etc/systemd/system/rails-puma@urlfavorites_2.0.service.d/env.conf` | LLAMA_SERVER_URL 변경 |
| `CLAUDE.md` | systemd 환경변수 섹션 업데이트 |

## 검증

- `systemctl status rails-puma@urlfavorites_2.0` → active (running)
- Solid Queue worker/dispatcher/scheduler 모두 정상 시작
- Puma `http://0.0.0.0:3001` listening 확인

## 참고

- 백업 위치: VPS `/etc/systemd/system/rails-puma@urlfavorites_2.0.service.d/env.conf.backup.20260415`
- 롤백: 백업 파일 복원 후 `daemon-reload && systemctl restart`
