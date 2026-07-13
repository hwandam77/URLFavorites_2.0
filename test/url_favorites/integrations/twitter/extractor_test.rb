require "test_helper"
require "webmock/minitest"

class UrlFavorites::Integrations::Twitter::ExtractorTest < ActiveSupport::TestCase
  X_URL = "https://x.com/alice/status/123"
  PROFILE_URL = "https://x.com/alice"
  SYNDICATION_URL = "https://cdn.syndication.twimg.com/tweet-result"
  JINA_URL = "https://r.jina.ai/#{X_URL}"
  SYNDICATION_HEADERS = { "User-Agent" => /Mozilla\/5\.0/ }

  setup do
    WebMock.enable!
    WebMock.disable_net_connect!
  end

  teardown do
    WebMock.reset!
  end

  test "fetches an individual tweet through the syndication API" do
    stub_syndication(
      text: "첫 주장",
      user: { "name" => "Alice", "screen_name" => "alice" },
      quoted_tweet: { "text" => "인용된 근거" }
    )

    result = UrlFavorites::Integrations::Twitter::Extractor.call(X_URL)

    assert_equal "Alice (@alice)", result[:author]
    assert_includes result[:body_text], "첫 주장"
    assert_includes result[:body_text], "인용된 근거"
    assert_includes result[:title], "Alice (@alice)"
    assert_not result[:is_video]
    assert_nil result[:transcript]
    assert_includes result[:raw_content], "Author: Alice"
    assert_requested :get, SYNDICATION_URL, headers: SYNDICATION_HEADERS,
                     query: { id: "123", token: "a", lang: "en" }
    assert_not_requested :get, X_URL
  end

  test "falls back to Jina when syndication returns a non-success response" do
    stub_request(:get, SYNDICATION_URL)
      .with(query: { id: "123", token: "a", lang: "en" })
      .to_return(status: 403, body: "blocked")
    stub_jina("Alice (@alice) on X: Rails", "Jina fallback content")

    result = UrlFavorites::Integrations::Twitter::Extractor.call(X_URL)

    assert_equal "Alice", result[:author]
    assert_equal "Jina fallback content", result[:body_text]
    assert_requested :get, JINA_URL
  end

  test "falls back to Jina when syndication JSON cannot be parsed" do
    stub_request(:get, SYNDICATION_URL)
      .with(query: { id: "123", token: "a", lang: "en" })
      .to_return(status: 200, body: "not-json")
    stub_jina("Alice (@alice) on X: Rails", "Jina parse fallback")

    result = UrlFavorites::Integrations::Twitter::Extractor.call(X_URL)

    assert_equal "Jina parse fallback", result[:body_text]
    assert_requested :get, JINA_URL
  end

  test "uses Jina directly for a profile URL" do
    profile_jina_url = "https://r.jina.ai/#{PROFILE_URL}"
    stub_request(:get, profile_jina_url).to_return(
      status: 200,
      body: "Title: Alice (@alice)\nMarkdown Content:\nProfile posts"
    )

    result = UrlFavorites::Integrations::Twitter::Extractor.call(PROFILE_URL)

    assert_equal "Alice", result[:author]
    assert_equal "Profile posts", result[:body_text]
    assert_requested :get, profile_jina_url
    assert_not_requested :get, SYNDICATION_URL
  end

  test "extracts video metadata and manual captions from a syndicated tweet" do
    stub_syndication(
      text: "영상 트윗",
      user: { "name" => "Alice", "screen_name" => "alice" },
      mediaDetails: [ { "type" => "video", "media_url_https" => "https://pbs.twimg.com/video.jpg" } ]
    )
    metadata = {
      "title" => "X video demo",
      "uploader" => "Alice",
      "thumbnail" => "https://pbs.twimg.com/thumb.jpg",
      "subtitles" => { "ko" => [ { "start" => 0, "duration" => 2, "text" => "영상 자막" } ] },
      "automatic_captions" => {}
    }.to_json

    Open3.stub(:capture3, [ metadata, "", status(success: true) ]) do
      result = UrlFavorites::Integrations::Twitter::Extractor.call(X_URL)

      assert result[:is_video]
      assert_equal "X video demo", result[:title]
      assert_equal "https://pbs.twimg.com/thumb.jpg", result[:thumbnail_url]
      assert_equal "manual", result[:subtitle_source]
      assert_includes result[:transcript], "영상 자막"
      assert_includes result[:raw_content], "Video transcript:"
    end
  end

  test "keeps syndicated text when yt-dlp fails" do
    stub_syndication(
      text: "텍스트 설명",
      user: { "name" => "Alice", "screen_name" => "alice" },
      mediaDetails: [ { "type" => "video" } ]
    )

    Open3.stub(:capture3, [ "", "failed", status(success: false) ]) do
      result = UrlFavorites::Integrations::Twitter::Extractor.call(X_URL)

      assert result[:is_video]
      assert_nil result[:transcript]
      assert_includes result[:raw_content], "텍스트 설명"
    end
  end

  test "falls back to syndicated text when yt-dlp is unavailable" do
    stub_syndication(
      text: "텍스트 설명",
      user: { "name" => "Alice", "screen_name" => "alice" },
      mediaDetails: [ { "type" => "video" } ]
    )

    Open3.stub(:capture3, ->(*_args) { raise Errno::ENOENT }) do
      result = UrlFavorites::Integrations::Twitter::Extractor.call(X_URL)

      assert_nil result[:transcript]
      assert_includes result[:raw_content], "텍스트 설명"
    end
  end

  private

  def stub_syndication(payload)
    stub_request(:get, SYNDICATION_URL)
      .with(query: { id: "123", token: "a", lang: "en" }, headers: SYNDICATION_HEADERS)
      .to_return(status: 200, body: payload.to_json)
  end

  def stub_jina(title, content)
    stub_request(:get, JINA_URL).to_return(
      status: 200,
      body: "Title: #{title}\nMarkdown Content:\n#{content}"
    )
  end

  def status(success:)
    Object.new.tap { |value| value.define_singleton_method(:success?) { success } }
  end
end
