require Rails.root.join("app/url_favorites/domain/analysis").to_s
require Rails.root.join("app/url_favorites/domain/analysis/prompt_style").to_s
require Rails.root.join("app/url_favorites/domain/analysis/retry_policy").to_s
require Rails.root.join("app/url_favorites/use_cases/analysis/run_analysis").to_s

class AnalyzeWebpageAnalysisJob < ApplicationJob
  MAX_RETRIES = UrlFavorites::Domain::Analysis::RetryPolicy::MAX_RETRIES
  BACKOFF_SECONDS = UrlFavorites::Domain::Analysis::RetryPolicy::BACKOFF_SECONDS

  queue_as :ai

  rescue_from(StandardError) do |e|
    if executions < MAX_RETRIES
      retry_job(wait: UrlFavorites::Domain::Analysis::RetryPolicy.next_wait_seconds(executions - 1))
    else
      raise e
    end
  end

  def perform(favorite_id, analysis_style = "execution_brief")
    UrlFavorites::UseCases::Analysis::RunAnalysis.call(favorite_id: favorite_id, analysis_style: analysis_style)
  end
end
