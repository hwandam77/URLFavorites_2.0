require "test_helper"
require "webmock/minitest"

class UrlFavorites::Integrations::Twitter::ExtractorTest < ActiveSupport::TestCase
  X_URL = "https://x.com/alice/status/123"
  JINA_URL = "https://r.jina.ai/#{X_URL}"

  setup do
    WebMock.enable!
    WebMock.disable_net_connect!
  end

  teardown do
    WebMock.reset!
  end

  test "fetches text thread directly through Jina" do
    stub_jina("Alice (@alice) on X: Rails", "Alice (@alice) 첫 주장 후속 트윗의 근거")

    result = UrlFavorites::Integrations::Twitter::Extractor.call(X_URL)

    assert_equal "Alice", result[:author]
    assert_includes result[:body_text], "후속 트윗의 근거"
    assert_not result[:is_video]
    assert_nil result[:transcript]
    assert_includes result[:raw_content], "Author: Alice"
    assert_requested :get, JINA_URL
    assert_not_requested :get, X_URL
  end

  test "extracts video metadata and manual captions with yt-dlp" do
    stub_jina("Alice (@alice) on X: Video", "Alice (@alice) [Video] 데모")
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

  test "falls back to Jina text when yt-dlp fails" do
    stub_jina("Alice (@alice) on X: Video", "Alice (@alice) [Video] 텍스트 설명")

    Open3.stub(:capture3, [ "", "failed", status(success: false) ]) do
      result = UrlFavorites::Integrations::Twitter::Extractor.call(X_URL)

      assert result[:is_video]
      assert_nil result[:transcript]
      assert_includes result[:raw_content], "텍스트 설명"
    end
  end

  test "falls back to Jina text when yt-dlp is unavailable" do
    stub_jina("Alice (@alice) on X: Video", "Alice (@alice) [Video] 텍스트 설명")

    Open3.stub(:capture3, ->(*_args) { raise Errno::ENOENT }) do
      result = UrlFavorites::Integrations::Twitter::Extractor.call(X_URL)

      assert_nil result[:transcript]
      assert_includes result[:raw_content], "텍스트 설명"
    end
  end

  private

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
