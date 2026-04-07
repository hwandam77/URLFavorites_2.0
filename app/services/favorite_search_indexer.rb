# app/services/favorite_search_indexer.rb
class FavoriteSearchIndexer
  # favorites_fts 가상 테이블을 위한 FTS5 인덱스 관리
  # favorites_fts 열: favorite_id INTEGER, title TEXT, summary TEXT, tags TEXT, note TEXT

  # 단일 즐겨찾기를 인덱싱하거나 재인덱싱
  def self.index(favorite)
    analysis = favorite.analysis
    summary = analysis&.summary
    tags = analysis&.tags&.join(" ")
    note = favorite.respond_to?(:note) ? favorite.note : nil

    conn = ActiveRecord::Base.connection

    # 먼저 기존 행을 삭제 (delete+insert 를 통한 upsert)
    conn.execute("DELETE FROM favorites_fts WHERE favorite_id = #{favorite.id}")

    # 새 행 삽입
    conn.execute(
      ActiveRecord::Base.send(:sanitize_sql_array, [
        "INSERT INTO favorites_fts (favorite_id, title, summary, tags, note) VALUES (?, ?, ?, ?, ?)",
        favorite.id, favorite.title, summary, tags, note
      ])
    )
  end

  # FTS 인덱스에서 즐겨찾기를 제거
  def self.remove(favorite_id)
    ActiveRecord::Base.connection.execute(
      "DELETE FROM favorites_fts WHERE favorite_id = #{favorite_id.to_i}"
    )
  end

  # 처음부터 FTS 인덱스를 다시 구축
  def self.reindex_all
    conn = ActiveRecord::Base.connection
    conn.execute("DELETE FROM favorites_fts")

    Favorite.includes(:analysis).find_each do |favorite|
      index(favorite)
    end
  end
end
