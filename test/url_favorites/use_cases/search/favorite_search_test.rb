# test/url_favorites/use_cases/search/favorite_search_test.rb
require "test_helper"
require "webmock/minitest"

class UrlFavorites::UseCases::Search::FavoriteSearchTest < ActiveSupport::TestCase
  EMBEDDING_TEST_URL = "http://localhost:8080"

  def setup
    ENV["EMBEDDING_URL"] = EMBEDDING_TEST_URL
    WebMock.enable!
    WebMock.disable_net_connect!
    # EmbeddingService stub
    @embedding_response = { embedding: [ 0.1, 0.2, 0.3 ] * 384 }.to_json
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
      tags: [ "ruby", "rails" ],
      key_points: [ "MVC", "ActiveRecord" ]
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
      tags: [ "python", "tutorial" ]
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

  def test_handles_c_plus_plus_query
    favorite = Favorite.create!(
      title: "C++ 메모리 관리",
      url: "https://example.com/cpp-memory",
      content_type: "webpage",
      status: "done"
    )
    UrlFavorites::Integrations::Search::Indexer.index(favorite)

    results = UrlFavorites::UseCases::Search::FavoriteSearch.call(query: "C++")

    assert_includes results.map(&:id), favorite.id
  end

  def test_handles_c_sharp_query
    assert_nothing_raised do
      UrlFavorites::UseCases::Search::FavoriteSearch.call(query: "C#")
    end
  end

  def test_handles_colon_query_as_implicit_and
    favorite = Favorite.create!(
      title: "foo xxx bar",
      url: "https://example.com/foo-xxx-bar",
      content_type: "webpage",
      status: "done"
    )
    UrlFavorites::Integrations::Search::Indexer.index(favorite)

    foo_only = Favorite.create!(
      title: "foo only",
      url: "https://example.com/foo-only",
      content_type: "webpage",
      status: "done"
    )
    UrlFavorites::Integrations::Search::Indexer.index(foo_only)

    results = UrlFavorites::UseCases::Search::FavoriteSearch.call(query: "foo:bar")

    assert_includes results.map(&:id), favorite.id
    refute_includes results.map(&:id), foo_only.id
  end

  def test_handles_fts_operator_keyword_query_as_implicit_and
    favorite = Favorite.create!(
      title: "foo xxx bar",
      url: "https://example.com/foo-xxx-bar",
      content_type: "webpage",
      status: "done"
    )
    UrlFavorites::Integrations::Search::Indexer.index(favorite)

    foo_only = Favorite.create!(
      title: "foo only",
      url: "https://example.com/foo-only",
      content_type: "webpage",
      status: "done"
    )
    UrlFavorites::Integrations::Search::Indexer.index(foo_only)

    results = nil
    assert_nothing_raised do
      results = UrlFavorites::UseCases::Search::FavoriteSearch.call(query: "foo AND bar")
    end

    assert_includes results.map(&:id), favorite.id
    refute_includes results.map(&:id), foo_only.id
  end

  def test_returns_empty_for_query_with_only_symbols
    results = nil
    UrlFavorites::Integrations::Search::SemanticClient.stub(:call, ->(*) { flunk "semantic fallback must not run" }) do
      results = UrlFavorites::UseCases::Search::FavoriteSearch.call(query: "+++")
    end

    assert_empty results
  end

  def test_returns_empty_for_query_with_only_fts_operator_keywords
    UrlFavorites::Integrations::Search::SemanticClient.stub(:call, ->(*) { flunk "semantic fallback must not run" }) do
      assert_empty UrlFavorites::UseCases::Search::FavoriteSearch.call(query: "AND")
      assert_empty UrlFavorites::UseCases::Search::FavoriteSearch.call(query: "AND OR NOT NEAR")
    end
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

  def test_filters_by_pinned_when_category_is_pin
    @fav1.update!(category: "AI에이전트", pinned: true)
    @fav2.update!(category: "백엔드", pinned: false)

    results = UrlFavorites::UseCases::Search::FavoriteSearch.call(query: nil, category: "핀")
    assert_includes results.map(&:id), @fav1.id
    refute_includes results.map(&:id), @fav2.id
  end

  def test_filters_by_collection_id
    collection = Collection.create!(name: "Test Collection")
    CollectionMembership.create!(favorite: @fav1, collection: collection)

    results = UrlFavorites::UseCases::Search::FavoriteSearch.call(query: nil, collection_id: collection.id.to_s)
    assert_includes results.map(&:id), @fav1.id
    refute_includes results.map(&:id), @fav2.id
  end
end
