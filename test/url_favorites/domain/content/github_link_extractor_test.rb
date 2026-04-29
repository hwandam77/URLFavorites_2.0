require "test_helper"

class UrlFavorites::Domain::Content::GithubLinkExtractorTest < ActiveSupport::TestCase
  test "GitHub 링크만 중복 제거해서 추출한다" do
    links = UrlFavorites::Domain::Content::GithubLinkExtractor.call(
      "Code: https://github.com/rails/rails and docs https://example.com",
      "Repo again https://github.com/rails/rails. gist: https://gist.github.com/user/abc123)"
    )

    assert_equal [
      "https://github.com/rails/rails",
      "https://gist.github.com/user/abc123"
    ], links
  end

  test "fragment와 문장 부호를 제거한다" do
    links = UrlFavorites::Domain::Content::GithubLinkExtractor.call(
      "See https://github.com/hotwired/turbo#readme, then continue"
    )

    assert_equal [ "https://github.com/hotwired/turbo" ], links
  end

  test "GitHub 링크가 없으면 빈 배열을 반환한다" do
    assert_empty UrlFavorites::Domain::Content::GithubLinkExtractor.call("https://example.com")
  end
end
