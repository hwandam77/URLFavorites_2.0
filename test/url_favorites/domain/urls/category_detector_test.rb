require "test_helper"

class UrlFavoritesDomainUrlsCategoryDetectorTest < ActiveSupport::TestCase
  test "blank/invalid URL은 기타" do
    assert_equal "기타", UrlFavorites::Domain::Urls::CategoryDetector.call("")
    assert_equal "기타", UrlFavorites::Domain::Urls::CategoryDetector.call("not a url")
  end

  test "youtube URL 기본 카테고리는 튜토리얼" do
    assert_equal "튜토리얼", UrlFavorites::Domain::Urls::CategoryDetector.call("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
  end

  test "twitter content type은 뉴스" do
    assert_equal "뉴스", UrlFavorites::Domain::Urls::CategoryDetector.call("https://x.com/example", "twitter")
  end

  test "키워드 없는 블로그 URL은 text 없이는 기타" do
    assert_equal "기타", UrlFavorites::Domain::Urls::CategoryDetector.call("https://goddaehee.tistory.com/601", "webpage")
  end

  test "text(제목·태그)로 내용 기반 분류한다" do
    assert_equal "AI코딩", UrlFavorites::Domain::Urls::CategoryDetector.call(
      "https://goddaehee.tistory.com/601", "webpage",
      text: "Codex CLI 입문(6) : Codex 자동화 파이프라인 구축 codex-cli automation code-review"
    )
  end
end
