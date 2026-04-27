module UrlFavorites
  module UseCases
    module Favorites
      class UpdateCategory
        def self.call(id:, category:)
          favorite = Favorite.find(id)
          favorite.update!(category: category)
          favorite
        end
      end
    end
  end
end
