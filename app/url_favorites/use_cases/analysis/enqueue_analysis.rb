module UrlFavorites
  module UseCases
    module Analysis
      class EnqueueAnalysis
        def self.call(favorite_id:, analysis_style: UrlFavorites::Domain::Analysis::PromptStyle::DEFAULT)
          favorite = Favorite.find(favorite_id)
          normalized_style = UrlFavorites::Domain::Analysis::PromptStyle.normalize(analysis_style)
          favorite.update!(status: "analyzing", error_message: nil)

          if favorite.content_type == "youtube"
            AnalyzeYoutubeJob.perform_later(favorite.id, normalized_style)
          else
            AnalyzeWebpageAnalysisJob.perform_later(favorite.id, normalized_style)
          end
        end
      end
    end
  end
end
