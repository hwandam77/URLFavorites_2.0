class AnalyzeWebpageJob < ApplicationJob
  queue_as :default

  def perform(favorite_id)
    favorite = Favorite.find(favorite_id)
    favorite.update!(status: "analyzing")

    scraper_result = WebpageScraper.call(favorite.url)
    raw_content = [ scraper_result[:title], scraper_result[:body_text] ].compact.join(" ")

    analysis_result = LlmAnalyzer.call(raw_content, type: favorite.content_type)

    if favorite.analysis
      favorite.analysis.update!(
        raw_content: raw_content,
        summary:     analysis_result[:summary],
        key_points:  analysis_result[:key_points],
        tags:        analysis_result[:tags],
        sentiment:   analysis_result[:sentiment]
      )
    else
      favorite.create_analysis!(
        raw_content: raw_content,
        summary:     analysis_result[:summary],
        key_points:  analysis_result[:key_points],
        tags:        analysis_result[:tags],
        sentiment:   analysis_result[:sentiment]
      )
    end

    favorite.update!(title: scraper_result[:title], status: "done")
  rescue => e
    favorite&.update!(status: "failed")
    Rails.logger.error "[AnalyzeWebpageJob] #{e.class}: #{e.message}"
  end
end
