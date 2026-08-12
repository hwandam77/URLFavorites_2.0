class ReindexFavoriteJob < ApplicationJob
  queue_as :default

  # favorite 별 직렬화. 무인자(reindex_all) 호출 계약 유지.
  limits_concurrency key: ->(favorite_id = nil, *) { favorite_id ? "reindex_#{favorite_id}" : "reindex_all" },
    to: 1,
    duration: 10.minutes

  def perform(favorite_id = nil)
    if favorite_id.present?
      UrlFavorites::UseCases::Search::ReindexFavorite.call(favorite_id: favorite_id)
    else
      UrlFavorites::UseCases::Search::ReindexFavorite.call_all
    end
  end
end
