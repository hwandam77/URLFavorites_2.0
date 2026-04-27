module UrlFavorites
  module UseCases
    module Collections
      class RemoveFavoriteFromCollection
        def self.call(favorite_id:, collection_id:)
          favorite = Favorite.find(favorite_id)
          membership = CollectionMembership.find_by(favorite: favorite, collection_id: collection_id)
          membership&.destroy
          favorite
        end
      end
    end
  end
end
