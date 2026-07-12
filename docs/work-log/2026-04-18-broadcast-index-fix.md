# 2026-04-18 분석/재분석 500 에러 수정 + 배포 스크립트 경로 수정

## 증상

1. URL 추가 후 AI 분석이 실행되지 않음 (상태가 pending/analyzing에 머무름)
2. 재분석 버튼 클릭 시 500 Internal Server Error
3. 사용자 추정: LLM 서버 문제

## 원인

**LLM 서버 문제가 아니었음.** SQLite `favorites` 테이블에 `id` 컬럼의 unique index가 누락되어 있었다.

### 에러 체인

```
ArgumentError: No unique index found for id
  app/models/favorite.rb:18:in 'block in <class:Favorite>'
  app/jobs/analyze_webpage_job.rb:39 / app/controllers/favorites_controller.rb:73
```

- `favorite.rb:18`은 `after_update_commit { broadcast_replace_to :favorites }` 콜백
- Rails 8.1 + sqlite3 2.9.2 환경에서 `broadcast_replace_to` 실행 시 내부적으로 `id` unique index 탐색
- `PRAGMA index_list('favorites')`에 `id` 관련 인덱스가 없어 `ArgumentError` 발생
- 결과: 모든 `update!` 호출(상태 변경)이 콜백 단계에서 실패

### 스키마 상태 (수정 전)

```sql
-- id 컬럼은 PRIMARY KEY AUTOINCREMENT지만 명시적 unique index 없음
PRAGMA index_list('favorites');
--> index_favorites_on_pinned   (non-unique)
--> index_favorites_on_category (non-unique)
--> index_favorites_on_url      (unique)
```

## 수정 내용

### 1. 마이그레이션: id unique index 추가

파일: `db/migrate/20260418000001_add_unique_index_on_favorites_id.rb`

```ruby
class AddUniqueIndexOnFavoritesId < ActiveRecord::Migration[8.1]
  def change
    add_index :favorites, :id, unique: true, if_not_exists: true
  end
end
```

커밋: `db44f59 fix: favorites 테이블 id unique index 추가`

### 2. 배포 스크립트 경로 수정

파일: `~/bin/deploy`

문제: rsync 대상이 `~/urlfavorites_2.0/`이었으나, systemd 서비스는 `~/services/rails/urlfavorites_2.0/`에서 실행 중

수정: 앱별 원격 경로 매핑 추가

```bash
case "$APP" in
  urlfavorites_2.0|URLFavorites_2.0)
    REMOTE_PATH="services/rails/urlfavorites_2.0"
    ;;
  yugoss|Yugoss)
    REMOTE_PATH="services/rails/yugoss"
    ;;
  closepilot|closepilot-web)
    REMOTE_PATH="services/closepilot"
    ;;
  *)
    REMOTE_PATH="$APP"
    ;;
esac
REMOTE=hwandam@vps-server:/home/hwandam/$REMOTE_PATH/
```

rsync 대상과 SSH heredoc 내 `cd` 경로 모두 `REMOTE_PATH` 사용하도록 변경.

## 검증 결과

| 항목 | 상태 |
|------|------|
| 마이그레이션 실행 | 성공 |
| `index_favorites_on_id` (unique) 생성 | 확인 |
| Rails 서비스 `active` | 확인 |
| LLM 서버 (Qwen3.6-35B @ 10.10.0.5:8282) | 정상 응답 |
| `POST /favorites/:id/retry` 500 에러 | 해결 (더 이상 500 아님) |
| 배포 스크립트 경로 | `~/services/rails/urlfavorites_2.0/`로 수정 완료 |
| quick deploy 검증 | 파일 정상 싱크 확인 |

## 2차 수정: SolidCable 테이블 누락

### 증상

unique index 추가 후에도 `broadcast_replace_to`에서 `ArgumentError: No unique index found for id` 발생.
실제 에러는 SolidCable의 `InsertAll.execute` → `find_unique_index_for`에서 발생.

### 원인

`solid_cable:install`이 `config/cable.yml`을 `solid_cable` 어댑터로 변경하고 `writing: cable` 연결을 요구했지만,
`config/database.yml`에 `cable` role이 정의되어 있지 않았음.
결과적으로 `solid_cable_messages` 테이블이 생성되지 않아 broadcast 시 테이블 미존재 에러 발생.

### 수정 내용

#### 1. database.yml에 cable role 추가

파일: `config/database.yml`

```yaml
development:
  cable:
    <<: *default
    database: storage/development.sqlite3

production:
  cable:
    <<: *default
    database: storage/production.sqlite3
```

커밋: `fa882f3 fix: database.yml에 cable role 추가 (SolidCable 연결 해결)`

#### 2. solid_cable_messages 테이블 직접 생성

```sql
CREATE TABLE IF NOT EXISTS solid_cable_messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  channel BLOB NOT NULL,
  payload BLOB NOT NULL,
  created_at DATETIME NOT NULL,
  channel_hash INTEGER NOT NULL
);
-- + 3개 인덱스 (channel, channel_hash, created_at)
```

### E2E 검증 결과

| 항목 | 결과 |
|------|------|
| favorite 121 (public-apis) 분석 | status: **done** |
| 요약 생성 | "공개 API 리포지토리는 커뮤니티와 APILayer가 수작업으로 관리하는..." |
| 태그 생성 | 공개 api, 개발자 도구, API 리포지토리, 무료 API 등 7개 |
| SolidCable broadcast | 에러 없이 정상 동작 |
| Puma 로그 | 에러 없음 |

## 참고

- 배포 스크립트 경로 매핑은 `docs/개발_환경_참조문서.md` §5-1 프로젝트 소스 vs 배포 표와 일치
- 전체 파이프라인 (스크래핑 → LLM 분석 → 상태 업데이트 → SolidCable broadcast) 정상 동작 확인
