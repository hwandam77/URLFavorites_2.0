module UrlFavorites
  module UseCases
    module Authentication
      class DestroySession
        def self.call(session:)
          session&.destroy

          Result.ok(value: {})
        end
      end
    end
  end
end
