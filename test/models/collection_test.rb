require "test_helper"

class CollectionTest < ActiveSupport::TestCase
  test "name이 없으면 invalid" do
    col = Collection.new(name: nil)
    assert_not col.valid?
    assert_includes col.errors[:name], "can't be blank"
  end

  test "name 중복이면 invalid" do
    Collection.create!(name: "My Collection")
    col = Collection.new(name: "My Collection")
    assert_not col.valid?
  end

  test "has_many :favorites through :collection_memberships" do
    col = Collection.create!(name: "Test Collection")
    fav = Favorite.create!(url: "https://example.com", content_type: "webpage")
    CollectionMembership.create!(favorite: fav, collection: col)
    assert_includes col.favorites, fav
  end

  test "collection 삭제 시 memberships 삭제, favorites는 유지" do
    col = Collection.create!(name: "Test Collection")
    fav = Favorite.create!(url: "https://example.com", content_type: "webpage")
    CollectionMembership.create!(favorite: fav, collection: col)
    assert_difference "CollectionMembership.count", -1 do
      assert_no_difference "Favorite.count" do
        col.destroy
      end
    end
  end
end
