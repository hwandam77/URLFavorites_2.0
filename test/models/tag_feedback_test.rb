require "test_helper"

class TagFeedbackTest < ActiveSupport::TestCase
  def setup
    @favorite = Favorite.create!(url: "https://example.com/article", content_type: "webpage", status: "done")
    @favorite.create_analysis!(tags: ["tech", "news"], summary: "Test article")
  end

  test "tag_diff returns added and removed tags" do
    feedback = TagFeedback.create!(
      favorite: @favorite,
      original_tags: ["tech", "news"],
      corrected_tags: ["technology", "programming", "news"]
    )

    diff = feedback.tag_diff

    assert_includes diff[:added], "technology"
    assert_includes diff[:added], "programming"
    refute_includes diff[:added], "news"
    assert_includes diff[:removed], "tech"
    refute_includes diff[:removed], "news"
    assert_includes diff[:unchanged], "news"
  end

  test "validates presence of original_tags and corrected_tags" do
    feedback = TagFeedback.new(favorite: @favorite)

    assert_not feedback.save
    assert_includes feedback.errors[:original_tags], "can't be blank"
    assert_includes feedback.errors[:corrected_tags], "can't be blank"
  end

  test "validates uniqueness of favorite_id" do
    TagFeedback.create!(
      favorite: @favorite,
      original_tags: ["tech"],
      corrected_tags: ["technology"]
    )

    duplicate = TagFeedback.new(
      favorite: @favorite,
      original_tags: ["news"],
      corrected_tags: ["breaking-news"]
    )

    assert_not duplicate.save
    assert_includes duplicate.errors[:favorite_id], "has already been taken"
  end

  test "allows anonymous corrections without user" do
    feedback = TagFeedback.new(
      favorite: @favorite,
      original_tags: ["tech"],
      corrected_tags: ["technology"]
    )

    assert_difference "TagFeedback.count", 1 do
      feedback.save!
    end
  end
end
