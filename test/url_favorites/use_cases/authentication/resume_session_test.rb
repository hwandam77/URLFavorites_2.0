require "test_helper"

module UrlFavorites
  module UseCases
    module Authentication
      class ResumeSessionTest < ActiveSupport::TestCase
        test "returns session for a valid token" do
          user = create_authenticated_user
          session = user.sessions.create!

          result = ResumeSession.call(token: session.token)

          assert_predicate result, :ok?
          assert_equal session, result.value[:session]
        end

        test "fails for a missing token" do
          result = ResumeSession.call(token: nil)

          assert_not result.ok?
          assert_equal :not_found, result.error
        end
      end
    end
  end
end
