require "test_helper"

class UrlFavoritesDomainUrlsSafetyPolicyTest < ActiveSupport::TestCase
  # 차단 케이스
  test "192.168.x.x 사설 IP 차단" do
    assert_not UrlFavorites::Domain::Urls::SafetyPolicy.allowed?("http://192.168.1.1")
  end

  test "10.x.x.x 사설 IP 차단" do
    assert_not UrlFavorites::Domain::Urls::SafetyPolicy.allowed?("http://10.0.0.1")
  end

  test "172.16-31.x.x 사설 IP 차단" do
    assert_not UrlFavorites::Domain::Urls::SafetyPolicy.allowed?("http://172.16.0.1")
  end

  test "127.0.0.1 loopback 차단" do
    assert_not UrlFavorites::Domain::Urls::SafetyPolicy.allowed?("http://127.0.0.1")
  end

  test "localhost 차단" do
    assert_not UrlFavorites::Domain::Urls::SafetyPolicy.allowed?("http://localhost")
  end

  test "IPv6 loopback 차단" do
    assert_not UrlFavorites::Domain::Urls::SafetyPolicy.allowed?("http://[::1]")
  end

  test "ftp 스킴 차단" do
    assert_not UrlFavorites::Domain::Urls::SafetyPolicy.allowed?("ftp://example.com")
  end

  test "file 스킴 차단" do
    assert_not UrlFavorites::Domain::Urls::SafetyPolicy.allowed?("file:///etc/passwd")
  end

  # 허용 케이스
  test "https URL 허용" do
    assert UrlFavorites::Domain::Urls::SafetyPolicy.allowed?("https://example.com")
  end

  test "http URL 허용" do
    assert UrlFavorites::Domain::Urls::SafetyPolicy.allowed?("http://example.com")
  end
end
