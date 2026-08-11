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

  test "guest cannot send a test notification" do
    post test_delivery_notification_settings_path

    assert_redirected_to new_user_session_path
  end

  test "renders configured state without exposing the saved key" do
    user = create_user!(email: "settings-view@example.com", pushover_user_key: "secret-user-key")
    sign_in user

    search = user.search_preferences.create!(name: "Pocitos", location_query: "Pocitos", notifications_enabled: true)

    get edit_notification_settings_path

    assert_response :success
    assert_select ".notification-settings__channels .notification-settings__channel", count: 2
    assert_select ".notification-settings__web-push h2", text: "Browser notifications"
    assert_select ".notification-settings__pushover h2", text: "Pushover"
    assert_select ".notification-settings__pushover .notification-settings__channel-state--ready", text: "Pushover is connected."
    assert_select "[data-web-push-settings][data-vapid-public-key]" do
      assert_select "h2", text: "Browser notifications"
      assert_select "button[data-web-push-toggle]", text: "Enable on this device"
      assert_select ".notification-settings__device-guides" do
        assert_select "h3", text: "Setup instructions by device"
        assert_select "details[data-device-guide]", count: 4
        assert_select "details[data-device-guide='ios']" do
          assert_select "summary", text: "iPhone or iPad"
          assert_select "li", count: 5
          assert_select "li", text: /Open Rental Scout in Safari—not Chrome/
          assert_select "li", text: /Add to Home Screen/
        end
        assert_select "details[data-device-guide='android'] summary", text: "Android phone or tablet"
        assert_select "details[data-device-guide='mac'] summary", text: "Mac"
        assert_select "details[data-device-guide='windows'] summary", text: "Windows PC"
      end
    end
    assert_select ".notification-settings__status", text: /Notifications connected/
    assert_select ".notification-settings__explanation" do
      assert_select "h2", text: "What is Pushover?"
      assert_select "p", text: /independent notification service/
      assert_select "h3", text: "Why do we use Pushover?"
      assert_select "p", text: /even when Rental Scout isn't open/
      assert_select "li", text: /Pushover app and a Pushover account/
      assert_select "li", text: /separate from Rental Scout/
    end
    assert_select ".notification-settings__searches" do
      assert_select "a[href='#{edit_search_preference_path(search)}']", text: "Pocitos"
      assert_select "p", text: "1 saved search has notifications enabled."
    end
    assert_select "form[action='#{test_delivery_notification_settings_path}'] button", text: "Send test notification"
    assert_select "details summary", text: "Replace Pushover key"
    assert_select "label", text: "New Pushover key"
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
    assert_select ".notification-settings__explanation" do
      assert_select "h2", text: "¿Qué es Pushover?"
      assert_select "p", text: /servicio independiente de notificaciones/
      assert_select "h3", text: "¿Por qué usamos Pushover?"
      assert_select "p", text: /incluso cuando Rental Scout no está abierto/
      assert_select "li", text: /Necesitás la aplicación de Pushover/
      assert_select "li", text: /independiente de Rental Scout/
    end
    assert_select ".notification-settings__status", text: /Configurá las notificaciones/
    assert_select ".notification-settings__device-guides" do
      assert_select "h3", text: "Instrucciones según tu dispositivo"
      assert_select "details[data-device-guide]", count: 4
      assert_select "details[data-device-guide='ios']", text: /Agregar a inicio/
      assert_select "details[data-device-guide='android'] summary", text: "Teléfono o tablet Android"
      assert_select "details[data-device-guide='windows'] summary", text: "PC con Windows"
    end
    assert_select ".notification-settings__steps" do
      assert_select "li", count: 3
      assert_select "strong", text: "Instalá Pushover"
      assert_select "a[href='https://pushover.net/']", text: "Visitar el sitio de Pushover"
      assert_select "a[href='https://pushover.net/login']", text: "Obtener mi clave de Pushover"
    end
    assert_select "label", text: "Clave de Pushover"
    assert_select ".notification-settings__troubleshooting", text: /¿No recibís alertas?/
  end

  test "shows a connected state and test action for a Web Push-only user" do
    user = create_user!(email: "settings-web-push@example.com")
    user.push_subscriptions.create!(
      endpoint: "https://push.example.test/settings", p256dh: "public-key", auth: "auth-secret"
    )
    sign_in user

    get edit_notification_settings_path

    assert_response :success
    assert_select ".notification-settings__status", text: /Notifications connected/
    assert_select "form[action='#{test_delivery_notification_settings_path}'] button", text: "Send test notification"
    assert_select ".notification-settings__pushover" do
      assert_select "h2", text: "Pushover"
      assert_select ".notification-settings__channel-state", text: "Pushover is not connected yet."
    end
  end

  test "updates only the signed in user's key" do
    user = create_user!(email: "settings-update@example.com")
    other_user = create_user!(email: "settings-other@example.com", pushover_user_key: "other-key")
    sign_in user

    client = validating_client
    with_pushover_client(client) do
      patch notification_settings_path, params: { user: { pushover_user_key: "new-user-key" } }
    end

    assert_redirected_to edit_notification_settings_path
    assert_equal ["new-user-key"], client.validated_keys
    assert_equal "new-user-key", user.reload.pushover_user_key
    assert_equal "other-key", other_user.reload.pushover_user_key
  end

  test "does not save a key Pushover rejects" do
    user = create_user!(email: "settings-invalid-key@example.com", pushover_user_key: "keep-key")
    sign_in user
    client = Object.new
    client.define_singleton_method(:validate_user_key!) do |**|
      raise Notifications::PushoverClient::InvalidUserKey, "raw provider response"
    end

    with_pushover_client(client) do
      patch notification_settings_path, params: { user: { pushover_user_key: "bad-key" } }
    end

    assert_redirected_to edit_notification_settings_path
    assert_equal "keep-key", user.reload.pushover_user_key
    assert_equal "That Pushover key wasn't recognized. Check it and try again.", flash[:alert]
    assert_not_includes flash[:alert], "raw provider response"
  end

  test "reports a temporary validation outage without saving the key" do
    user = create_user!(email: "settings-outage@example.com")
    sign_in user
    client = Object.new
    client.define_singleton_method(:validate_user_key!) do |**|
      raise Notifications::PushoverClient::ServiceUnavailable, "provider is down"
    end

    with_pushover_client(client) do
      patch notification_settings_path, params: { user: { pushover_user_key: "new-key" } }
    end

    assert_nil user.reload.pushover_user_key
    assert_equal "Pushover couldn't be reached. Try again shortly.", flash[:alert]
  end

  test "sends a localized test notification using the saved key" do
    user = create_user!(email: "settings-test@example.com", pushover_user_key: "saved-key")
    sign_in user
    deliveries = []
    client = Object.new
    client.define_singleton_method(:deliver) { |**attributes| deliveries << attributes }

    with_pushover_client(client) do
      post test_delivery_notification_settings_path
    end

    assert_redirected_to edit_notification_settings_path
    assert_equal "Test sent—check your phone.", flash[:notice]
    assert_equal 1, deliveries.size
    assert_equal "saved-key", deliveries.first.fetch(:user_key)
    assert_equal "Rental Scout test", deliveries.first.fetch(:title)
    assert_equal listings_url, deliveries.first.fetch(:url)
  end

  test "test notification explains when setup is missing" do
    user = create_user!(email: "settings-test-missing@example.com")
    sign_in user

    post test_delivery_notification_settings_path

    assert_redirected_to edit_notification_settings_path
    assert_equal "Connect Pushover before sending a test notification.", flash[:alert]
  end

  test "test notification gives an actionable message for an invalid saved key" do
    user = create_user!(email: "settings-test-invalid@example.com", pushover_user_key: "old-key")
    sign_in user
    client = Object.new
    client.define_singleton_method(:deliver) do |**|
      raise Notifications::PushoverClient::InvalidUserKey, "provider details"
    end

    with_pushover_client(client) do
      post test_delivery_notification_settings_path
    end

    assert_equal "Your saved Pushover key is no longer valid. Replace it to resume phone notifications.", flash[:alert]
    assert_not_includes flash[:alert], "provider details"
  end

  test "test notification reports a temporary delivery problem" do
    user = create_user!(email: "settings-test-outage@example.com", pushover_user_key: "saved-key")
    sign_in user
    client = Object.new
    client.define_singleton_method(:deliver) do |**|
      raise Notifications::PushoverClient::ServiceUnavailable, "provider details"
    end

    with_pushover_client(client) do
      post test_delivery_notification_settings_path
    end

    assert_equal "The test notification couldn't be delivered. Check Pushover and try again.", flash[:alert]
  end

  test "blank key preserves the configured key" do
    user = create_user!(email: "settings-blank@example.com", pushover_user_key: "keep-this-key")
    sign_in user

    patch notification_settings_path, params: { user: { pushover_user_key: "" } }

    assert_equal "keep-this-key", user.reload.pushover_user_key
  end

  test "pauses and resumes Pushover without removing the key" do
    user = create_user!(email: "settings-pause@example.com", pushover_user_key: "keep-this-key")
    sign_in user

    patch notification_settings_path, params: { user: { pushover_enabled: "false" } }

    assert_not user.reload.pushover_enabled?
    assert_equal "keep-this-key", user.pushover_user_key

    get edit_notification_settings_path
    assert_select ".notification-settings__pushover", text: /notifications are paused/
    assert_select "form[action='#{notification_settings_path}'] button", text: "Resume Pushover notifications"

    patch notification_settings_path, params: { user: { pushover_enabled: "true" } }

    assert user.reload.pushover_enabled?
    assert_equal "keep-this-key", user.pushover_user_key
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

  def validating_client
    client = Object.new
    validated_keys = []
    client.define_singleton_method(:validated_keys) { validated_keys }
    client.define_singleton_method(:validate_user_key!) { |user_key:| validated_keys << user_key }
    client
  end

  def with_pushover_client(client)
    original_new = Notifications::PushoverClient.method(:new)
    Notifications::PushoverClient.define_singleton_method(:new) { client }
    yield
  ensure
    Notifications::PushoverClient.define_singleton_method(:new, original_new)
  end

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
