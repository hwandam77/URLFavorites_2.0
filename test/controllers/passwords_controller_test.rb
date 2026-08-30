# frozen_string_literal: true

require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  test "GET /password/edit 은 미인증 시 로그인 페이지로 리다이렉트한다" do
    get edit_password_url

    assert_redirected_to new_session_url
  end

  test "GET /password/edit 은 인증 시 폼을 렌더링한다" do
    user = sign_in_as

    get edit_password_url

    assert_response :success
    assert_select "h1", text: "비밀번호 변경"
    assert_select "form[action='#{password_path}'][method='post']"
    assert_match user.email_address, response.body
  end

  test "PATCH /password 는 올바른 현재 비밀번호로 암호를 변경한다" do
    user = sign_in_as

    patch password_url, params: {
      password: {
        current_password: AuthenticationTestHelpers::DEFAULT_PASSWORD,
        password: "doking99",
        password_confirmation: "doking99"
      }
    }

    assert_redirected_to edit_password_url
    user.reload
    assert user.authenticate("doking99")
  end

  test "PATCH /password 는 틀린 현재 비밀번호를 거부한다" do
    user = sign_in_as

    patch password_url, params: {
      password: {
        current_password: "wrong-current",
        password: "doking99",
        password_confirmation: "doking99"
      }
    }

    assert_response :unprocessable_entity
    user.reload
    assert user.authenticate(AuthenticationTestHelpers::DEFAULT_PASSWORD)
  end

  test "PATCH /password 는 6자 미만 새 비밀번호를 거부한다" do
    user = sign_in_as

    patch password_url, params: {
      password: {
        current_password: AuthenticationTestHelpers::DEFAULT_PASSWORD,
        password: "abc",
        password_confirmation: "abc"
      }
    }

    assert_response :unprocessable_entity
    user.reload
    assert user.authenticate(AuthenticationTestHelpers::DEFAULT_PASSWORD)
  end
end
