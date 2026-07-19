require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  test "admin sees users and can promote another user" do
    admin = create_user!("admin-users@example.com", admin: true)
    user = create_user!("member@example.com")
    user.search_preferences.create!(name: "Centro", location_query: "centro")
    sign_in admin

    get admin_users_path

    assert_response :success
    assert_select "h1", text: "Users"
    assert_select ".runs-header__count", text: "2 users"
    assert_includes response.body, user.email
    assert_select "form[action='#{admin_user_path(user)}'] button", text: "Make admin"

    patch admin_user_path(user), params: { user: { admin: "1" } }

    assert_redirected_to admin_users_path
    assert_predicate user.reload, :admin?
  end

  test "admin cannot demote their own account" do
    admin = create_user!("self-admin@example.com", admin: true)
    sign_in admin

    patch admin_user_path(admin), params: { user: { admin: "0" } }

    assert_redirected_to admin_users_path
    assert_predicate admin.reload, :admin?
  end

  test "normal user cannot manage roles" do
    user = create_user!("normal-role@example.com")
    target = create_user!("target-role@example.com")
    sign_in user

    get admin_users_path
    assert_response :not_found

    sign_in user
    patch admin_user_path(target), params: { user: { admin: "1" } }
    assert_response :not_found
    assert_not target.reload.admin?
  end

  private

  def create_user!(email, admin: false)
    User.create!(
      first_name: "Admin",
      last_name: "User",
      email:,
      password: "password123",
      password_confirmation: "password123",
      admin:
    )
  end
end
