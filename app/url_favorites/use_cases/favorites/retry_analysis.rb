module UrlFavorites
  module UseCases
    module Favorites
      class RetryAnalysis
        def self.call(id:, analysis_style: UrlFavorites::Domain::Analysis::PromptStyle::DEFAULT)
          favorite = Favorite.find(id)
          favorite.update!(status: "analyzing", error_message: nil)
          UrlFavorites::UseCases::Analysis::EnqueueAnalysis.call(
            favorite_id: favorite.id,
            analysis_style: analysis_style
          )
          favorite
        end
      end
    end
  end
end
