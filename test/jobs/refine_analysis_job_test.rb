# frozen_string_literal: true

require "test_helper"

class RefineAnalysisJobTest < ActiveSupport::TestCase
  test "queue is ai_refine" do
    assert_equal "ai_refine", RefineAnalysisJob.queue_name
  end

  test "limits_concurrency is declared" do
    assert_equal 1, RefineAnalysisJob.concurrency_limit
    assert_equal 30.minutes, RefineAnalysisJob.concurrency_duration
    assert_equal "refine_analysis", RefineAnalysisJob.concurrency_key
  end

  test "perform delegates to RefineAnalysis use case" do
    called = nil
    stub = ->(**kwargs) { called = kwargs }

    UrlFavorites::UseCases::Analysis::RefineAnalysis.stub(:call, stub) do
      RefineAnalysisJob.perform_now(42, "tutorial", 1.23)
    end

    assert_equal 42, called[:favorite_id]
    assert_equal "tutorial", called[:analysis_style]
    assert_in_delta 1.23, called[:analysis_snapshot], 0.0001
  end
end
