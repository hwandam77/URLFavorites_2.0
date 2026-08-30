# frozen_string_literal: true

require "test_helper"

class UrlFavorites::UseCases::Analysis::RecoverStalledAnalysesTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @llm_failed = Favorite.create!(
      url: "https://example.com/llm-failed",
      status: "failed",
      content_type: "webpage",
      raw_content: "cached body",
      error_message: "UrlFavorites::Integrations::LlamaServer::Client::ServerError: All LLM backends failed. Last error: Connection error",
      updated_at: 30.minutes.ago
    )
  end

  test "LLM 장애로 실패한 favorite 을 재발주한다 — raw_content 유지" do
    assert_enqueued_jobs(1, only: AnalyzeWebpageAnalysisJob) do
      result = UrlFavorites::UseCases::Analysis::RecoverStalledAnalyses.call
      assert result.ok?
      assert_equal 1, result.value[:recovered]
    end

    @llm_failed.reload
    assert_equal "analyzing", @llm_failed.status
    assert_nil @llm_failed.error_message
    assert_equal "cached body", @llm_failed.raw_content, "본문 재추출 없이 캐시 유지"
  end

  test "추출 실패(ExtractionError)는 재발주하지 않는다" do
    @llm_failed.update!(
      error_message: "UrlFavorites::Integrations::Webpage::Scraper::ExtractionError: yt-dlp failed",
      updated_at: 30.minutes.ago
    )

    assert_no_enqueued_jobs(only: AnalyzeWebpageAnalysisJob) do
      result = UrlFavorites::UseCases::Analysis::RecoverStalledAnalyses.call
      assert_equal 0, result.value[:recovered]
    end
  end

  test "백오프 창(5분) 이내 실패는 재발주하지 않는다" do
    @llm_failed.update!(updated_at: 2.minutes.ago) # rubocop:disable Rails/SkipsModelValidations

    assert_no_enqueued_jobs(only: AnalyzeWebpageAnalysisJob) do
      result = UrlFavorites::UseCases::Analysis::RecoverStalledAnalyses.call
      assert_equal 0, result.value[:recovered]
    end
  end

  test "30분 이상 묵은 analyzing (잡 소실) 도 회복한다" do
    @llm_failed.update!(status: "analyzing", error_message: nil, updated_at: 45.minutes.ago)

    assert_enqueued_jobs(1, only: AnalyzeWebpageAnalysisJob) do
      result = UrlFavorites::UseCases::Analysis::RecoverStalledAnalyses.call
      assert_equal 1, result.value[:recovered]
    end
  end

  test "5분 이상 묵은 pending (enqueue 유실) 도 회복한다" do
    @llm_failed.update!(status: "pending", error_message: nil, updated_at: 20.minutes.ago)

    assert_enqueued_jobs(1, only: AnalyzeWebpageAnalysisJob) do
      result = UrlFavorites::UseCases::Analysis::RecoverStalledAnalyses.call
      assert_equal 1, result.value[:recovered]
    end
  end

  test "방금 생성된 pending (정상 흐름 진행 중) 은 건드리지 않는다" do
    @llm_failed.update!(status: "pending", error_message: nil, updated_at: 30.seconds.ago)

    assert_no_enqueued_jobs(only: AnalyzeWebpageAnalysisJob) do
      result = UrlFavorites::UseCases::Analysis::RecoverStalledAnalyses.call
      assert_equal 0, result.value[:recovered]
    end
  end

  test "content_type 에 맞는 잡으로 발주한다 (youtube)" do
    @llm_failed.update!(content_type: "youtube", error_message: "Net::ReadTimeout", updated_at: 30.minutes.ago)

    assert_enqueued_jobs(1, only: AnalyzeYoutubeJob) do
      UrlFavorites::UseCases::Analysis::RecoverStalledAnalyses.call
    end
  end

  test "done 상태는 건드리지 않는다" do
    @llm_failed.update!(status: "done", error_message: nil, updated_at: 30.minutes.ago)

    assert_no_enqueued_jobs do
      result = UrlFavorites::UseCases::Analysis::RecoverStalledAnalyses.call
      assert_equal 0, result.value[:recovered]
    end
  end
end
