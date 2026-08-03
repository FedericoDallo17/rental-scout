require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  test "guest root redirects to sign in and sign in page is accessible" do
    get root_url
    assert_redirected_to new_user_session_path

    get new_user_session_url
    assert_response :success
  end

  test "sign in page renders the shared auth shell" do
    get new_user_session_url

    assert_response :success
    assert_includes response.body, "auth-card"
    assert_select "header nav", count: 0
    assert_select ".auth-shell", count: 1
    assert_select ".auth-card", count: 1
    assert_select ".auth-brand", text: "Rental Scout Lite"
    assert_select ".auth-header", count: 1
    assert_select ".auth-title", text: "Sign in"
    assert_select ".auth-copy", text: /Sign in to continue/
    assert_select "form.auth-form", count: 1
    assert_select ".auth-submit", text: "Sign in"
    assert_select ".auth-links a", text: "Sign up"
    assert_select ".auth-links a", text: "Forgot your password?"
  end

  test "sign up page renders the auth shell and custom fields" do
    get new_user_registration_url

    assert_response :success
    assert_select ".auth-shell", count: 1
    assert_select ".auth-title", text: "Create account"
    assert_select ".auth-copy", text: /Create your account/
    assert_select "form.auth-form", count: 1
    assert_select ".auth-links a", text: "Log in"
    assert_includes response.body, 'name="user[first_name]"'
    assert_includes response.body, 'name="user[last_name]"'
    assert_includes response.body, 'name="user[pushover_user_key]"'
    assert_select "input[name='user[locale]'][type='hidden'][value='en']", count: 1
  end

  test "Spanish signup inherits the public language choice" do
    patch language_settings_path, params: { locale: "es" }

    post user_registration_path, params: {
      user: {
        first_name: "Idioma",
        last_name: "Español",
        email: "spanish-signup@example.com",
        password: "password123",
        password_confirmation: "password123",
        locale: "es"
      }
    }

    assert_equal "es", User.find_by!(email: "spanish-signup@example.com").locale
    follow_redirect!
    assert_select "html[lang='es']"
  end

  test "password reset pages render the shared auth shell" do
    get new_user_password_url

    assert_response :success
    assert_select ".auth-shell", count: 1
    assert_select ".auth-title", text: "Forgot your password?"
  end

  test "password reset edit page renders the shared auth shell with reset form structure" do
    user = User.create!(
      first_name: "Reset",
      last_name: "Target",
      email: "reset-target@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    reset_token = user.send_reset_password_instructions

    get edit_user_password_url(reset_password_token: reset_token)

    assert_response :success
    assert_select ".auth-shell", count: 1
    assert_select ".auth-card", count: 1
    assert_select ".auth-title", text: "Change your password"
    assert_select "form.auth-form", count: 1
    assert_select "input[name='user[reset_password_token]'][type='hidden'][value='#{reset_token}']", count: 1
    assert_select "form.auth-form input.auth-submit[type='submit'][value='Change password']", count: 1
  end

  test "user can sign up sign in and sign out with names and optional pushover key" do
    post user_registration_path, params: {
      user: {
        first_name: "Lara",
        last_name: "Scout",
        email: "new-user@example.com",
        password: "password123",
        password_confirmation: "password123",
        pushover_user_key: "uQiRzpo4DXghDmr9QzzfQu27cmVRsG"
      }
    }

    follow_redirect!
    assert_response :success
    assert_includes response.body, "Signed in successfully"
    assert User.exists?(email: "new-user@example.com", first_name: "Lara", last_name: "Scout", pushover_user_key: "uQiRzpo4DXghDmr9QzzfQu27cmVRsG")

    delete destroy_user_session_path
    follow_redirect!
    assert_response :success
    assert_includes response.body, "Signed out successfully"

    post user_session_path, params: {
      user: {
        email: "new-user@example.com",
        password: "password123"
      }
    }

    follow_redirect!
    assert_response :success
    assert_includes response.body, "Signed in successfully"
  end

  test "guest is redirected to sign in when requesting listings" do
    get listings_url

    assert_redirected_to new_user_session_path
  end

  test "signed in user can access listings" do
    user = User.create!(
      first_name: "View",
      last_name: "Only",
      email: "viewer@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    sign_in user

    get listings_url

    assert_response :success
    assert_includes response.body, "feed-layout"
    assert_select "header.app-header"
    assert_select "nav.app-nav"
    assert_select ".app-user__email", text: user.email
    assert_select "form.app-sign-out"
    assert_select ".app-sign-out__button", text: "Sign out"
    refute_includes response.body, "auth-shell"
  end

  test "auth flashes stay scoped to auth pages" do
    user = User.create!(
      first_name: "Flash",
      last_name: "Scope",
      email: "flash-scope@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    sign_in user
    delete destroy_user_session_path
    follow_redirect!

    assert_response :success
    assert_select ".auth-flash", text: "Signed out successfully."

    post user_session_path, params: {
      user: {
        email: user.email,
        password: "password123"
      }
    }
    follow_redirect!

    assert_response :success
    assert_select ".flash", text: "Signed in successfully."
    assert_select ".app-flash", text: "Signed in successfully."
    assert_select ".auth-flash", count: 0
  end

  test "Spanish users see translated Devise sign-in flashes" do
    user = User.create!(
      first_name: "Idioma",
      last_name: "Español",
      email: "spanish-auth@example.com",
      password: "password123",
      password_confirmation: "password123",
      locale: "es"
    )

    post user_session_path, params: {
      user: { email: user.email, password: "password123" }
    }
    follow_redirect!

    assert_response :success
    assert_select ".app-flash", text: "Iniciaste sesión correctamente."
    refute_includes response.body, "Translation missing"
  end
end
