# frozen_string_literal: true

require "test_helper"

class RunAnalysisManualTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @favorite = Favorite.create!(
      url: "https://example.com/manual-run-#{SecureRandom.hex(4)}",
      status: "pending",
      content_type: "webpage",
      raw_content: "short body"
    )
    @base_result = {
      summary: "요약",
      key_points: [ "k1" ],
      tags: [ "rails" ],
      sentiment: "neutral",
      used_backend_role: "fast",
      used_backend_model: "fast-gguf"
    }
  end

  test "onboarding_manual 이면 PlanManualOutlineJob 발주하고 RefineAnalysisJob 미발주" do
    UrlFavorites::Integrations::LlamaServer::Client.stub(:call, @base_result) do
      assert_no_enqueued_jobs(only: RefineAnalysisJob) do
        assert_enqueued_jobs(1, only: PlanManualOutlineJob) do
          UrlFavorites::UseCases::Analysis::RunAnalysis.call(
            favorite_id: @favorite.id,
            analysis_style: "onboarding_manual"
          )
        end
      end
    end

    job = enqueued_jobs.find { |j| j[:job] == PlanManualOutlineJob }
    assert_equal @favorite.id, job[:args].first
    assert_in_delta @favorite.reload.analysis.updated_at.to_f, job[:args].last, 0.001
  end

  test "다른 스타일은 기존대로 RefineAnalysisJob" do
    UrlFavorites::Integrations::LlamaServer::Client.stub(:call, @base_result) do
      assert_no_enqueued_jobs(only: PlanManualOutlineJob) do
        assert_enqueued_with(job: RefineAnalysisJob) do
          UrlFavorites::UseCases::Analysis::RunAnalysis.call(
            favorite_id: @favorite.id,
            analysis_style: "tutorial"
          )
        end
      end
    end
  end
end
