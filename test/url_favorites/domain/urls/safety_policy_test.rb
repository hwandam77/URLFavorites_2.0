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

  test "비표준 IP 표기 우회 차단" do
    [
      "http://0177.0.0.1/x",
      "http://012.0.0.1/x",
      "http://0/x",
      "http://00.0.0.0/x",
      "http://0300.0250.0001.0001/x",
      "http://127.0.0.1./x",
      "http://127.1/x",
      "http://0x7f000001/x",
      "http://2130706433/x",
      "http://[::ffff:10.0.0.1]/x"
    ].each do |url|
      assert_not UrlFavorites::Domain::Urls::SafetyPolicy.allowed?(url), url
    end
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
