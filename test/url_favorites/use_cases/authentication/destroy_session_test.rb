require "test_helper"

module UrlFavorites
  module UseCases
    module Authentication
      class DestroySessionTest < ActiveSupport::TestCase
        test "destroys the session" do
          user = create_authenticated_user
          session = user.sessions.create!

          assert_difference "Session.count", -1 do
            result = DestroySession.call(session: session)

            assert_predicate result, :ok?
          end
        end
      end
    end
  end
end
