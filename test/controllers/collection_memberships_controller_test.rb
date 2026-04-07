# test/controllers/collection_memberships_controller_test.rb
require 'test_helper'

class CollectionMembershipsControllerTest < ActionDispatch::IntegrationTest
  test "POST /favorites/:favorite_id/collection_membership adds to collection" do
    fav = Favorite.create!(title: "Member Test", url: "https://example.com/member", content_type: "webpage", status: "done")
    col = Collection.create!(name: "My Collection")
    assert_difference "CollectionMembership.count", 1 do
      post favorite_collection_membership_url(fav), params: { collection_membership: { collection_id: col.id } }
    end
    assert_redirected_to favorite_url(fav)
  end

  test "DELETE /favorites/:favorite_id/collection_membership removes from collection" do
    fav = Favorite.create!(title: "Remove Test", url: "https://example.com/remove", content_type: "webpage", status: "done")
    col = Collection.create!(name: "My Collection")
    CollectionMembership.create!(favorite: fav, collection: col)
    assert_difference "CollectionMembership.count", -1 do
      delete favorite_collection_membership_url(fav), params: { collection_membership: { collection_id: col.id } }
    end
    assert_redirected_to favorite_url(fav)
  end

  test "POST duplicate membership is rejected gracefully" do
    fav = Favorite.create!(title: "Dup Test", url: "https://example.com/dup", content_type: "webpage", status: "done")
    col = Collection.create!(name: "My Collection")
    CollectionMembership.create!(favorite: fav, collection: col)
    assert_no_difference "CollectionMembership.count" do
      post favorite_collection_membership_url(fav), params: { collection_membership: { collection_id: col.id } }
    end
  end
end
