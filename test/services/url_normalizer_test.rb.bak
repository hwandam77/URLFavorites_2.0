require "test_helper"

class UrlNormalizerTest < ActiveSupport::TestCase
  test "스킴 없는 URL에 https:// 추가" do
    assert_equal "https://example.com", UrlNormalizer.call("example.com")
  end

  test "트레일링 슬래시 제거" do
    assert_equal "http://example.com", UrlNormalizer.call("http://example.com/")
  end

  test "UTM 파라미터 제거, 나머지 쿼리 유지" do
    result = UrlNormalizer.call("https://example.com?utm_source=google&utm_medium=cpc&q=rails")
    assert_equal "https://example.com?q=rails", result
  end

  test "스킴과 호스트를 소문자로 정규화" do
    assert_equal "https://example.com/Path", UrlNormalizer.call("HTTPS://EXAMPLE.COM/Path")
  end

  test "이미 정규화된 URL은 변경 없음" do
    url = "https://example.com/some/path?q=test"
    assert_equal url, UrlNormalizer.call(url)
  end

  test "nil 입력 시 ArgumentError" do
    assert_raises(ArgumentError) { UrlNormalizer.call(nil) }
  end

  test "빈 문자열 입력 시 ArgumentError" do
    assert_raises(ArgumentError) { UrlNormalizer.call("") }
  end
end
