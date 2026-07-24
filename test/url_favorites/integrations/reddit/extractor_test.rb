require "test_helper"

class UrlFavorites::Integrations::Reddit::ExtractorTest < ActiveSupport::TestCase
  COMMENTS_URL = "https://www.reddit.com/r/rails/comments/abc123/some_title/"
  SHORT_URL = "https://redd.it/xyz789"

  test "parses a normal rdt read JSON payload" do
    payload = {
      "title" => "Rails 8 출시 정리",
      "selftext" => "본문 내용",
      "author" => "alice",
      "comments" => [
        { "author" => "bob", "body" => "좋은 정리네요" },
        { "author" => "carol", "body" => "추가 의견" }
      ]
    }.to_json

    captured = nil
    runner = lambda do |*args|
      captured = args
      [ payload, "", status(success: true) ]
    end

    Open3.stub(:capture3, runner) do
      result = UrlFavorites::Integrations::Reddit::Extractor.call(COMMENTS_URL)

      assert_equal [ "rdt", "read", "abc123", "--json" ], captured
      assert_equal "Rails 8 출시 정리", result[:title]
      assert_equal "본문 내용", result[:body_text]
      assert_equal "alice", result[:author]
      assert_nil result[:thumbnail_url]
      assert_includes result[:raw_content], "Title: Rails 8 출시 정리"
      assert_includes result[:raw_content], "본문 내용"
      assert_includes result[:raw_content], "bob: 좋은 정리네요"
    end
  end

  test "extracts the post id from a comments URL with query string" do
    captured = nil
    runner = lambda do |*args|
      captured = args
      [ "{}", "", status(success: true) ]
    end

    Open3.stub(:capture3, runner) do
      UrlFavorites::Integrations::Reddit::Extractor.call("#{COMMENTS_URL}?sort=top&utm_source=share")
    end

    assert_equal [ "rdt", "read", "abc123", "--json" ], captured
  end

  test "extracts the post id from a redd.it short URL" do
    captured = nil
    runner = lambda do |*args|
      captured = args
      [ "{}", "", status(success: true) ]
    end

    Open3.stub(:capture3, runner) do
      UrlFavorites::Integrations::Reddit::Extractor.call("#{SHORT_URL}?ref=share")
    end

    assert_equal [ "rdt", "read", "xyz789", "--json" ], captured
  end

  test "raises ExtractionError when rdt is not installed" do
    Open3.stub(:capture3, ->(*_args) { raise Errno::ENOENT }) do
      error = assert_raises(UrlFavorites::Integrations::Reddit::Extractor::ExtractionError) do
        UrlFavorites::Integrations::Reddit::Extractor.call(COMMENTS_URL)
      end
      assert_includes error.message, "not installed"
    end
  end

  test "raises ExtractionError with stderr tail on abnormal exit" do
    Open3.stub(:capture3, [ "", "cookie expired", status(success: false) ]) do
      error = assert_raises(UrlFavorites::Integrations::Reddit::Extractor::ExtractionError) do
        UrlFavorites::Integrations::Reddit::Extractor.call(COMMENTS_URL)
      end
      assert_includes error.message, "cookie expired"
    end
  end

  test "raises ExtractionError on unparsable output" do
    Open3.stub(:capture3, [ "not-json", "", status(success: true) ]) do
      assert_raises(UrlFavorites::Integrations::Reddit::Extractor::ExtractionError) do
        UrlFavorites::Integrations::Reddit::Extractor.call(COMMENTS_URL)
      end
    end
  end

  test "survives unexpected JSON structure with unknown keys" do
    payload = { "weird_key" => "weird value" }.to_json

    Open3.stub(:capture3, [ payload, "", status(success: true) ]) do
      result = UrlFavorites::Integrations::Reddit::Extractor.call(COMMENTS_URL)

      assert_nil result[:title]
      assert_nil result[:body_text]
      assert_nil result[:author]
      assert_equal "", result[:raw_content]
    end
  end

  test "survives a top-level array payload by treating entries as comments" do
    payload = [ { "body" => "첫 댓글", "author" => "bob" }, "두번째 댓글" ].to_json

    Open3.stub(:capture3, [ payload, "", status(success: true) ]) do
      result = UrlFavorites::Integrations::Reddit::Extractor.call(COMMENTS_URL)

      assert_includes result[:raw_content], "bob: 첫 댓글"
      assert_includes result[:raw_content], "두번째 댓글"
    end
  end

  test "truncates raw_content at the limit" do
    payload = { "title" => "t", "selftext" => "가" * 20_000 }.to_json

    Open3.stub(:capture3, [ payload, "", status(success: true) ]) do
      result = UrlFavorites::Integrations::Reddit::Extractor.call(COMMENTS_URL)

      assert_operator result[:raw_content].length, :<=, UrlFavorites::Integrations::Reddit::Extractor::RAW_CONTENT_LIMIT
    end
  end

  private

  def status(success:)
    Object.new.tap { |value| value.define_singleton_method(:success?) { success } }
  end
end
