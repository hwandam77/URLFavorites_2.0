# frozen_string_literal: true

require "test_helper"

class GenerateManualSectionJobTest < ActiveSupport::TestCase
  test "queue is ai_refine" do
    assert_equal "ai_refine", GenerateManualSectionJob.queue_name
  end

  test "limits_concurrency is declared with shared refine_analysis key" do
    assert_equal 1, GenerateManualSectionJob.concurrency_limit
    assert_equal 30.minutes, GenerateManualSectionJob.concurrency_duration
    assert_equal "refine_analysis", GenerateManualSectionJob.concurrency_key
  end

  test "perform delegates to GenerateSection use case" do
    called = nil
    stub = ->(**kwargs) { called = kwargs }

    UrlFavorites::UseCases::Manual::GenerateSection.stub(:call, stub) do
      GenerateManualSectionJob.perform_now(42, 3, 1.23)
    end

    assert_equal 42, called[:analysis_id]
    assert_equal 3, called[:position]
    assert_in_delta 1.23, called[:analysis_snapshot], 0.0001
  end
end
