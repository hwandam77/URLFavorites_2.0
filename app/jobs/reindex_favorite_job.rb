class ReindexFavoriteJob < ApplicationJob
  queue_as :default

  def perform(favorite_id = nil)
    if favorite_id.present?
      favorite = Favorite.find_by(id: favorite_id)
      return unless favorite
      FavoriteSearchIndexer.index(favorite)
    else
      FavoriteSearchIndexer.reindex_all
    end
  end
end
