module UrlFavorites
  module UseCases
    module Notes
      class UpdateFavoriteNote
        def self.call(favorite_id:, note:)
          favorite = Favorite.find(favorite_id)
          favorite.update!(note: note)
          ReindexFavoriteJob.perform_later(favorite.id)
          favorite
        end
      end
    end
  end
end
