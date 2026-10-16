# test/controllers/collections_controller_test.rb
require "test_helper"

class CollectionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    sign_in_as
  end

  test "GET /collections returns success" do
    get collections_url
    assert_response :success
  end

  test "GET /collections/:id shows collection with its favorites" do
    col = Collection.create!(name: "My Collection")
    fav = Favorite.create!(title: "In Collection", url: "https://example.com/col", content_type: "webpage", status: "done")
    CollectionMembership.create!(favorite: fav, collection: col)
    get collection_url(col)
    assert_response :success
    assert_includes response.body, "My Collection"
    assert_includes response.body, "In Collection"
  end

  test "POST /collections creates collection" do
    assert_difference "Collection.count", 1 do
      post collections_url, params: { collection: { name: "New Collection", description: "Test desc" } }
    end
    assert_redirected_to collection_url(Collection.last)
  end

  test "POST /collections with blank name fails" do
    assert_no_difference "Collection.count" do
      post collections_url, params: { collection: { name: "" } }
    end
  end

  test "PATCH /collections/:id updates collection" do
    col = Collection.create!(name: "Old Name")
    patch collection_url(col), params: { collection: { name: "New Name" } }
    assert_redirected_to collection_url(col)
    col.reload
    assert_equal "New Name", col.name
  end

  test "DELETE /collections/:id destroys collection" do
    col = Collection.create!(name: "Delete Me")
    assert_difference "Collection.count", -1 do
      delete collection_url(col)
    end
    assert_redirected_to collections_url
  end

  test "DELETE /collections/:id does not destroy associated favorites" do
    col = Collection.create!(name: "Has Favorites")
    fav = Favorite.create!(title: "Keep Me", url: "https://example.com/keep", content_type: "webpage", status: "done")
    CollectionMembership.create!(favorite: fav, collection: col)
    assert_no_difference "Favorite.count" do
      delete collection_url(col)
    end
  end

  test "PATCH /collections/:id with blank name returns unprocessable_entity" do
    col = Collection.create!(name: "Original Name")
    patch collection_url(col), params: { collection: { name: "" } }
    assert_response :unprocessable_entity
    assert_equal "Original Name", col.reload.name
  end

  test "collection create, update, and destroy invalidate sidebar_collections cache" do
    Rails.cache.write("sidebar_collections", [:cached])
    UrlFavorites::UseCases::Collections::CreateCollection.call(name: "Cache Test Col")
    assert_nil Rails.cache.read("sidebar_collections")

    col = Collection.create!(name: "Cache Target")
    Rails.cache.write("sidebar_collections", [:cached])
    UrlFavorites::UseCases::Collections::UpdateCollection.call(id: col.id, name: "Cache Target Updated")
    assert_nil Rails.cache.read("sidebar_collections")

    Rails.cache.write("sidebar_collections", [:cached])
    UrlFavorites::UseCases::Collections::DeleteCollection.call(id: col.id)
    assert_nil Rails.cache.read("sidebar_collections")
  end
end
