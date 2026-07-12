module UrlFavorites
  module UseCases
    module Authentication
      class ResumeSession
        def self.call(token:)
          session = Session.find_by_token(token)

          return Result.fail(error: :not_found) unless session

          Result.ok(value: { session: session })
        end
      end
    end
  end
end
