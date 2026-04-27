class AnalyzeWebpageJob < ApplicationJob
  queue_as :ai

  rescue_from(StandardError) do |e|
    executions_index = (executions - 1)
    if executions < UrlFavorites::Domain::Analysis::RetryPolicy::MAX_RETRIES
      wait_seconds = UrlFavorites::Domain::Analysis::RetryPolicy.next_wait_seconds(executions_index)
      retry_job(wait: wait_seconds)
    end
  end

  def perform(favorite_id)
    UrlFavorites::UseCases::Analysis::RunAnalysis.call(favorite_id: favorite_id)
  end
end
