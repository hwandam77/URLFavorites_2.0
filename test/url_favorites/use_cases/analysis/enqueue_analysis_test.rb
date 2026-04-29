require "test_helper"

class UrlFavorites::UseCases::Analysis::EnqueueAnalysisTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    clear_enqueued_jobs
  end

  teardown do
    clear_enqueued_jobs
  end

  test "YouTube 분석 작업에 선택한 분석 스타일을 전달한다" do
    favorite = Favorite.create!(
      url: "https://www.youtube.com/watch?v=style123456",
      content_type: "youtube",
      status: "done"
    )

    assert_enqueued_with(job: AnalyzeYoutubeJob, args: [ favorite.id, "tutorial" ]) do
      UrlFavorites::UseCases::Analysis::EnqueueAnalysis.call(
        favorite_id: favorite.id,
        analysis_style: "tutorial"
      )
    end
  end

  test "알 수 없는 분석 스타일은 기본 스타일로 정규화한다" do
    favorite = Favorite.create!(
      url: "https://example.com/style",
      content_type: "webpage",
      status: "done"
    )

    assert_enqueued_with(job: AnalyzeWebpageJob, args: [ favorite.id, "execution_brief" ]) do
      UrlFavorites::UseCases::Analysis::EnqueueAnalysis.call(
        favorite_id: favorite.id,
        analysis_style: "unknown"
      )
    end
  end
end
