require "test_helper"
require "webmock/minitest"

class AnalyzeYoutubeJobTest < ActiveSupport::TestCase
  setup do
    WebMock.enable!
    WebMock.disable_net_connect!
    @favorite = Favorite.create!(
      url: "https://www.youtube.com/watch?v=test123",
      status: "pending",
      content_type: "youtube"
    )
    @extractor_result = {
      title: "Rails 8 튜토리얼",
      description: "Rails 8 소개 https://github.com/rails/rails",
      transcript: "안녕하세요. 이 영상에서는 Rails 8을 소개합니다.",
      subtitle_source: "manual",
      transcript_segments: [
        { start: 0.0, duration: 3.0, timestamp: "00:00", text: "안녕하세요." },
        { start: 3.0, duration: 4.0, timestamp: "00:03", text: "이 영상에서는 Rails 8을 소개합니다." }
      ],
      github_links: [ "https://github.com/rails/rails" ]
    }
    @analyzer_result = {
      summary: "Rails 8 튜토리얼 요약",
      key_points: [ "Solid Queue", "Hotwire" ],
      tags: [ "rails", "tutorial" ],
      sentiment: "positive"
    }
  end

  teardown do
    WebMock.reset!
  end

  test "성공 시 pending → analyzing → done 상태 전이 및 Analysis 생성" do
    UrlFavorites::Integrations::Youtube::Extractor.stub(:call, @extractor_result) do
      UrlFavorites::Integrations::LlamaServer::Client.stub(:call, @analyzer_result) do
        AnalyzeYoutubeJob.perform_now(@favorite.id)

        @favorite.reload
        assert_equal "done", @favorite.status
        assert_not_nil @favorite.analysis
        assert_equal "Rails 8 튜토리얼 요약", @favorite.analysis.summary
        assert_equal [ "rails", "tutorial" ], @favorite.analysis.tags
        assert_equal "positive", @favorite.analysis.sentiment
        assert_equal "manual", @favorite.analysis.subtitle_source
        assert_equal 2, @favorite.analysis.parsed_transcript_segments.size
      end
    end
  end

  test "raw_content에 transcript를 캐싱한다" do
    UrlFavorites::Integrations::Youtube::Extractor.stub(:call, @extractor_result) do
      UrlFavorites::Integrations::LlamaServer::Client.stub(:call, @analyzer_result) do
        AnalyzeYoutubeJob.perform_now(@favorite.id)

        assert_includes @favorite.reload.analysis.raw_content, "Rails 8"
      end
    end
  end

  test "YouTube 분석 입력에 제목 설명 자막 출처와 AI 실행 브리프 지시를 포함한다" do
    captured_content = nil

    analyzer = lambda do |content, type:, analysis_style:|
      captured_content = content
      assert_equal "youtube", type
      assert_equal "execution_brief", analysis_style
      @analyzer_result
    end

    UrlFavorites::Integrations::Youtube::Extractor.stub(:call, @extractor_result) do
      UrlFavorites::Integrations::LlamaServer::Client.stub(:call, analyzer) do
        AnalyzeYoutubeJob.perform_now(@favorite.id)
      end
    end

    assert_includes captured_content, "Title: Rails 8 튜토리얼"
    assert_includes captured_content, "Description: Rails 8 소개"
    assert_includes captured_content, "Subtitle source: manual"
    assert_includes captured_content, "Provided GitHub links:"
    assert_includes captured_content, "- https://github.com/rails/rails"
    assert_includes captured_content, "Transcript:"
    assert_includes captured_content, "AI 실행 브리프"
    assert_includes captured_content, "Timestamped transcript sample:"
    assert_includes captured_content, "- [00:03] 이 영상에서는 Rails 8을 소개합니다."
  end

  test "GitHub 링크가 없으면 분석 입력에 미확인으로 표시한다" do
    captured_content = nil
    extractor_result = @extractor_result.merge(github_links: [])

    analyzer = lambda do |content, type:, analysis_style:|
      captured_content = content
      assert_equal "youtube", type
      assert_equal "execution_brief", analysis_style
      @analyzer_result
    end

    UrlFavorites::Integrations::Youtube::Extractor.stub(:call, extractor_result) do
      UrlFavorites::Integrations::LlamaServer::Client.stub(:call, analyzer) do
        AnalyzeYoutubeJob.perform_now(@favorite.id)
      end
    end

    assert_includes captured_content, "Provided GitHub links:"
    assert_includes captured_content, "- 미확인"
  end

  test "YouTube 추출 실패 시 status = failed" do
    UrlFavorites::Integrations::Youtube::Extractor.stub(:call, ->(_url) { raise UrlFavorites::Integrations::Youtube::Extractor::ExtractionError, "yt-dlp failed" }) do
      AnalyzeYoutubeJob.perform_now(@favorite.id)

      @favorite.reload
      assert_equal "failed", @favorite.status
    end
  end

  test "LLM 분석 실패 시 status = failed" do
    UrlFavorites::Integrations::Youtube::Extractor.stub(:call, @extractor_result) do
      UrlFavorites::Integrations::LlamaServer::Client.stub(:call, ->(*_args) { raise UrlFavorites::Integrations::LlamaServer::Client::ServerError, "llm error" }) do
        AnalyzeYoutubeJob.perform_now(@favorite.id)

        @favorite.reload
        assert_equal "failed", @favorite.status
      end
    end
  end

  test "재실행 시 Analysis를 덮어쓴다 (upsert)" do
    UrlFavorites::Integrations::Youtube::Extractor.stub(:call, @extractor_result) do
      UrlFavorites::Integrations::LlamaServer::Client.stub(:call, @analyzer_result) do
        AnalyzeYoutubeJob.perform_now(@favorite.id)
        AnalyzeYoutubeJob.perform_now(@favorite.id)

        assert_equal 1, Analysis.where(favorite_id: @favorite.id).count
      end
    end
  end

  test "선택한 분석 스타일을 LLM 호출과 Analysis에 저장한다" do
    captured_style = nil
    analyzer = lambda do |_content, type:, analysis_style:|
      assert_equal "youtube", type
      captured_style = analysis_style
      @analyzer_result
    end

    UrlFavorites::Integrations::Youtube::Extractor.stub(:call, @extractor_result) do
      UrlFavorites::Integrations::LlamaServer::Client.stub(:call, analyzer) do
        UrlFavorites::UseCases::Analysis::RunAnalysis.call(
          favorite_id: @favorite.id,
          analysis_style: "qna"
        )
      end
    end

    assert_equal "qna", captured_style
    assert_equal "qna", @favorite.reload.analysis.analysis_style
    assert_equal "Q&A", @favorite.analysis.analysis_style_label
  end
end
