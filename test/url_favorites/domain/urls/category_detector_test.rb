require "test_helper"

class UrlFavoritesDomainUrlsCategoryDetectorTest < ActiveSupport::TestCase
  test "blank/invalid URL은 기타" do
    assert_equal "기타", UrlFavorites::Domain::Urls::CategoryDetector.call("")
    assert_equal "기타", UrlFavorites::Domain::Urls::CategoryDetector.call("not a url")
  end

  test "youtube URL 기본 카테고리는 튜토리얼" do
    assert_equal "튜토리얼", UrlFavorites::Domain::Urls::CategoryDetector.call("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
  end
end
