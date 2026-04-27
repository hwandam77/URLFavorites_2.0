class ReindexFavoriteJob < ApplicationJob
  queue_as :default

  def perform(favorite_id = nil)
    if favorite_id.present?
      favorite = Favorite.find_by(id: favorite_id)
      return unless favorite
      UrlFavorites::Integrations::Search::Indexer.index(favorite)
    else
      UrlFavorites::Integrations::Search::Indexer.reindex_all
    end
  end
end
