require "test_helper"

class ListingsFlowTest < ActionDispatch::IntegrationTest
  test "guest root redirects to sign in" do
    get root_url

    assert_redirected_to new_user_session_path
  end

  test "layout includes the application stylesheet asset" do
    get new_user_session_url

    assert_response :success
    assert_match %r{<link[^>]+href="[^"]*application[^"]*\.css[^"]*"}, response.body
  end

  test "application stylesheet asset is served" do
    get "/stylesheets/application.css"

    assert_response :success
    assert_match ":root", response.body
    assert_includes response.body, ".auth-body"
    assert_includes response.body, ".auth-card"
    assert_includes response.body, ".auth-submit"
    assert_includes response.body, ".auth-flash"
    assert_includes response.body, ".app-flash"
    refute_includes response.body, ".flash {"
  end

  test "signed in user root goes to the listings portal" do
    sign_in create_user!(email: "portal@example.com")

    get root_url

    assert_response :success
    assert_includes response.body, "Scraped Apartments"
  end

  test "signed in root defaults to the first saved search feed" do
    user = create_user!(email: "root-feed@example.com")
    sign_in user

    user.search_preferences.create!(name: "Centro", location_query: "Centro")
    user.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")

    get listings_url

    assert_response :success
    assert_includes response.body, "Centro"
    assert_select ".feed-header__context", text: /Browsing Centro/
    assert_select ".feed-header__refresh-cue", text: /Updated automatically/
    assert_select "nav.search-sidebar__nav a.search-link.search-link--active .search-link__name", text: "Centro"
  end

  test "signed in listings route shows an empty saved-search state when none exist" do
    sign_in create_user!(email: "empty-root@example.com")

    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
    create_listing!(
      listing_source: source,
      title: "Centro Loft",
      canonical_url: "https://example.test/listings/centro-loft",
      location_text: "Centro"
    )

    get listings_url

    assert_response :success
    assert_select ".feed-header__context", count: 0
    assert_select ".feed-header__count", text: "0 listings"
    assert_select ".feed-empty-state", text: /Save your first search to start a feed tailored to you/
    assert_select "section.listings-grid article.listing-card", count: 0
    assert_no_match "Centro Loft", response.body
  end

  test "signed in listings route shows saved searches sidebar and listings grid" do
    user = create_user!(email: "homepage@example.com")
    sign_in user

    pocitos = user.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
    user.search_preferences.create!(name: "Centro", location_query: "Centro")
    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")

    create_listing!(
      listing_source: source,
      title: "Pocitos Bright Loft",
      canonical_url: "https://example.test/listings/pocitos-bright-loft",
      location_text: "Pocitos, Montevideo",
      price_cents: 2100000,
      square_meters: 48,
      bedrooms: 2
    )
    create_listing!(
      listing_source: source,
      title: "Pocitos Patio Studio",
      canonical_url: "https://example.test/listings/pocitos-patio-studio",
      location_text: "POCITOS",
      price_cents: 1750000,
      square_meters: 39,
      bedrooms: 1
    )
    create_listing!(
      listing_source: source,
      title: "Centro Loft",
      canonical_url: "https://example.test/listings/centro-loft",
      location_text: "Centro",
      price_cents: 1600000,
      square_meters: 41
    )

    get listings_url(search_id: pocitos.id)

    assert_response :success
    assert_select "aside.search-sidebar h2", text: "Saved searches"
    assert_select "nav.search-sidebar__nav a.search-link", count: 2
    assert_select "nav.search-sidebar__nav a.search-link.search-link--active[href='#{listings_path(search_id: pocitos.id)}']", count: 1
    assert_select "nav.search-sidebar__nav a.search-link.search-link--active .search-link__name", text: "Pocitos"
    assert_select "nav.search-sidebar__nav a.search-link.search-link--active .search-link__meta", text: "Pocitos"
    assert_select ".feed-header h1", text: "Scraped Apartments"
    assert_select ".feed-header__context", text: /Browsing Pocitos/
    assert_select ".feed-header__count", text: "2 listings"
    assert_select "section.listings-grid article.listing-card", count: 2
    assert_select "section.listings-grid article.listing-card h2", text: "Pocitos Bright Loft"
    assert_select "section.listings-grid article.listing-card h2", text: "Pocitos Patio Studio"
    assert_select "section.listings-grid article.listing-card .listing-card__location", text: "Pocitos, Montevideo"
    assert_select "section.listings-grid article.listing-card .listing-card__location", text: "POCITOS"
    assert_select "section.listings-grid article.listing-card .listing-card__facts dd", text: "2", count: 1
    assert_select "section.listings-grid article.listing-card .listing-card__facts dd", text: "1", count: 1
    assert_select "section.listings-grid article.listing-card .listing-card__url", text: "https://example.test/listings/pocitos-bright-loft"
    assert_select "section.listings-grid article.listing-card .listing-card__url", text: "https://example.test/listings/pocitos-patio-studio"
    assert_no_match "Centro Loft", response.body
  end

  test "signed in listings route scopes saved searches to the current user" do
    current_user = create_user!(email: "scoped-flow@example.com")
    other_user = create_user!(email: "hidden-flow@example.com")
    sign_in current_user

    current_user.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
    other_user.search_preferences.create!(name: "Centro", location_query: "Centro")

    get listings_url

    assert_response :success
    assert_select "nav.search-sidebar__nav a.search-link .search-link__name", text: "Pocitos"
    assert_select "nav.search-sidebar__nav a.search-link .search-link__name", text: "Centro", count: 0
  end

  test "signed in listings route stays on the listings layout" do
    sign_in create_user!(email: "listings-layout@example.com")

    get listings_url

    assert_response :success
    assert_includes response.body, "feed-layout"
    refute_includes response.body, "auth-shell"
  end

  test "guest is redirected away from listings route" do
    get listings_url

    assert_redirected_to new_user_session_path
  end

  private

  def create_listing!(**attributes)
    Listing.create!({
      currency: "USD",
      raw_payload: {},
      external_id: SecureRandom.uuid
    }.merge(attributes))
  end

  def create_user!(email:)
    User.create!(
      first_name: "Flow",
      last_name: "User",
      email: email,
      password: "password123",
      password_confirmation: "password123"
    )
  end
end
