# frozen_string_literal: true

require "test_helper"

class UrlFavorites::UseCases::Authentication::UpdatePasswordTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email_address: "changer@example.com",
      password: "oldpass123",
      password_confirmation: "oldpass123"
    )
    @keep = @user.sessions.create!(user_agent: "current", ip_address: "127.0.0.1")
    @other = @user.sessions.create!(user_agent: "other-device", ip_address: "10.0.0.9")
  end

  test "현재 비밀번호가 올바르면 암호를 변경한다" do
    result = UrlFavorites::UseCases::Authentication::UpdatePassword.call(
      user: @user,
      current_password: "oldpass123",
      password: "newpass456",
      password_confirmation: "newpass456",
      keep_session: @keep
    )

    assert result.ok?
    @user.reload
    assert @user.authenticate("newpass456")
    assert_not @user.authenticate("oldpass123")
  end

  test "암호 변경 시 현재 세션만 유지하고 다른 세션은 무효화한다" do
    UrlFavorites::UseCases::Authentication::UpdatePassword.call(
      user: @user,
      current_password: "oldpass123",
      password: "newpass456",
      keep_session: @keep
    )

    assert Session.exists?(@keep.id)
    assert_not Session.exists?(@other.id)
  end

  test "현재 비밀번호가 틀리면 변경하지 않는다" do
    result = UrlFavorites::UseCases::Authentication::UpdatePassword.call(
      user: @user,
      current_password: "wrong-password",
      password: "newpass456"
    )

    assert_not result.ok?
    assert_equal :wrong_current_password, result.error
    @user.reload
    assert @user.authenticate("oldpass123")
    assert Session.exists?(@other.id)
  end

  test "새 비밀번호가 최소 길이 미달이면 실패한다" do
    result = UrlFavorites::UseCases::Authentication::UpdatePassword.call(
      user: @user,
      current_password: "oldpass123",
      password: "short"
    )

    assert_not result.ok?
    assert_equal :invalid_new_password, result.error
    @user.reload
    assert @user.authenticate("oldpass123")
  end
end
