require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "normalizes email address before save" do
    user = User.create!(
      email_address: "  PERSON@Example.COM  ",
      password: "password123",
      password_confirmation: "password123"
    )

    assert_equal "person@example.com", user.email_address
  end

  test "requires unique email address" do
    create_authenticated_user(email_address: "person@example.com")

    duplicate = User.new(
      email_address: "PERSON@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email_address], "has already been taken"
  end

  test "requires a secure password length" do
    user = User.new(
      email_address: "short@example.com",
      password: "short",
      password_confirmation: "short"
    )

    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 8 characters)"
  end
end
