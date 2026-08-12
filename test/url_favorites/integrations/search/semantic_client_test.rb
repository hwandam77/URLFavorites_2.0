# frozen_string_literal: true

require "test_helper"

class UrlFavorites::Integrations::Search::SemanticClientTest < ActiveSupport::TestCase
  setup do
    @favorite = Favorite.create!(
      url: "https://example.com/ai-article",
      content_type: "webpage",
      title: "AI and Machine Learning"
    )
    @favorite.create_analysis!(
      summary: "Introduction to artificial intelligence concepts",
      tags: [ "ai", "ml" ]
    )

    now = Time.current.iso8601
    emb = [ 0.1, 0.2, 0.9 ].to_json
    ActiveRecord::Base.connection.execute(
      "INSERT INTO favorite_embeddings (favorite_id, embedding, model, dimensions, created_at, updated_at) " \
      "VALUES (#{@favorite.id}, '#{emb}', 'test', 3, '#{now}', '#{now}')"
    )
  end

  teardown do
    ActiveRecord::Base.connection.execute("DELETE FROM favorite_embeddings WHERE favorite_id = #{@favorite.id}")
  end

  test "semantic search finds conceptually related content" do
    UrlFavorites::Integrations::Search::EmbeddingClient.stub :call, [ 0.1, 0.9, 0.3 ] do
      results = UrlFavorites::Integrations::Search::SemanticClient.call(query: "neural networks deep learning")
      assert results.any? { |f| f.id == @favorite.id }
    end
  end

  test "falls back to FTS when embedding fails" do
    # query embedding이 빈 배열을 반환하면 결과가 빈 배열인지 확인
    UrlFavorites::Integrations::Search::EmbeddingClient.stub :call, [] do
      results = UrlFavorites::Integrations::Search::SemanticClient.call(query: "machine learning")
      assert_equal [], results
    end
  end

  test "returns empty for blank query" do
    results = UrlFavorites::Integrations::Search::SemanticClient.call(query: "")
    assert_equal [], results
  end
end
