require "test_helper"

class UrlFavorites::Domain::Analysis::BackendRouterTest < ActiveSupport::TestCase
  test "routes youtube content to fast first" do
    roles = UrlFavorites::Domain::Analysis::BackendRouter.call(
      content_type: "youtube",
      content_length: 6_000
    )

    assert_equal %w[fast heavy], roles
  end

  test "routes detailed-style youtube to heavy first" do
    roles = UrlFavorites::Domain::Analysis::BackendRouter.call(
      content_type: "youtube",
      content_length: 12_000,
      analysis_style: "detail"
    )

    assert_equal %w[heavy fast], roles
  end

  test "routes short webpage content to fast first" do
    roles = UrlFavorites::Domain::Analysis::BackendRouter.call(
      content_type: "webpage",
      content_length: 2_000
    )

    assert_equal %w[fast heavy], roles
  end

  test "routes detailed analysis to heavy first" do
    roles = UrlFavorites::Domain::Analysis::BackendRouter.call(
      content_type: "webpage",
      content_length: 2_000,
      analysis_style: "tutorial"
    )

    assert_equal %w[heavy fast], roles
  end
end
