require "test_helper"

class UrlFavorites::Domain::Tags::LearningTest < ActiveSupport::TestCase
  def setup
    @favorite = Favorite.create!(url: "https://example.com/article", content_type: "webpage", status: "done")
    @favorite.create_analysis!(tags: [ "tech", "news" ], summary: "Test")
  end

  test "suggest_tags returns tags from similar corrections" do
    similar = Favorite.create!(url: "https://example.com/blog/post", content_type: "webpage", status: "done")
    similar.create_analysis!(tags: [ "tech" ], summary: "Test")

    TagFeedback.create!(
      favorite: similar,
      original_tags: [ "tech" ],
      corrected_tags: [ "technology", "programming" ]
    )

    suggestions = UrlFavorites::Domain::Tags::Learning.suggest_tags(favorite_id: @favorite.id)

    assert_includes suggestions, "technology"
    assert_includes suggestions, "programming"
    refute_includes suggestions, "tech"
  end

  test "suggest_tags returns empty for no corrections" do
    suggestions = UrlFavorites::Domain::Tags::Learning.suggest_tags(favorite_id: @favorite.id)
    assert_equal [], suggestions
  end

  test "suggest_tags excludes current tags from suggestions" do
    similar = Favorite.create!(url: "https://example.com/blog/post", content_type: "webpage", status: "done")
    similar.create_analysis!(tags: [ "tech" ], summary: "Test")

    TagFeedback.create!(
      favorite: similar,
      original_tags: [ "tech" ],
      corrected_tags: [ "tech", "programming" ]
    )

    suggestions = UrlFavorites::Domain::Tags::Learning.suggest_tags(favorite_id: @favorite.id)
    refute_includes suggestions, "tech"
    assert_includes suggestions, "programming"
  end

  test "call returns tag statistics" do
    TagFeedback.create!(
      favorite: @favorite,
      original_tags: [ "tech" ],
      corrected_tags: [ "technology", "programming" ]
    )

    stats = UrlFavorites::Domain::Tags::Learning.call

    assert_equal 1, stats[:total_corrections]
    assert_equal 1, stats[:unique_favorites]
    assert_equal 1, stats[:popular_additions]["technology"]
    assert_equal 1, stats[:popular_additions]["programming"]
    assert_equal 1, stats[:popular_removals]["tech"]
  end
end
