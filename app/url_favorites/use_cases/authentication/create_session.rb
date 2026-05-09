module UrlFavorites
  module UseCases
    module Authentication
      class CreateSession
        def self.call(email_address:, password:, user_agent:, ip_address:)
          user = User.authenticate_by(
            email_address: email_address.to_s.strip.downcase,
            password: password.to_s
          )

          return Result.fail(error: :invalid_credentials) unless user

          session = user.sessions.create!(
            user_agent: user_agent,
            ip_address: ip_address
          )

          Result.ok(value: { session: session })
        end
      end
    end
  end
end
