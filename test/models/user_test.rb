require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "users are not admins by default" do
    assert_not User.new.admin?
  end

  test "locale defaults to English and only supports English or Spanish" do
    user = User.new
    assert_equal "en", user.locale

    user.locale = "fr"
    refute user.valid?
    assert_includes user.errors[:locale], "is not included in the list"
  end

  test "requires unique email and required names" do
    User.create!(
      first_name: "Jane",
      last_name: "Scout",
      email: "owner@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    duplicate = User.new(
      first_name: "",
      last_name: "",
      email: "owner@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], "has already been taken"
    assert_includes duplicate.errors[:first_name], "can't be blank"
    assert_includes duplicate.errors[:last_name], "can't be blank"
  end

  test "stores encrypted password and optional pushover key" do
    user = User.create!(
      first_name: "Ana",
      last_name: "Portal",
      email: "secure@example.com",
      password: "password123",
      password_confirmation: "password123",
      pushover_user_key: "uQiRzpo4DXghDmr9QzzfQu27cmVRsG"
    )

    assert_not_nil user.encrypted_password
    refute_equal "password123", user.encrypted_password
    assert_equal "uQiRzpo4DXghDmr9QzzfQu27cmVRsG", user.pushover_user_key
  end
end
