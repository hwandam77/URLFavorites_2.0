# URLFavorites 2.0 — Project Definition

## Vision
기존 `urlf.hwandam.kr`를 개선한 개인용 지식 아카이브 `urlf2.hwandam.kr`. URL 저장은 빠르게, 다시 찾기는 강하게, AI 분석 + 사용자 메모의 결합.

## Constraints
- 개인 전용 서비스 (멀티유저/공유 제외)
- Rails 8 모노리스 + SQLite + Solid Queue
- AI: Qwen3-30B via llama-server (WireGuard VPN)
- 배포: VPS via `deploy urlfavorites`
- 기존 urlf 데이터 1회 이관, 동기화 없음

## Decisions
- 프론트엔드: Hotwire (Turbo + Stimulus) + Tailwind CSS
- 검색: SQLite FTS5
- 상세 화면: 독립 페이지 (사이드 패널 X)
- 메모: favorites.note 단일 필드 (별도 모델 분리 X)
- 태그: analyses.tags JSON 유지 (초기), 필요시 정규화 확장

## Key References
- 설계 문서: `docs/plans/2026-04-07-urlf2-design.md`
- 구현 플랜: `docs/plans/2026-04-07-urlf2-implementation.md`
- 에이전트 지침: `AGENTS.md`
- 커스텀 에이전트: `.claude/agents/rails-{core,ui,test,qa}.md`
