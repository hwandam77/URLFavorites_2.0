require "test_helper"
require "webmock/minitest"

class UrlFavorites::Integrations::Webpage::ScraperTest < ActiveSupport::TestCase
  setup do
    WebMock.enable!
    WebMock.disable_net_connect!
  end

  teardown do
    WebMock.reset!
  end

  HTML_WITH_OG = <<~HTML
    <html>
      <head>
        <meta property="og:title" content="OG 제목" />
        <meta property="og:description" content="OG 설명입니다." />
        <meta property="og:image" content="https://example.com/image.jpg" />
      </head>
      <body>
        <article>
          <p>본문 내용 첫 번째 단락.</p>
          <p>본문 내용 두 번째 단락.</p>
        </article>
      </body>
    </html>
  HTML

  HTML_WITHOUT_OG = <<~HTML
    <html>
      <head>
        <title>일반 타이틀</title>
        <meta name="description" content="메타 설명" />
      </head>
      <body>
        <main>
          <p>메인 본문.</p>
        </main>
      </body>
    </html>
  HTML

  test "OG 태그가 있으면 og:title, og:description, og:image 반환" do
    stub_request(:get, "https://example.com/page")
      .to_return(status: 200, body: HTML_WITH_OG, headers: { "Content-Type" => "text/html" })

    result = UrlFavorites::Integrations::Webpage::Scraper.call("https://example.com/page")

    assert_equal "OG 제목", result[:title]
    assert_equal "OG 설명입니다.", result[:description]
    assert_equal "https://example.com/image.jpg", result[:og_image]
  end

  test "OG 태그 없으면 title 태그, meta description 사용" do
    stub_request(:get, "https://example.com/no-og")
      .to_return(status: 200, body: HTML_WITHOUT_OG, headers: { "Content-Type" => "text/html" })

    result = UrlFavorites::Integrations::Webpage::Scraper.call("https://example.com/no-og")

    assert_equal "일반 타이틀", result[:title]
    assert_equal "메타 설명", result[:description]
    assert_nil result[:og_image]
  end

  test "article 태그 내 본문을 추출한다" do
    stub_request(:get, "https://example.com/page")
      .to_return(status: 200, body: HTML_WITH_OG, headers: { "Content-Type" => "text/html" })

    result = UrlFavorites::Integrations::Webpage::Scraper.call("https://example.com/page")

    assert_includes result[:body_text], "본문 내용 첫 번째 단락"
    assert_includes result[:body_text], "본문 내용 두 번째 단락"
  end

  test "main 태그 내 본문을 추출한다" do
    stub_request(:get, "https://example.com/no-og")
      .to_return(status: 200, body: HTML_WITHOUT_OG, headers: { "Content-Type" => "text/html" })

    result = UrlFavorites::Integrations::Webpage::Scraper.call("https://example.com/no-og")

    assert_includes result[:body_text], "메인 본문"
  end

  test "body_text 는 8,000 자를 초과하지 않는다" do
    long_body = "<html><body><article><p>#{"가" * 10_000}</p></article></body></html>"
    stub_request(:get, "https://example.com/long")
      .to_return(status: 200, body: long_body, headers: { "Content-Type" => "text/html" })

    result = UrlFavorites::Integrations::Webpage::Scraper.call("https://example.com/long")

    assert result[:body_text].length <= 8_000
  end

  test "HTTP 오류 시 Scraper::FetchError 발생" do
    stub_request(:get, "https://example.com/error")
      .to_return(status: 500)

    assert_raises(UrlFavorites::Integrations::Webpage::Scraper::FetchError) do
      UrlFavorites::Integrations::Webpage::Scraper.call("https://example.com/error")
    end
  end

  test "네트워크 타임아웃 시 Scraper::FetchError 발생" do
    stub_request(:get, "https://example.com/timeout")
      .to_timeout

    assert_raises(UrlFavorites::Integrations::Webpage::Scraper::FetchError) do
      UrlFavorites::Integrations::Webpage::Scraper.call("https://example.com/timeout")
    end
  end
end
