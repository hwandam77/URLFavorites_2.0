require "test_helper"

module UrlFavorites
  module UseCases
    module Authentication
      class CreateSessionTest < ActiveSupport::TestCase
        test "creates a session for valid credentials" do
          user = create_authenticated_user(email_address: "person@example.com")

          assert_difference "Session.count", 1 do
            result = CreateSession.call(
              email_address: " PERSON@example.com ",
              password: "password123",
              user_agent: "Rails test",
              ip_address: "127.0.0.1"
            )

            assert_predicate result, :ok?
            assert_equal user, result.value[:session].user
          end
        end

        test "rejects invalid credentials" do
          create_authenticated_user(email_address: "person@example.com")

          assert_no_difference "Session.count" do
            result = CreateSession.call(
              email_address: "person@example.com",
              password: "wrong-password",
              user_agent: "Rails test",
              ip_address: "127.0.0.1"
            )

            assert_not result.ok?
            assert_equal :invalid_credentials, result.error
          end
        end
      end
    end
  end
end
