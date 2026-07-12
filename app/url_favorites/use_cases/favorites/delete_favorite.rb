module UrlFavorites
  module UseCases
    module Favorites
      class DeleteFavorite
        def self.call(id:)
          favorite = Favorite.find(id)
          UrlFavorites::Integrations::Search::Indexer.remove(favorite.id)
          favorite.destroy!
        end
      end
    end
  end
end
