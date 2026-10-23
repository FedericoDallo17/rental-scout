require "test_helper"

class LanguageSettingsControllerTest < ActionDispatch::IntegrationTest
  test "guest browser language selects Spanish sign-in page" do
    get new_user_session_path, headers: { "Accept-Language" => "es-UY,es;q=0.9,en;q=0.8" }

    assert_response :success
    assert_select "html[lang='es']"
    assert_select ".auth-title", text: "Iniciar sesión"
    assert_select ".app-language__button--active", text: "ES"
  end

  test "guest language switch persists and overrides browser language" do
    patch language_settings_path, params: { locale: "en" },
      headers: { "HTTP_REFERER" => new_user_session_url }

    assert_redirected_to new_user_session_url
    assert_equal "en", cookies[:locale]

    get new_user_session_path, headers: { "Accept-Language" => "es-UY,es;q=0.9" }
    assert_select "html[lang='en']"
    assert_select ".auth-title", text: "Sign in"
  end

  test "guest cannot persist an unsupported locale" do
    patch language_settings_path, params: { locale: "fr" }

    assert_response :unprocessable_entity
    assert_nil cookies[:locale]
  end

  test "user switches to Spanish and subsequent pages use the persisted locale" do
    user = create_user!("spanish@example.com")
    sign_in user

    patch language_settings_path, params: { locale: "es" }

    assert_redirected_to root_path
    assert_equal "es", user.reload.locale
    assert_equal "es", cookies[:locale]
    follow_redirect!
    assert_select "html[lang='es']"
    assert_select "[data-onboarding-welcome] a", text: "Armar mi primera búsqueda"
    assert_includes response.body, "Cerrar sesión"
    assert_includes response.body, "Idioma actualizado."
  end

  test "new and other users remain in English" do
    spanish_user = create_user!("spanish-isolated@example.com", locale: "es")
    english_user = create_user!("english-isolated@example.com")

    sign_in spanish_user
    get listings_path
    assert_select "html[lang='es']"
    sign_out spanish_user

    sign_in english_user
    get listings_path
    assert_select "html[lang='en']"
    assert_select "[data-onboarding-welcome] a", text: "Set up my first search"
    assert_equal "en", english_user.locale
  end

  test "unsupported locale is rejected" do
    user = create_user!("invalid-locale@example.com")
    sign_in user

    patch language_settings_path, params: { locale: "fr" }

    assert_response :unprocessable_entity
    assert_equal "en", user.reload.locale
  end

  test "Spanish preference translates signed-in product surfaces" do
    user = create_user!("spanish-surfaces@example.com", locale: "es", admin: true)
    sign_in user

    get new_search_preference_path
    assert_select "form[data-onboarding]"
    assert_includes response.body, "Barrios"

    get admin_root_path
    assert_includes response.body, "Ejecuciones de scraping"
    assert_includes response.body, "¿Qué tan confiable es la ubicación?"

    get edit_notification_settings_path
    assert_includes response.body, "Avisos"
    assert_includes response.body, "Los datos de tus notificaciones permanecen privados"
  end

  private

  def create_user!(email, locale: "en", admin: false)
    User.create!(
      first_name: "Locale",
      last_name: "User",
      email:,
      password: "password123",
      password_confirmation: "password123",
      locale:,
      admin:
    )
  end
end
