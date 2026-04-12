# test/controllers/favorites_controller_test.rb
require 'test_helper'
require 'webmock/minitest'

class FavoritesControllerTest < ActionDispatch::IntegrationTest
  EMBEDDING_TEST_URL = "http://localhost:8080"

  def setup
    super
    ENV["EMBEDDING_URL"] = EMBEDDING_TEST_URL
    WebMock.enable!
    WebMock.disable_net_connect!
    @embedding_response = { embedding: [0.1, 0.2, 0.3] * 384 }.to_json
    stub_request(:post, EMBEDDING_TEST_URL + "/v1/embeddings")
      .to_return(status: 200, body: @embedding_response, headers: { "Content-Type" => "application/json" })
  end

  def teardown
    super
    ENV.delete("EMBEDDING_URL")
    WebMock.reset!
  end

  test "GET /favorites 성공을 반환합니다" do
    get favorites_url
    assert_response :success
  end

  test "GET /favorites 검색 쿼리로 결과를 필터링합니다" do
    fav = Favorite.create!(
      title: "Rails Guide",
      url: "https://guides.rubyonrails.org",
      content_type: "webpage",
      status: "done"
    )
    Analysis.create!(
      favorite: fav,
      summary: "Rails framework",
      tags: ["rails"],
      key_points: []
    )
    FavoriteSearchIndexer.reindex_all
    get favorites_url, params: { q: "Rails" }
    assert_response :success
    assert_includes response.body, "Rails Guide"
  end

  test "GET /favorites content_type 으로 필터링합니다" do
    Favorite.create!(
      title: "Web Page",
      url: "https://example.com",
      content_type: "webpage",
      status: "done"
    )
    Favorite.create!(
      title: "Video",
      url: "https://youtube.com/watch?v=x",
      content_type: "youtube",
      status: "done"
    )
    get favorites_url, params: { content_type: "youtube" }
    assert_response :success
    assert_includes response.body, "Video"
    refute_includes response.body, "Web Page"
  end

  test "POST /favorites 즐겨찾기를 생성하고 작업을 큐에 추가합니다" do
    assert_difference "Favorite.count", 1 do
      post favorites_url, params: { favorite: { url: "https://example.com/new" } }
    end
    assert_redirected_to favorites_url
    fav = Favorite.last
    assert_equal "pending", fav.status
  end

  test "POST /favorites 안전하지 않은 URL 을 거부합니다" do
    assert_no_difference "Favorite.count" do
      post favorites_url, params: { favorite: { url: "http://192.168.1.1/admin" } }
    end
  end

  test "GET /favorites/:id 즐겨찾기를 표시합니다" do
    fav = Favorite.create!(
      title: "Test",
      url: "https://example.com/show",
      content_type: "webpage",
      status: "done"
    )
    get favorite_url(fav)
    assert_response :success
    assert_includes response.body, "Test"
  end

  test "DELETE /favorites/:id 즐겨찾기를 삭제합니다" do
    fav = Favorite.create!(
      title: "Delete Me",
      url: "https://example.com/del",
      content_type: "webpage",
      status: "done"
    )
    assert_difference "Favorite.count", -1 do
      delete favorite_url(fav)
    end
    assert_redirected_to favorites_url
  end

  test "POST /favorites/:id/retry 실패한 즐겨찾기를 다시 큐에 추가합니다" do
    fav = Favorite.create!(
      title: "Failed",
      url: "https://example.com/fail",
      content_type: "webpage",
      status: "failed"
    )
    post retry_favorite_url(fav)
    assert_redirected_to favorite_url(fav)
    fav.reload
    assert_equal "pending", fav.status
  end
end
