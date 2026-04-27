# test/system/favorites_flow_test.rb
require "application_system_test_case"

class FavoritesFlowTest < ApplicationSystemTestCase
  def setup
    Favorite.where("url LIKE ?", "%example.com/system-test%").destroy_all
  end

  def teardown
    Favorite.where("url LIKE ?", "%example.com/system-test%").destroy_all
  end

  test "visiting the favorites index page" do
    visit favorites_url

    assert_selector "h1", text: "Bookmarks"
    assert_text "개의 URL이 보관됨"
  end

  test "adding a new favorite via form" do
    visit favorites_url

    within "#url-form" do
      fill_in "favorite[url]", with: "https://example.com/system-test-add"
    end
    click_on "추가하기"

    assert_text "URL이 저장되었습니다"
    assert_text "example.com"
  end

  test "visiting a favorite detail page" do
    fav = Favorite.create!(
      title: "System Test Favorite Detail",
      url: "https://example.com/system-test-detail",
      content_type: "webpage",
      status: "done"
    )
    fav.create_analysis!(summary: "This is a system test favorite summary", tags: ["test", "system"])

    visit favorite_url(fav)

    assert_text "System Test Favorite Detail"
    assert_text "example.com"
    assert_text "This is a system test favorite summary"
    assert_text "test"
  end

  test "deleting a favorite" do
    fav = Favorite.create!(
      title: "System Test Favorite Delete",
      url: "https://example.com/system-test-delete",
      content_type: "webpage",
      status: "done"
    )

    visit favorite_url(fav)
    click_on "삭제"

    assert_text "Deleted"
  end

  test "empty index shows empty state" do
    Favorite.delete_all
    Analysis.delete_all

    visit favorites_url

    assert_text "아직 북마크가 없습니다"
  end
end
