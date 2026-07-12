# test/system/collections_flow_test.rb
require "application_system_test_case"

class CollectionsFlowTest < ApplicationSystemTestCase
  def setup
    sign_in_as
  end

  test "visiting the collections index page" do
    visit collections_url
    assert_selector "h1", text: "컬렉션"
    assert_text "관련 북마크를 그룹으로 관리합니다"
  end

  test "creating a new collection" do
    visit collections_url

    fill_in "collection[name]", with: "My System Test Collection"
    click_on "만들기"

    assert_text "My System Test Collection"
    assert_text "0개"
  end

  test "viewing a collection with its favorites" do
    col = Collection.create!(name: "System Test View Collection")
    fav = Favorite.create!(
      title: "In System Test Collection",
      url: "https://example.com/system-test-col-view",
      content_type: "webpage",
      status: "done"
    )
    CollectionMembership.create!(favorite: fav, collection: col)

    visit collection_url(col)

    assert_text "System Test View Collection"
    assert_text "1개 콘텐츠"
    assert_text "In System Test Collection"
  end

  test "deleting a collection" do
    Collection.create!(name: "Collection To Delete")

    visit collections_url
    assert_text "Collection To Delete"

    click_on "삭제", match: :first

    assert_no_text "Collection To Delete"
  end

  test "empty collections index shows empty state message" do
    Collection.delete_all

    visit collections_url

    assert_text "컬렉션이 없습니다"
  end
end
