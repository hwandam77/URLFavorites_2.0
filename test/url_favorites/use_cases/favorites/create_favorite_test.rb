require "test_helper"

class UrlFavorites::UseCases::Favorites::CreateFavoriteTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    clear_enqueued_jobs
  end

  teardown do
    clear_enqueued_jobs
  end

  test "새 GitHub URL을 만들면 대기 상태에 머물지 않고 바로 분석 작업을 예약한다" do
    result = nil

    assert_enqueued_jobs 1, only: AnalyzeWebpageAnalysisJob do
      result = UrlFavorites::UseCases::Favorites::CreateFavorite.call(
        url: "https://github.com/GitFrog1111/OpenWhip"
      )
    end

    favorite = result.value[:favorite]

    assert result.ok?
    assert result.value[:created]
    assert_equal "github", favorite.content_type
    assert_equal "analyzing", favorite.status
  end

  test "기존 GitHub URL이 미분석 상태이면 다시 입력해도 분석 작업을 예약한다" do
    existing = Favorite.create!(
      url: "https://github.com/GitFrog1111/OpenWhip-existing",
      content_type: "github",
      status: "pending"
    )
    result = nil

    assert_enqueued_jobs 1, only: AnalyzeWebpageAnalysisJob do
      result = UrlFavorites::UseCases::Favorites::CreateFavorite.call(url: existing.url)
    end

    assert result.ok?
    refute result.value[:created]
    assert_equal existing.id, result.value[:favorite].id
    assert_equal "analyzing", existing.reload.status
  end
end
