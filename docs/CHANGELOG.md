# URLFavorites 2.0 변경 이력

| 날짜 | 변경 내용 | 대상 | 사유 |
|------|----------|------|------|
| 2026-04-07 | 초기 구성 — 4 에이전트 + 오케스트레이터 | 전체 | 하네스 신규 구축 |
| 2026-04-07 | GSD 통합 — .planning/ + ROADMAP 10 Phase | 전체 | GSD phase 관리 연결 |
| 2026-04-07 | tmux 2계층 병렬 — Claude Workers + Nexus LLM | 전체 에이전트 + 오케스트레이터 | Claude Workers + 30B/48B 코드 생성 조합 |
| 2026-04-10 | 배포 가이드 추가 — 서버 설정, 환경변수, 트러블슈팅 | CLAUDE.md | 첫 운영 배포 경험 문서화 |
| 2026-04-13 | Warm Archive 테마 전면 리디자인 | 전체 뷰 + 디자인 토큰 | Neo-Brutalist → Editorial Swiss |
| 2026-04-14 | UI 워크플로우 간소화 — 로컬 시각확인 제거 | CLAUDE.md | 로컬 빌드 후 서버 배포에서 바로 시각 확인 |
| 2026-04-15 | DDD 아키텍처 리팩토링 — app/services/ → app/url_favorites/ | 전체 백엔드 | 레이어 분리: Domain, Integrations, UseCases |
| 2026-04-16 | CSS 디자인 토큰 분리 — tokens.css, theme_controller 리팩토링 | 프론트엔드 | 다크/라이트 테마 구조화 |
| 2026-04-18 | PWA Share Target 구현 — manifest.json, share 액션, CSRF 예외 | PWA | 모바일 공유 타겟 등록 |
| 2026-04-27 | E2E 시스템 테스트 10개 추가 (전체 138개 통과) | 테스트 | favorites/collections flow, turbo-rails test config fix |
