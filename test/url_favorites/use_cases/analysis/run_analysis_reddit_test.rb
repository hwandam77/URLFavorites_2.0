require "test_helper"

class RunAnalysisRedditTest < ActiveSupport::TestCase
  setup do
    @favorite = Favorite.create!(
      url: "https://www.reddit.com/r/rails/comments/abc123/some_title/",
      title: "https://www.reddit.com/r/rails/comments/abc123/some_title/",
      status: "pending",
      content_type: "reddit"
    )
    @extraction = {
      title: "Rails 8 출시 정리",
      body_text: "본문 내용",
      author: "alice",
      thumbnail_url: nil,
      raw_content: "Title: Rails 8 출시 정리\n\nAuthor: alice\n\nPost:\n본문 내용"
    }
    @analysis = {
      summary: "Reddit 게시물 요약",
      key_points: [ "핵심 주장" ],
      tags: [ "reddit" ],
      sentiment: "neutral"
    }
  end

  test "routes reddit favorites through the Reddit extractor and stores raw_content" do
    analyzer = lambda do |content, type:, analysis_style:, content_length:, backend_role: nil|
      assert_equal @extraction[:raw_content], content
      assert_equal "reddit", type
      assert_equal "execution_brief", analysis_style
      assert_equal content.length, content_length
      assert_equal "fast", backend_role
      @analysis
    end

    UrlFavorites::Integrations::Reddit::Extractor.stub(:call, @extraction) do
      UrlFavorites::Integrations::LlamaServer::Client.stub(:call, analyzer) do
        UrlFavorites::UseCases::Analysis::RunAnalysis.call(favorite_id: @favorite.id)
      end
    end

    @favorite.reload
    assert_equal "done", @favorite.status
    assert_equal "Rails 8 출시 정리", @favorite.title
    assert_equal @extraction[:raw_content], @favorite.raw_content
    assert_equal "Reddit 게시물 요약", @favorite.analysis.summary
  end
end
