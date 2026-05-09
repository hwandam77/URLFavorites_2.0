require "test_helper"

class SessionTest < ActiveSupport::TestCase
  test "generates a token when created" do
    user = create_authenticated_user
    session = user.sessions.create!(user_agent: "Test", ip_address: "127.0.0.1")

    assert_predicate session.token, :present?
    assert_equal session, Session.find_by_token(session.token)
  end
end
