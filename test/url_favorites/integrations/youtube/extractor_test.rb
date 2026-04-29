require "test_helper"

class UrlFavorites::Integrations::Youtube::ExtractorTest < ActiveSupport::TestCase
  VALID_JSON = JSON.generate({
    "title" => "Test Video Title",
    "description" => "This is a test video description. Code: https://github.com/rails/rails",
    "subtitles" => {
      "en" => [
        { "duration" => 5.0, "start" => 0.0, "text" => "First subtitle line." },
        { "duration" => 4.0, "start" => 5.0, "text" => "Second subtitle line." }
      ]
    },
    "automatic_captions" => {}
  })

  NO_SUBTITLES_JSON = JSON.generate({
    "title" => "No Subtitles Video",
    "description" => "Fallback description.",
    "subtitles" => {},
    "automatic_captions" => {}
  })

  AUTO_CAPTIONS_JSON = JSON.generate({
    "title" => "Auto Captions Video",
    "description" => "Fallback description.",
    "subtitles" => {},
    "automatic_captions" => {
      "en" => [
        { "duration" => 3.0, "start" => 0.0, "text" => "Auto caption 1" },
        { "duration" => 3.0, "start" => 3.0, "text" => "Auto caption 2" }
      ]
    }
  })

  def ok_status
    s = Object.new
    s.define_singleton_method(:success?) { true }
    s
  end

  def fail_status
    s = Object.new
    s.define_singleton_method(:success?) { false }
    s
  end

  test "title과 description을 반환한다" do
    Open3.stub(:capture3, [ VALID_JSON, "", ok_status ]) do
      result = UrlFavorites::Integrations::Youtube::Extractor.call("https://youtube.com/watch?v=test")
      assert_equal "Test Video Title", result[:title]
      assert_equal "This is a test video description. Code: https://github.com/rails/rails", result[:description]
    end
  end

  test "description과 transcript에서 GitHub 링크를 추출한다" do
    json = JSON.generate({
      "title" => "Links",
      "description" => "Main repo https://github.com/basecamp/kamal.",
      "subtitles" => {
        "en" => [
          { "text" => "Also see https://github.com/hotwired/turbo#readme" }
        ]
      },
      "automatic_captions" => {}
    })

    Open3.stub(:capture3, [ json, "", ok_status ]) do
      result = UrlFavorites::Integrations::Youtube::Extractor.call("https://youtube.com/watch?v=links")

      assert_equal [
        "https://github.com/basecamp/kamal",
        "https://github.com/hotwired/turbo"
      ], result[:github_links]
    end
  end

  test "subtitles 가 있으면 자막을 transcript 로 사용" do
    Open3.stub(:capture3, [ VALID_JSON, "", ok_status ]) do
      result = UrlFavorites::Integrations::Youtube::Extractor.call("https://youtube.com/watch?v=test")
      assert_includes result[:transcript], "First subtitle line"
    end
  end

  test "subtitles 타임스탬프를 transcript_segments 로 반환한다" do
    Open3.stub(:capture3, [ VALID_JSON, "", ok_status ]) do
      result = UrlFavorites::Integrations::Youtube::Extractor.call("https://youtube.com/watch?v=test")

      assert_equal 2, result[:transcript_segments].size
      assert_equal 0.0, result[:transcript_segments].first[:start]
      assert_equal "00:00", result[:transcript_segments].first[:timestamp]
      assert_equal "First subtitle line.", result[:transcript_segments].first[:text]
      assert_equal "00:05", result[:transcript_segments].second[:timestamp]
    end
  end

  test "subtitles 없으면 automatic_captions fallback" do
    Open3.stub(:capture3, [ AUTO_CAPTIONS_JSON, "", ok_status ]) do
      result = UrlFavorites::Integrations::Youtube::Extractor.call("https://youtube.com/watch?v=auto")
      assert_includes result[:transcript], "Auto caption 1"
      assert_equal "00:03", result[:transcript_segments].second[:timestamp]
    end
  end

  test "자막 없으면 description 을 transcript 로 사용" do
    Open3.stub(:capture3, [ NO_SUBTITLES_JSON, "", ok_status ]) do
      result = UrlFavorites::Integrations::Youtube::Extractor.call("https://youtube.com/watch?v=nodesc")
      assert_includes result[:transcript], "Fallback description"
      assert_empty result[:transcript_segments]
    end
  end

  test "transcript 는 12,000 자를 초과하지 않는다" do
    long_json = JSON.generate({
      "title" => "Long", "description" => "x" * 20_000,
      "subtitles" => {}, "automatic_captions" => {}
    })

    Open3.stub(:capture3, [ long_json, "", ok_status ]) do
      result = UrlFavorites::Integrations::Youtube::Extractor.call("https://youtube.com/watch?v=long")
      assert result[:transcript].length <= 12_000
    end
  end

  test "exit 실패 시 ExtractionError 발생" do
    Open3.stub(:capture3, [ "", "error", fail_status ]) do
      assert_raises(UrlFavorites::Integrations::Youtube::Extractor::ExtractionError) do
        UrlFavorites::Integrations::Youtube::Extractor.call("https://youtube.com/watch?v=fail")
      end
    end
  end

  test "JSON 파싱 실패 시 ExtractionError 발생" do
    Open3.stub(:capture3, [ "{ invalid }", "", ok_status ]) do
      assert_raises(UrlFavorites::Integrations::Youtube::Extractor::ExtractionError) do
        UrlFavorites::Integrations::Youtube::Extractor.call("https://youtube.com/watch?v=badjson")
      end
    end
  end
end
