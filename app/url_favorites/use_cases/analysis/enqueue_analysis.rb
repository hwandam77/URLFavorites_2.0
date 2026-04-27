module UrlFavorites
  module UseCases
    module Analysis
      class EnqueueAnalysis
        def self.call(favorite_id:)
          favorite = Favorite.find(favorite_id)
          if favorite.content_type == "youtube"
            AnalyzeYoutubeJob.perform_later(favorite.id)
          else
            AnalyzeWebpageJob.perform_later(favorite.id)
          end
        end
      end
    end
  end
end
