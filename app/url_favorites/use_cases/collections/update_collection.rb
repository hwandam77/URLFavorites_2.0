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
          collection.update!(**attrs)
          UrlFavorites::UseCases::Result.new(ok: true, value: { collection: collection })
        end
      end
    end
  end
end
