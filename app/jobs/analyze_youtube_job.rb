class AnalyzeYoutubeJob < ApplicationJob
  queue_as :default

  def perform(favorite_id)
    favorite = Favorite.find(favorite_id)
    favorite.update!(status: "analyzing")

    extractor_result = YoutubeExtractor.call(favorite.url)
    raw_content     = extractor_result[:transcript]
    thumbnail_url   = extractor_result[:thumbnail_url]
    subtitle_source = extractor_result[:subtitle_source]
    extracted_title = extractor_result[:title]

    analysis_result = LlmAnalyzer.call(raw_content, type: favorite.content_type)

    analysis_attrs = {
      raw_content:     raw_content,
      summary:        analysis_result[:summary],
      key_points:     analysis_result[:key_points],
      tags:           analysis_result[:tags],
      sentiment:      analysis_result[:sentiment],
      detail_content: analysis_result[:detail_content],
      subtitle_source: subtitle_source
    }
    if favorite.analysis
      favorite.analysis.update!(**analysis_attrs)
    else
      favorite.create_analysis!(**analysis_attrs)
    end

    favorite_attrs = { status: "done" }
    favorite_attrs[:thumbnail_url] = thumbnail_url if thumbnail_url.present?
    title_is_url = favorite.title.to_s.start_with?("http://", "https://")
    favorite_attrs[:title] = extracted_title if extracted_title.present? && (favorite.title.blank? || title_is_url)
    favorite_attrs[:category] = UrlCategoryDetector.call(favorite.url, "youtube")
    favorite.update!(**favorite_attrs)
  rescue => e
    favorite&.update!(status: "failed")
    Rails.logger.error "[AnalyzeYoutubeJob] #{e.class}: #{e.message}"
  end
end
