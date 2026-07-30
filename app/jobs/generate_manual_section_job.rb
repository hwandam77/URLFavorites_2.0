# frozen_string_literal: true

require Rails.root.join("app/url_favorites/use_cases/manual/generate_section").to_s

class GenerateManualSectionJob < ApplicationJob
  MAX_RETRIES = 3
  BACKOFF_SECONDS = [ 30, 60, 120 ].freeze

  queue_as :ai_refine

  # duration 은 semaphore lock 획득 시점부터 계산된다 (절대 보장 아님).
  # RefineAnalysisJob 과 같은 전역 키를 공유해 LLM 레인 전체를 직렬화한다.
  limits_concurrency key: "refine_analysis", to: 1, duration: 30.minutes

  rescue_from(StandardError) do |e|
    executions_index = (executions - 1)
    if executions < MAX_RETRIES
      wait_seconds = BACKOFF_SECONDS.fetch(executions_index, BACKOFF_SECONDS.last)
      retry_job(wait: wait_seconds)
    else
      raise e
    end
  end

  def perform(analysis_id, position, analysis_snapshot)
    UrlFavorites::UseCases::Manual::GenerateSection.call(
      analysis_id: analysis_id,
      position: position,
      analysis_snapshot: analysis_snapshot
    )
  end
end
