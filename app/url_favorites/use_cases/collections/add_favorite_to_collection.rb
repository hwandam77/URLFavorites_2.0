module UrlFavorites
  module UseCases
    module Collections
      class AddFavoriteToCollection
        def self.call(favorite_id:, collection_id:)
          favorite = Favorite.find(favorite_id)
          unless CollectionMembership.exists?(favorite: favorite, collection_id: collection_id)
            CollectionMembership.create!(favorite: favorite, collection_id: collection_id)
          end
          favorite
        end
      end
    end
  end
end
