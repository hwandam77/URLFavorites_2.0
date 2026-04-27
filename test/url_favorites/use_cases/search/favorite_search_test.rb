# test/url_favorites/use_cases/search/favorite_search_test.rb
require 'test_helper'
require 'webmock/minitest'

class UrlFavorites::UseCases::Search::FavoriteSearchTest < ActiveSupport::TestCase
  EMBEDDING_TEST_URL = "http://localhost:8080"

  def setup
    ENV["EMBEDDING_URL"] = EMBEDDING_TEST_URL
    WebMock.enable!
    WebMock.disable_net_connect!
    # EmbeddingService stub
    @embedding_response = { embedding: [0.1, 0.2, 0.3] * 384 }.to_json
    stub_request(:post, EMBEDDING_TEST_URL + "/v1/embeddings")
      .to_return(status: 200, body: @embedding_response, headers: { "Content-Type" => "application/json" })

    # fav1 생성 및 관련 Analysis 생성
    @fav1 = Favorite.create!(
      title: "Ruby on Rails Guide",
      url: "https://guides.rubyonrails.org",
      content_type: "webpage",
      status: "done"
    )
    Analysis.create!(
      favorite: @fav1,
      summary: "Rails MVC framework",
      tags: ["ruby", "rails"],
      key_points: ["MVC", "ActiveRecord"]
    )

    # fav2 생성 및 관련 Analysis 생성
    @fav2 = Favorite.create!(
      title: "Python Tutorial",
      url: "https://docs.python.org",
      content_type: "webpage",
      status: "done"
    )
    Analysis.create!(
      favorite: @fav2,
      summary: "Python programming language",
      tags: ["python", "tutorial"]
    )

    # Analysis 없이 fav3 생성
    @fav3 = Favorite.create!(
      title: "YouTube Video",
      url: "https://youtube.com/watch?v=abc",
      content_type: "youtube",
      status: "pending"
    )

    # 모두 FTS에 인덱싱
    UrlFavorites::Integrations::Search::Indexer.reindex_all
  end

  def teardown
    ENV.delete("EMBEDDING_URL")
    WebMock.reset!
  end

  def test_returns_favorites_matching_title_keyword
    results = UrlFavorites::UseCases::Search::FavoriteSearch.call(query: "Rails")
    assert_includes results.map(&:id), @fav1.id
    refute_includes results.map(&:id), @fav2.id
  end

  def test_returns_favorites_matching_summary_keyword
    results = UrlFavorites::UseCases::Search::FavoriteSearch.call(query: "framework")
    assert_includes results.map(&:id), @fav1.id
  end

  def test_returns_favorites_matching_tags
    results = UrlFavorites::UseCases::Search::FavoriteSearch.call(query: "python")
    assert_includes results.map(&:id), @fav2.id
    refute_includes results.map(&:id), @fav1.id
  end

  def test_filters_by_content_type
    results = UrlFavorites::UseCases::Search::FavoriteSearch.call(query: nil, content_type: "youtube")
    assert_includes results.map(&:id), @fav3.id
    refute_includes results.map(&:id), @fav1.id
  end

  def test_filters_by_status
    results = UrlFavorites::UseCases::Search::FavoriteSearch.call(query: nil, status: "pending")
    assert_includes results.map(&:id), @fav3.id
    refute_includes results.map(&:id), @fav1.id
  end

  def test_returns_all_when_query_is_blank_and_no_filters
    results = UrlFavorites::UseCases::Search::FavoriteSearch.call(query: nil)
    assert_equal 3, results.count
  end

  def test_returns_empty_when_no_match
    results = UrlFavorites::UseCases::Search::FavoriteSearch.call(query: "nonexistent_xyz_999")
    assert_empty results
  end
end
