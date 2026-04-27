# frozen_string_literal: true

require "test_helper"

class UrlFavorites::Integrations::Search::SemanticClientTest < ActiveSupport::TestCase
  def setup
    @favorite = Favorite.create!(
      url: "https://example.com/ai-article",
      content_type: "webpage",
      title: "AI and Machine Learning"
    )
    @favorite.create_analysis!(
      summary: "Introduction to artificial intelligence concepts",
      tags: [ "ai", "ml" ]
    )

    # 수동으로 FTS에 인덱싱 (EmbeddingService 미호출)
    conn = ActiveRecord::Base.connection
    conn.execute(
      ActiveRecord::Base.send(:sanitize_sql_array, [
        "INSERT INTO favorites_fts (favorite_id, title, summary, tags, note, content_embedding) VALUES (?, ?, ?, ?, ?, ?)",
        @favorite.id, @favorite.title, "Introduction to artificial intelligence concepts", "ai ml", nil, [ 0.1, 0.2, 0.9 ].to_json
      ])
    )
  end

  test "semantic search finds conceptually related content" do
    # Mock embedding service to return similar vector
    UrlFavorites::Integrations::Search::EmbeddingClient.stub :call, [ 0.1, 0.9, 0.3 ] do
      results = UrlFavorites::Integrations::Search::SemanticClient.call(query: "neural networks deep learning")
      assert results.any? { |f| f.id == @favorite.id }
    end
  end

  test "falls back to FTS when embedding fails" do
    # embedding이 없을 때 FTS fallback 테스트
    conn = ActiveRecord::Base.connection
    conn.execute(ActiveRecord::Base.send(:sanitize_sql_array, [
      "DELETE FROM favorites_fts WHERE favorite_id = ?", @favorite.id
    ]))
    conn.execute(
      ActiveRecord::Base.send(:sanitize_sql_array, [
        "INSERT INTO favorites_fts (favorite_id, title, summary, tags, note, content_embedding) VALUES (?, ?, ?, ?, ?, ?)",
        @favorite.id, @favorite.title, "Introduction to artificial intelligence concepts", "ai ml", nil, nil
      ])
    )

    UrlFavorites::Integrations::Search::EmbeddingClient.stub :call, [] do
      results = UrlFavorites::Integrations::Search::SemanticClient.call(query: "machine learning")
      assert results.any? { |f| f.id == @favorite.id }
    end
  end

  test "returns empty for blank query" do
    results = UrlFavorites::Integrations::Search::SemanticClient.call(query: "")
    assert_equal [], results
  end
end
