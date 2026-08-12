# frozen_string_literal: true

module UrlFavorites
  module UseCases
    module Search
      class ReindexFavorite
        def self.call(favorite_id:)
          favorite = Favorite.find_by(id: favorite_id)
          return unless favorite
          UrlFavorites::Integrations::Search::Indexer.index(favorite)
        end

        def self.call_all
          UrlFavorites::Integrations::Search::Indexer.reindex_all
        end
      end
    end
  end
end
