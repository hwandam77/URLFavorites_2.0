# test/url_favorites/integrations/search/indexer_test.rb
require 'test_helper'
require 'webmock/minitest'

class UrlFavorites::Integrations::Search::IndexerTest < ActiveSupport::TestCase
  EMBEDDING_TEST_URL = "http://localhost:8080"

  def setup
    ENV["EMBEDDING_URL"] = EMBEDDING_TEST_URL
    WebMock.enable!
    WebMock.disable_net_connect!
    # EmbeddingService stub - nomic-embed-text 모델의 더미 임베딩 응답
    @embedding_response = { embedding: [0.1, 0.2, 0.3] * 384 }.to_json
    stub_request(:post, EMBEDDING_TEST_URL + "/v1/embeddings")
      .to_return(status: 200, body: @embedding_response, headers: { "Content-Type" => "application/json" })
  end

  def teardown
    ENV.delete("EMBEDDING_URL")
    WebMock.reset!
  end

  test "분석을 통해 FTS 테이블에 즐겨찾기를 색인합니다" do
    fav = Favorite.create!(
      title: "Rails Guide",
      url: "https://guides.rubyonrails.org",
      content_type: "webpage",
      status: "done"
    )
    Analysis.create!(
      favorite: fav,
      summary: "MVC framework guide",
      tags: ["rails"],
      key_points: []
    )
    UrlFavorites::Integrations::Search::Indexer.index(fav)

    row = ActiveRecord::Base.connection.execute(
      "SELECT * FROM favorites_fts WHERE favorite_id = #{fav.id}"
    ).first

    assert_not_nil row
    assert_equal "Rails Guide", row["title"]
    assert_includes row["summary"], "MVC"
  end

  test "분석 없이 즐겨찾기를 색인합니다 (nil summary/tags)" do
    fav = Favorite.create!(
      title: "Pending URL",
      url: "https://example.com",
      content_type: "webpage",
      status: "pending"
    )
    UrlFavorites::Integrations::Search::Indexer.index(fav)

    row = ActiveRecord::Base.connection.execute(
      "SELECT * FROM favorites_fts WHERE favorite_id = #{fav.id}"
    ).first

    assert_not_nil row
    assert_equal "Pending URL", row["title"]
  end

  test "재색인 시 기존 FTS 행을 업데이트합니다" do
    fav = Favorite.create!(
      title: "Old Title",
      url: "https://example.com/old",
      content_type: "webpage",
      status: "done"
    )
    UrlFavorites::Integrations::Search::Indexer.index(fav)

    fav.update!(title: "New Title")
    UrlFavorites::Integrations::Search::Indexer.index(fav)

    rows = ActiveRecord::Base.connection.execute(
      "SELECT * FROM favorites_fts WHERE favorite_id = #{fav.id}"
    ).to_a

    assert_equal 1, rows.count
    assert_equal "New Title", rows.first["title"]
  end

  test "즐겨찾기가 삭제될 때 FTS 행을 제거합니다" do
    fav = Favorite.create!(
      title: "To Delete",
      url: "https://example.com/del",
      content_type: "webpage",
      status: "done"
    )
    UrlFavorites::Integrations::Search::Indexer.index(fav)
    UrlFavorites::Integrations::Search::Indexer.remove(fav.id)

    row = ActiveRecord::Base.connection.execute(
      "SELECT * FROM favorites_fts WHERE favorite_id = #{fav.id}"
    ).first

    assert_nil row
  end

  test "reindex_all 은 모든 즐겨찾기를 색인합니다" do
    Favorite.create!(title: "A", url: "https://a.com", content_type: "webpage", status: "done")
    Favorite.create!(title: "B", url: "https://b.com", content_type: "webpage", status: "done")
    UrlFavorites::Integrations::Search::Indexer.reindex_all

    count = ActiveRecord::Base.connection.execute(
      "SELECT COUNT(*) as c FROM favorites_fts"
    ).first["c"]

    assert count >= 2
  end
end
