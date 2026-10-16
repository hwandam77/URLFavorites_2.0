# frozen_string_literal: true

module UrlFavorites
  module UseCases
    module Collections
      class UpdateCollection
        def self.call(id:, name: nil, description: nil)
          collection = Collection.find(id)
          attrs = {}
          attrs[:name] = name if name
          attrs[:description] = description if description
          if collection.update(**attrs)
            Rails.cache.delete("sidebar_collections")
            UrlFavorites::UseCases::Result.new(ok: true, value: { collection: collection })
          else
            UrlFavorites::UseCases::Result.new(ok: false, value: { collection: collection }, error: collection.errors)
          end
        end
      end
    end
  end
end
