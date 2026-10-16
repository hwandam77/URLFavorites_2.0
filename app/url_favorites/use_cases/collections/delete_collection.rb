# frozen_string_literal: true

module UrlFavorites
  module UseCases
    module Collections
      class DeleteCollection
        def self.call(id:)
          collection = Collection.find(id)
          collection.destroy
          Rails.cache.delete("sidebar_collections")
          UrlFavorites::UseCases::Result.new(ok: true, value: {})
        end
      end
    end
  end
end
