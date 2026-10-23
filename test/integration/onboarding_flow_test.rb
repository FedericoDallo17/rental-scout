require "test_helper"

class OnboardingFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_push_test_user!
    @user.update!(locale: "es")
    sign_in @user
  end

  test "empty account has a welcome and a concrete first action" do
    get listings_path
    assert_select "[data-onboarding-welcome] h1", text: "Tu próximo lugar puede estar por sonar."
    assert_select "[data-onboarding-welcome] a[href='#{new_search_preference_path}']", text: "Armar mi primera búsqueda"
    assert_select ".feed-controls", count: 0
  end

  test "first search has three accessible steps and useful defaults" do
    get new_search_preference_path
    assert_select "form[data-onboarding]"
    assert_select "[data-onboarding-panel]", count: 3
    assert_select "[data-onboarding-panel][hidden]", count: 0
    assert_select "input[name='search_preference[location_query]'][value='Montevideo']"
    assert_select "input[name='search_preference[name]'][value='Mi búsqueda']"
    assert_select "input[name='onboarding'][value='1']"
    assert_select "[data-onboarding-next][hidden]"
  end

  test "first search saves preferences then explains the remaining notification setup" do
    post search_preferences_path, params: { onboarding: "1", search_preference: {
      name: "Mi lugar", location_query: "Montevideo", operation_type: "alquiler",
      max_price: "32000", price_currency: "UYU", notifications_enabled: "1"
    } }
    search = @user.search_preferences.sole
    assert_equal 3_200_000, search.max_price_cents
    assert_redirected_to listings_path(search_id: search.id)
    follow_redirect!
    assert_select ".app-flash", count: 1
    assert_select "[data-onboarding-complete] h2", text: "Tu búsqueda ya está en marcha."
    assert_select "[data-onboarding-complete] a[href='#{edit_notification_settings_path}']", text: "Conectar mis avisos"
    assert_select ".feed-empty-state h2", text: "Todavía no hay coincidencias recientes."
    assert_select ".feed-empty-state a[href='#{edit_search_preference_path(search)}']", text: "Ajustar mi búsqueda"
    get listings_path
    assert_select "[data-onboarding-complete]", count: 0
    assert_select "[data-onboarding-welcome]", count: 0
  end

  test "validation errors keep onboarding and entered preferences" do
    zone = create_zone
    post search_preferences_path, params: { onboarding: "1", search_preference: {
      name: "", location_query: "Montevideo", max_price: "31500", price_currency: "USD", zone_ids: [zone.id]
    } }
    assert_response :unprocessable_entity
    assert_select "form[data-onboarding] .form-errors"
    assert_select "input[name='search_preference[max_price]'][value='31500']"
    assert_select "select[name='search_preference[price_currency]'] option[value='USD'][selected]"
    assert_select "input[name='search_preference[zone_ids][]'][value='#{zone.id}'][checked]"
    assert_select "[data-onboarding-summary-budget]", text: /USD.*31/
    assert_equal 0, @user.search_preferences.count
  end

  test "returning accounts keep the editor and cannot trigger a new first-search completion" do
    @user.search_preferences.create!(name: "Existente", location_query: "Montevideo")
    get new_search_preference_path
    assert_select "form[data-onboarding]", count: 0
    assert_select ".search-form-shell"
    post search_preferences_path, params: { onboarding: "1", search_preference: { name: "Otra", location_query: "Montevideo" } }
    follow_redirect!
    assert_select "[data-onboarding-complete]", count: 0
  end

  test "connected browser alerts confirm delivery readiness without asking again" do
    @user.push_subscriptions.create!(endpoint: "https://push.example.test/onboarding", p256dh: "key", auth: "secret")
    post search_preferences_path, params: { onboarding: "1", search_preference: { name: "Lista", location_query: "Montevideo", notifications_enabled: "1" } }
    follow_redirect!
    assert_select "[data-onboarding-complete]", text: /Tus avisos están conectados/
    assert_select "[data-onboarding-complete] a[href='#{edit_notification_settings_path}']", count: 0
  end

  test "saving without alerts keeps notification setup optional" do
    post search_preferences_path, params: { onboarding: "1", search_preference: { name: "Silenciosa", location_query: "Montevideo", notifications_enabled: "0" } }
    follow_redirect!
    assert_select "[data-onboarding-complete]", text: /activar avisos cuando quieras/
    assert_select "[data-onboarding-complete] a[href='#{edit_notification_settings_path}']", count: 0
    assert_not @user.search_preferences.sole.notifications_enabled?
  end

  test "a saved but disabled phone key does not claim alerts are connected" do
    @user.update!(pushover_user_key: "disabled-key", pushover_enabled: false)
    post search_preferences_path, params: { onboarding: "1", search_preference: { name: "Pendiente", location_query: "Montevideo", notifications_enabled: "1" } }
    follow_redirect!
    assert_select "[data-onboarding-complete] a[href='#{edit_notification_settings_path}']", text: "Conectar mis avisos"
  end

  test "first search shows only real listings matching its zones and budget" do
    zone = create_zone
    source = ListingSource.create!(name: "Onboarding source", adapter_key: "onboarding_test")
    source.listings.create!(title: "Lugar en Cordón", canonical_url: "https://example.test/first-match",
      location_text: "Cordón, Montevideo", source_neighborhood: "Cordón", location_resolution_status: "fallback", in_scope: true,
      operation_type: "alquiler", price_cents: 2_600_000, currency: "UYU")
    source.listings.create!(title: "Fuera del presupuesto", canonical_url: "https://example.test/too-expensive",
      location_text: "Cordón, Montevideo", source_neighborhood: "Cordón", location_resolution_status: "fallback", in_scope: true,
      operation_type: "alquiler", price_cents: 4_500_000, currency: "UYU")

    post search_preferences_path, params: { onboarding: "1", search_preference: {
      name: "Cordón", location_query: "Montevideo", zone_ids: [zone.id], max_price: "32000", price_currency: "UYU"
    } }
    follow_redirect!
    assert_select ".listing-card h2", text: "Lugar en Cordón"
    assert_select ".listing-card h2", text: "Fuera del presupuesto", count: 0
    assert_equal [zone.id], @user.search_preferences.sole.zone_ids
  end

  private

  def create_zone
    Zone.create!(name: "Cordón", slug: "cordon-onboarding", aliases: ["Cordón"],
      geom: Zone.polygon_from_coordinates([
        [-56.17, -34.92], [-56.14, -34.92], [-56.14, -34.89], [-56.17, -34.89], [-56.17, -34.92]
      ]))
  end
end
