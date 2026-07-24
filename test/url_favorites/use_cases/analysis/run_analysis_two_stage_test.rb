# frozen_string_literal: true

require "test_helper"

class RunAnalysisTwoStageTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @favorite = Favorite.create!(
      url: "https://example.com/two-stage-#{SecureRandom.hex(4)}",
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

  test "fast 고정 호출 및 tier·model_used 저장" do
    captured = nil
    stub = ->(*_args, **kwargs) {
      captured = kwargs
      @base_result
    }

    UrlFavorites::Integrations::LlamaServer::Client.stub(:call, stub) do
      UrlFavorites::UseCases::Analysis::RunAnalysis.call(favorite_id: @favorite.id)
    end

    assert_equal "fast", captured[:backend_role]
    @favorite.reload
    assert_equal "done", @favorite.status
    assert_equal "fast", @favorite.analysis.analysis_tier
    assert_equal "fast-gguf", @favorite.analysis.model_used
  end

  test "heavy 폴백 시 refine 미발주" do
    result = @base_result.merge(used_backend_role: "heavy", used_backend_model: "heavy-gguf")

    UrlFavorites::Integrations::LlamaServer::Client.stub(:call, result) do
      assert_no_enqueued_jobs(only: RefineAnalysisJob) do
        UrlFavorites::UseCases::Analysis::RunAnalysis.call(
          favorite_id: @favorite.id,
          analysis_style: "tutorial"
        )
      end
    end

    assert_equal "heavy", @favorite.reload.analysis.analysis_tier
  end

  test "DETAILED_STYLES 이면 refine 발주" do
    UrlFavorites::Integrations::LlamaServer::Client.stub(:call, @base_result) do
      assert_enqueued_with(job: RefineAnalysisJob) do
        UrlFavorites::UseCases::Analysis::RunAnalysis.call(
          favorite_id: @favorite.id,
          analysis_style: "tutorial"
        )
      end
    end
  end

  test "긴 raw_content 이면 refine 발주" do
    long = "x" * UrlFavorites::Domain::Analysis::BackendRouter::LONG_CONTENT_THRESHOLD
    @favorite.update!(raw_content: long)

    UrlFavorites::Integrations::LlamaServer::Client.stub(:call, @base_result) do
      assert_enqueued_with(job: RefineAnalysisJob) do
        UrlFavorites::UseCases::Analysis::RunAnalysis.call(favorite_id: @favorite.id)
      end
    end
  end

  test "짧은 기본 스타일은 refine 미발주" do
    UrlFavorites::Integrations::LlamaServer::Client.stub(:call, @base_result) do
      assert_no_enqueued_jobs(only: RefineAnalysisJob) do
        UrlFavorites::UseCases::Analysis::RunAnalysis.call(favorite_id: @favorite.id)
      end
    end
  end

  test "snapshot 은 upsert 직후 updated_at.to_f" do
    UrlFavorites::Integrations::LlamaServer::Client.stub(:call, @base_result) do
      assert_enqueued_jobs(1, only: RefineAnalysisJob) do
        UrlFavorites::UseCases::Analysis::RunAnalysis.call(
          favorite_id: @favorite.id,
          analysis_style: "qna"
        )
      end
    end

    job = enqueued_jobs.find { |j| j[:job] == RefineAnalysisJob }
    snapshot = job[:args].last
    assert_in_delta @favorite.reload.analysis.updated_at.to_f, snapshot, 0.001
  end
end
