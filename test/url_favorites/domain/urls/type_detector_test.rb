require "test_helper"

class UrlFavoritesDomainUrlsTypeDetectorTest < ActiveSupport::TestCase
  test "youtube.com watch URL은 youtube" do
    assert_equal "youtube", UrlFavorites::Domain::Urls::TypeDetector.call("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
  end

  test "youtu.be 단축 URL은 youtube" do
    assert_equal "youtube", UrlFavorites::Domain::Urls::TypeDetector.call("https://youtu.be/dQw4w9WgXcQ")
  end

  test "youtube.com shorts URL은 youtube" do
    assert_equal "youtube", UrlFavorites::Domain::Urls::TypeDetector.call("https://www.youtube.com/shorts/abc123")
  end

  test "일반 웹사이트는 webpage" do
    assert_equal "webpage", UrlFavorites::Domain::Urls::TypeDetector.call("https://example.com")
  end

  test "github URL은 github" do
    assert_equal "github", UrlFavorites::Domain::Urls::TypeDetector.call("https://github.com/rails/rails")
  end

  test "x.com 상태 URL은 twitter" do
    assert_equal "twitter", UrlFavorites::Domain::Urls::TypeDetector.call("https://x.com/rails/status/123")
  end

  test "twitter.com 프로필 URL은 twitter" do
    assert_equal "twitter", UrlFavorites::Domain::Urls::TypeDetector.call("https://twitter.com/rails")
  end

  test "mobile.twitter.com URL은 twitter" do
    assert_equal "twitter", UrlFavorites::Domain::Urls::TypeDetector.call("https://mobile.twitter.com/rails/status/123")
  end
end
