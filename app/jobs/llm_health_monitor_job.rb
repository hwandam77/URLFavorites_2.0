# frozen_string_literal: true

require Rails.root.join("app/url_favorites/integrations/llama_server/health_check").to_s
require Rails.root.join("app/url_favorites/use_cases/analysis/recover_stalled_analyses").to_s

# vLLM 헬스를 매 분 확인하고, 백엔드가 살아 있을 때만 장애 실패분을 재발주한다.
# 백엔드가 죽어 있는 동안엔 아무것도 하지 않는다 — 재발주했다가는 전부 또 실패한다.
class LlmHealthMonitorJob < ApplicationJob
  queue_as :search

  def perform
    unless UrlFavorites::Integrations::LlamaServer::HealthCheck.call
      Rails.logger.info "[LlmHealthMonitorJob] LLM backend down — waiting for recovery"
      return
    end

    UrlFavorites::UseCases::Analysis::RecoverStalledAnalyses.call
  rescue => e
    # 모니터 자체가 죽어도 다음 분에 다시 돈다 — 장애 전파 없음
    Rails.logger.error "[LlmHealthMonitorJob] #{e.class}: #{e.message}"
  end
end
