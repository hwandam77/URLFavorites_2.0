module UrlFavorites
  module UseCases
    module Favorites
      class RetryAnalysis
        def self.call(id:)
          favorite = Favorite.find(id)
          favorite.update!(status: "pending", error_message: nil)
          UrlFavorites::UseCases::Analysis::EnqueueAnalysis.call(favorite_id: favorite.id)
          favorite
        end
      end
    end
  end
end
