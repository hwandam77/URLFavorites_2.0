require "test_helper"

class UrlTypeDetectorTest < ActiveSupport::TestCase
  test "youtube.com watch URL은 youtube" do
    assert_equal "youtube", UrlTypeDetector.call("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
  end

  test "youtu.be 단축 URL은 youtube" do
    assert_equal "youtube", UrlTypeDetector.call("https://youtu.be/dQw4w9WgXcQ")
  end

  test "youtube.com shorts URL은 youtube" do
    assert_equal "youtube", UrlTypeDetector.call("https://www.youtube.com/shorts/abc123")
  end

  test "일반 웹사이트는 webpage" do
    assert_equal "webpage", UrlTypeDetector.call("https://example.com")
  end

  test "github URL은 webpage" do
    assert_equal "webpage", UrlTypeDetector.call("https://github.com/rails/rails")
  end
end
