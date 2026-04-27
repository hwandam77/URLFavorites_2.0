# test/controllers/collections_controller_test.rb
require "test_helper"

class CollectionsControllerTest < ActionDispatch::IntegrationTest
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
end
