require "test_helper"

class AnalyzeTwitterJobTest < ActiveSupport::TestCase
  setup do
    @favorite = Favorite.create!(
      url: "https://x.com/alice/status/123",
      title: "https://x.com/alice/status/123",
      status: "pending",
      content_type: "twitter"
    )
    @extraction = {
      title: "Alice on X",
      body_text: "첫 주장과 후속 근거",
      author: "Alice",
      thumbnail_url: "https://pbs.twimg.com/thumb.jpg",
      is_video: true,
      transcript: "영상 자막",
      subtitle_source: "manual",
      transcript_segments: [],
      raw_content: "Title: Alice on X\n\nAuthor: Alice\n\nPost / thread:\n첫 주장과 후속 근거\n\nVideo transcript:\n영상 자막"
    }
    @analysis = {
      summary: "X 스레드 요약",
      key_points: [ "핵심 주장" ],
      tags: [ "twitter" ],
      sentiment: "neutral"
    }
  end

  test "extracts Twitter content and delegates analysis with length hint" do
    analyzer = lambda do |content, type:, analysis_style:, content_length:|
      assert_equal @extraction[:raw_content], content
      assert_equal "twitter", type
      assert_equal "execution_brief", analysis_style
      assert_equal content.length, content_length
      @analysis
    end

    UrlFavorites::Integrations::Twitter::Extractor.stub(:call, @extraction) do
      UrlFavorites::Integrations::LlamaServer::Client.stub(:call, analyzer) do
        AnalyzeTwitterJob.perform_now(@favorite.id)
      end
    end

    @favorite.reload
    assert_equal "done", @favorite.status
    assert_equal "Alice on X", @favorite.title
    assert_equal "https://pbs.twimg.com/thumb.jpg", @favorite.thumbnail_url
    assert_equal "뉴스/커뮤니티", @favorite.category
    assert_equal "X 스레드 요약", @favorite.analysis.summary
    assert_equal "영상 자막", @favorite.analysis.transcript
  end
end
