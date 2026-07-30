# frozen_string_literal: true

require "test_helper"

class PlanManualOutlineJobTest < ActiveSupport::TestCase
  test "queue is ai_refine" do
    assert_equal "ai_refine", PlanManualOutlineJob.queue_name
  end

  test "limits_concurrency is declared with shared refine_analysis key" do
    assert_equal 1, PlanManualOutlineJob.concurrency_limit
    assert_equal 30.minutes, PlanManualOutlineJob.concurrency_duration
    assert_equal "refine_analysis", PlanManualOutlineJob.concurrency_key
  end

  test "perform delegates to PlanOutline use case" do
    called = nil
    stub = ->(**kwargs) { called = kwargs }

    UrlFavorites::UseCases::Manual::PlanOutline.stub(:call, stub) do
      PlanManualOutlineJob.perform_now(42, 1.23)
    end

    assert_equal 42, called[:favorite_id]
    assert_in_delta 1.23, called[:analysis_snapshot], 0.0001
  end
end
