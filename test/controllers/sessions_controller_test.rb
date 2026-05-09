require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "GET /session/new renders login form" do
    get new_session_url

    assert_response :success
    assert_select "h1", text: "로그인"
    assert_select "form[action='#{session_path}'][method='post']"
  end

  test "POST /session signs in with valid credentials" do
    user = create_authenticated_user(email_address: "person@example.com")

    assert_difference "Session.count", 1 do
      post session_url, params: {
        session: {
          email_address: " PERSON@example.com ",
          password: "password123"
        }
      }
    end

    assert_redirected_to favorites_url
    assert_equal user, Session.last.user
  end

  test "POST /session rejects invalid credentials" do
    create_authenticated_user(email_address: "person@example.com")

    assert_no_difference "Session.count" do
      post session_url, params: {
        session: {
          email_address: "person@example.com",
          password: "wrong-password"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "이메일 또는 비밀번호가 올바르지 않습니다."
  end

  test "protected pages redirect unauthenticated users to login" do
    get favorites_url

    assert_redirected_to new_session_url
  end

  test "DELETE /session signs out" do
    sign_in_as

    assert_difference "Session.count", -1 do
      delete session_url
    end

    assert_redirected_to new_session_url

    get favorites_url

    assert_redirected_to new_session_url
  end
end
