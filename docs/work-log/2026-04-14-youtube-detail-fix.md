# 문제 해결 기록

**날짜**: 2026-04-14
**프로젝트**: URLFavorites_2.0

---

## 문제 1: detail_content 미저장

**현상**: YouTube 분석 후 detail_content가 저장되지 않음

**원인**: `AnalyzeYoutubeJob#perform`에서 `analysis_attrs`에 `detail_content` 누락

**해결**: `app/jobs/analyze_youtube_job.rb`에 `detail_content: analysis_result[:detail_content]` 추가

```ruby
analysis_attrs = {
  raw_content:     raw_content,
  summary:        analysis_result[:summary],
  key_points:     analysis_result[:key_points],
  tags:           analysis_result[:tags],
  sentiment:      analysis_result[:sentiment],
  detail_content: analysis_result[:detail_content],  # 추가됨
  subtitle_source: subtitle_source
}
```

---

## 문제 2: 403 Blocked hosts

**현상**: `https://urlf.hwandam.kr/ver2.0/favorites/1` 접속 시 403 오류

**원인**: `config.hosts`에 프로DUCTION_IP 미등록

**해결**: `config/environments/production.rb`의 `config.hosts`에 `210.99.0.35` 추가

```ruby
config.hosts = [
  "urlf.hwandam.kr", "210.99.0.35",
  "localhost", "127.0.0.1"
]
```

---

## 문제 3: Solid Queue 미실행 (production)

**현상**: Job이 Enqueued 되지만 실행되지 않음

**원인**: URLFavorites_2.0 전용 solid_queue worker가 미실행 상태

**해결**:
1. `solid_queue:install`로 queue_schema migration 확인
2. production 환경으로 worker 시작:

```bash
cd /home/hwandam/URLFavorites_2.0
RAILS_RELATIVE_URL_ROOT=/ver2.0 PORT=3001 RAILS_ENV=production \
LLAMA_SERVER_URL=http://100.99.181.122:8282 \
nohup ~/.rbenv/shims/bundle exec bin/jobs start > /tmp/solid_queue_prod.log 2>&1 &
```

**참고**: job 테이블은 `storage/production_queue.sqlite3`에 있음 (main DB와 별도)

---

## 문제 4: Puma 재시작 필요

**현상**: config.hosts 변경 후에도 403 지속

**원인**: Puma가 구 설정 그대로 실행 중

**해결**: systemd service restart

```bash
sudo systemctl restart rails-puma@URLFavorites_2.0
```

**현재 상태**: `active (running)` — 정상

---

## 확인 결과

| 항목 | 상태 |
|------|------|
| detail_content 저장 | 정상 (842자) |
| subtitle_source badge | 정상 (`자막: description`) |
| simple_format 단락 표시 | 정상 (`<p>` 태그) |
| YouTube 분석 Job | 정상 실행됨 |
| HTTP 200 응답 | 정상 |

---

## 관련 파일

- `app/jobs/analyze_youtube_job.rb` — detail_content 추가
- `config/environments/production.rb` — hosts/IP 추가
- systemd service: `rails-puma@URLFavorites_2.0.service`