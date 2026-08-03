# FTS5 가상 테이블은 생성 시 섀도 테이블(_data/_idx/_content/_docsize/_config)을 자동으로 만든다.
# structure.sql 덤프에 섀도 DDL 이 남으면 스키마 로드 시 'table already exists' 로 실패하므로 덤프 후 제거한다.
Rake::Task["db:schema:dump"].enhance do
  Dir.glob(Rails.root.join("db/*structure.sql")).each do |file|
    sql = File.read(file)
    cleaned = sql.gsub(/^CREATE TABLE IF NOT EXISTS '\w+_fts_(data|idx|content|docsize|config)'.*\n/, "")
    File.write(file, cleaned) if cleaned != sql
  end
end
