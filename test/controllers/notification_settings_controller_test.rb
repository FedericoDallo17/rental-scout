require "test_helper"

class NotificationSettingsControllerTest < ActionDispatch::IntegrationTest
  test "guest cannot open notification settings" do
    get edit_notification_settings_path

    assert_redirected_to new_user_session_path
  end

  test "guest cannot update notification settings" do
    user = create_user!(email: "settings-guest-update@example.com", pushover_user_key: "keep-key")

    patch notification_settings_path, params: { user: { pushover_user_key: "attacker-key" } }

    assert_redirected_to new_user_session_path
    assert_equal "keep-key", user.reload.pushover_user_key
  end

  test "renders configured state without exposing the saved key" do
    user = create_user!(email: "settings-view@example.com", pushover_user_key: "secret-user-key")
    sign_in user

    get edit_notification_settings_path

    assert_response :success
    assert_select ".notification-settings__status", text: /Ready/
    assert_select ".notification-settings__intro", text: /third-party notification app/
    assert_select ".notification-settings__resources[aria-label='Pushover help']" do
      assert_select "a[href='https://pushover.net/'][target='_blank']", text: "What is Pushover?"
      assert_select "a[href='https://pushover.net/login'][target='_blank']", text: "Get my Pushover key"
    end
    assert_select "label", text: "Replace Pushover key"
    assert_select "input[name='user[pushover_user_key]'][type='password'][value]", count: 0
    assert_select "form[action='#{notification_settings_path}'] button.notification-settings__remove-button", text: "Remove key"
    assert_select "button.notification-settings__remove-button[data-turbo-confirm]"
    assert_no_match "secret-user-key", response.body
  end

  test "explains Pushover setup in the user's language" do
    user = create_user!(email: "settings-es@example.com")
    user.update!(locale: "es")
    sign_in user

    get edit_notification_settings_path

    assert_response :success
    assert_select ".notification-settings__intro", text: /aplicación externa de notificaciones/
    assert_select ".notification-settings__intro", text: /Instalá Pushover, creá una cuenta/
    assert_select "label", text: "Clave de Pushover"
    assert_select "a[href='https://pushover.net/']", text: "¿Qué es Pushover?"
    assert_select "a[href='https://pushover.net/login']", text: "Obtener mi clave de Pushover"
  end

  test "updates only the signed in user's key" do
    user = create_user!(email: "settings-update@example.com")
    other_user = create_user!(email: "settings-other@example.com", pushover_user_key: "other-key")
    sign_in user

    patch notification_settings_path, params: { user: { pushover_user_key: "new-user-key" } }

    assert_redirected_to edit_notification_settings_path
    assert_equal "new-user-key", user.reload.pushover_user_key
    assert_equal "other-key", other_user.reload.pushover_user_key
  end

  test "blank key preserves the configured key" do
    user = create_user!(email: "settings-blank@example.com", pushover_user_key: "keep-this-key")
    sign_in user

    patch notification_settings_path, params: { user: { pushover_user_key: "" } }

    assert_equal "keep-this-key", user.reload.pushover_user_key
  end

  test "explicit removal clears the configured key" do
    user = create_user!(email: "settings-remove@example.com", pushover_user_key: "remove-this-key")
    sign_in user

    delete notification_settings_path

    assert_redirected_to edit_notification_settings_path
    assert_nil user.reload.pushover_user_key
  end

  test "pushover key is filtered as a sensitive parameter" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    assert_equal "[FILTERED]", filter.filter("pushover_user_key" => "secret").fetch("pushover_user_key")
  end

  private

  def create_user!(email:, pushover_user_key: nil)
    User.create!(
      first_name: "Settings",
      last_name: "Owner",
      email: email,
      password: "password123",
      password_confirmation: "password123",
      pushover_user_key: pushover_user_key
    )
  end
end
