module UrlFavorites
  module UseCases
    module Favorites
      class TogglePin
        def self.call(id:)
          favorite = Favorite.find(id)
          favorite.update!(pinned: !favorite.pinned)
          favorite
        end
      end
    end
  end
end
