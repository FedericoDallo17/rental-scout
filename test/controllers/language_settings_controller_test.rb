require "test_helper"

class LanguageSettingsControllerTest < ActionDispatch::IntegrationTest
  test "user switches to Spanish and subsequent pages use the persisted locale" do
    user = create_user!("spanish@example.com")
    sign_in user

    patch language_settings_path, params: { locale: "es" }

    assert_redirected_to root_path
    assert_equal "es", user.reload.locale
    follow_redirect!
    assert_select "html[lang='es']"
    assert_includes response.body, "Búsquedas guardadas"
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
    assert_includes response.body, "Saved searches"
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
    user = create_user!("spanish-surfaces@example.com", locale: "es")
    sign_in user

    get new_search_preference_path
    assert_includes response.body, "Nueva búsqueda"
    assert_includes response.body, "Barrios"

    get scraping_runs_path
    assert_includes response.body, "Ejecuciones de scraping"
    assert_includes response.body, "¿Qué tan confiable es la ubicación?"

    get edit_notification_settings_path
    assert_includes response.body, "Configuración de notificaciones"
    assert_includes response.body, "Tu clave permanece privada"
  end

  private

  def create_user!(email, locale: "en")
    User.create!(
      first_name: "Locale",
      last_name: "User",
      email:,
      password: "password123",
      password_confirmation: "password123",
      locale:
    )
  end
end
