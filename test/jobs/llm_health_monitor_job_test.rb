# frozen_string_literal: true

require "test_helper"

class LlmHealthMonitorJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "LLM 백엔드가 죽어 있으면 복구를 실행하지 않는다" do
    UrlFavorites::Integrations::LlamaServer::HealthCheck.stub(:call, false) do
      UrlFavorites::UseCases::Analysis::RecoverStalledAnalyses.stub(:call, ->(*) { flunk "복구 유스케이스가 호출되면 안 된다" }) do
        perform_enqueued_jobs { LlmHealthMonitorJob.perform_now }
      end
    end
  end

  test "LLM 백엔드가 살아 있으면 복구를 실행한다" do
    called = false
    UrlFavorites::Integrations::LlamaServer::HealthCheck.stub(:call, true) do
      UrlFavorites::UseCases::Analysis::RecoverStalledAnalyses.stub(:call, ->(*) { called = true }) do
        perform_enqueued_jobs { LlmHealthMonitorJob.perform_now }
      end
    end

    assert called
  end

  test "복구 유스케이스 예외가 잡을 죽이지 않는다" do
    UrlFavorites::Integrations::LlamaServer::HealthCheck.stub(:call, true) do
      UrlFavorites::UseCases::Analysis::RecoverStalledAnalyses.stub(:call, ->(*) { raise "boom" }) do
        assert_nothing_raised { LlmHealthMonitorJob.perform_now }
      end
    end
  end
end
