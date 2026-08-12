# frozen_string_literal: true

module UrlFavorites
  module UseCases
    module Collections
      class CreateCollection
        def self.call(name:, description: nil)
          collection = Collection.new(name: name, description: description)
          if collection.save
            UrlFavorites::UseCases::Result.new(ok: true, value: { collection: collection })
          else
            UrlFavorites::UseCases::Result.new(ok: false, value: nil, error: collection.errors)
          end
        end
      end
    end
  end
end
