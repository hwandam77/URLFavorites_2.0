# test/controllers/favorites_controller_test.rb
require "test_helper"
require "webmock/minitest"

class FavoritesControllerTest < ActionDispatch::IntegrationTest
  EMBEDDING_TEST_URL = "http://localhost:8080"

  def setup
    super
    ENV["EMBEDDING_URL"] = EMBEDDING_TEST_URL
    WebMock.enable!
    WebMock.disable_net_connect!
    @embedding_response = { embedding: [ 0.1, 0.2, 0.3 ] * 384 }.to_json
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
      tags: [ "rails" ],
      key_points: []
    )
    UrlFavorites::Integrations::Search::Indexer.reindex_all
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

  test "GET /favorites/:id 원본 링크 열기 버튼을 표시합니다" do
    fav = Favorite.create!(
      title: "Original Link",
      url: "https://example.com/original",
      content_type: "webpage",
      status: "done"
    )

    get favorite_url(fav)

    assert_response :success
    assert_select "a[href='https://example.com/original'][target='_blank']", text: /원본 링크 열기/
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
    assert_equal "analyzing", fav.status
  end

  test "GET /favorites/:id 재분석 버튼을 표시합니다" do
    fav = Favorite.create!(
      title: "Analyzed",
      url: "https://example.com/analyzed",
      content_type: "webpage",
      status: "done"
    )

    get favorite_url(fav)

    assert_response :success
    assert_select "form[action='#{reanalyze_favorite_path(fav)}'][method='post']", text: /재분석/
    assert_includes response.body, "turbo-cable-stream-source"
    assert_select "script[type='importmap']"
    assert_select "script[type='module']", text: /import "application"/
  end

  test "GET /favorites/:id 분석중이면 재분석 버튼 대신 분석중 상태를 표시합니다" do
    fav = Favorite.create!(
      title: "Analyzing",
      url: "https://example.com/analyzing",
      content_type: "webpage",
      status: "analyzing"
    )

    get favorite_url(fav)

    assert_response :success
    assert_select "button[disabled]", text: /분석중/
    assert_select "form[action='#{reanalyze_favorite_path(fav)}']", count: 0
  end

  test "POST /favorites/:id/reanalyze 완료된 즐겨찾기를 다시 큐에 추가합니다" do
    fav = Favorite.create!(
      title: "Done",
      url: "https://example.com/done",
      content_type: "webpage",
      status: "done",
      raw_content: "cached raw content"
    )

    post reanalyze_favorite_url(fav)

    assert_redirected_to favorite_url(fav)
    assert_equal "analyzing", fav.reload.status
    assert_equal "cached raw content", fav.raw_content
  end
end
