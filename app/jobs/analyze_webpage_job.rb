require Rails.root.join("app/url_favorites/domain/analysis").to_s
require Rails.root.join("app/url_favorites/domain/analysis/prompt_style").to_s
require Rails.root.join("app/url_favorites/use_cases/analysis/run_analysis").to_s

class AnalyzeWebpageJob < ApplicationJob
  MAX_RETRIES = 3
  BACKOFF_SECONDS = [ 30, 60, 120 ].freeze

  queue_as :ai

  rescue_from(StandardError) do |e|
    executions_index = (executions - 1)
    if executions < MAX_RETRIES
      wait_seconds = BACKOFF_SECONDS.fetch(executions_index, BACKOFF_SECONDS.last)
      retry_job(wait: wait_seconds)
    else
      raise e
    end
  end

  def perform(favorite_id, analysis_style = "execution_brief")
    UrlFavorites::UseCases::Analysis::RunAnalysis.call(favorite_id: favorite_id, analysis_style: analysis_style)
  end
end
