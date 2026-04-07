require "test_helper"

class CollectionMembershipTest < ActiveSupport::TestCase
  def setup
    @favorite = Favorite.create!(url: "https://example.com", content_type: "webpage")
    @collection = Collection.create!(name: "Test Collection")
  end

  test "favorite + collection 조합이 중복이면 invalid" do
    CollectionMembership.create!(favorite: @favorite, collection: @collection)
    dup = CollectionMembership.new(favorite: @favorite, collection: @collection)
    assert_not dup.valid?
  end

  test "belongs_to :favorite" do
    membership = CollectionMembership.create!(favorite: @favorite, collection: @collection)
    assert_equal @favorite, membership.favorite
  end

  test "belongs_to :collection" do
    membership = CollectionMembership.create!(favorite: @favorite, collection: @collection)
    assert_equal @collection, membership.collection
  end
end
