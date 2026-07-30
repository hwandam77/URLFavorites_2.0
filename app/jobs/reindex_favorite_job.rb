class ReindexFavoriteJob < ApplicationJob
  queue_as :default

  # favorite 별 직렬화. 무인자(reindex_all) 호출 계약 유지.
  limits_concurrency key: ->(favorite_id = nil, *) { favorite_id ? "reindex_#{favorite_id}" : "reindex_all" },
    to: 1,
    duration: 10.minutes

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
