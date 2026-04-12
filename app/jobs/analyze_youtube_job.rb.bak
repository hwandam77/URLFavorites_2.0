class AnalyzeYoutubeJob < ApplicationJob
  queue_as :default

  def perform(favorite_id)
    favorite = Favorite.find(favorite_id)
    favorite.update!(status: "analyzing")

    extractor_result = YoutubeExtractor.call(favorite.url)
    raw_content = extractor_result[:transcript]

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

    favorite.update!(status: "done")
  rescue => e
    favorite&.update!(status: "failed")
    Rails.logger.error "[AnalyzeYoutubeJob] #{e.class}: #{e.message}"
  end
end
