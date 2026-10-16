require "test_helper"

class FavoriteTest < ActiveSupport::TestCase
  test "url이 없으면 invalid" do
    fav = Favorite.new(url: nil)
    assert_not fav.valid?
    assert_includes fav.errors[:url], "can't be blank"
  end

  test "url 중복이면 invalid" do
    Favorite.create!(url: "https://example.com", status: "pending", content_type: "webpage")
    fav = Favorite.new(url: "https://example.com")
    assert_not fav.valid?
    assert_includes fav.errors[:url], "has already been taken"
  end

  test "status 기본값은 pending" do
    fav = Favorite.new(url: "https://example.com")
    assert_equal "pending", fav.status
  end

  test "content_type은 webpage 또는 youtube만 허용" do
    fav = Favorite.new(url: "https://example.com", content_type: "invalid")
    assert_not fav.valid?
  end

  test "retry_count 기본값은 0" do
    fav = Favorite.create!(url: "https://example.com", content_type: "webpage")
    assert_equal 0, fav.retry_count
  end

  test "has_one :analysis — favorite 삭제 시 analysis 삭제" do
    fav = Favorite.create!(url: "https://example.com", content_type: "webpage")
    Analysis.create!(
      favorite: fav,
      summary: "test",
      tags: "[]",
      key_points: "[]",
      sentiment: "neutral",
      model_used: "test-model",
      analyzed_at: Time.current
    )
    assert_difference "Analysis.count", -1 do
      fav.destroy
    end
  end

  test "컬렉션과 has_many :through 연관관계" do
    fav = Favorite.create!(url: "https://example.com", content_type: "webpage")
    col = Collection.create!(name: "My Collection")
    CollectionMembership.create!(favorite: fav, collection: col)
    assert_includes fav.collections, col
  end

  test "note 필드에 긴 텍스트 허용" do
    fav = Favorite.new(url: "https://example.com", content_type: "webpage", note: "x" * 5_000)
    assert fav.valid?
  end

  test "detect_content_type은 도메인 TypeDetector에 위임하여 5종 타입을 판별한다" do
    assert_equal "youtube", Favorite.new(url: "https://www.youtube.com/watch?v=123", content_type: nil).detect_content_type
    assert_equal "github", Favorite.new(url: "https://github.com/rails/rails", content_type: nil).detect_content_type
    assert_equal "twitter", Favorite.new(url: "https://x.com/user/status/1", content_type: nil).detect_content_type
    assert_equal "reddit", Favorite.new(url: "https://www.reddit.com/r/ruby/comments/1/a", content_type: nil).detect_content_type
    assert_equal "webpage", Favorite.new(url: "https://example.com/article", content_type: nil).detect_content_type
  end
end

