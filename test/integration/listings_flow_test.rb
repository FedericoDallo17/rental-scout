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
    assert_includes response.body, ".app-header"
    assert_includes response.body, ".app-sign-out__button"
    assert_includes response.body, ".search-form-shell"
    assert_includes response.body, ".search-form-aside"
    assert_includes response.body, ".search-link__count"
    assert_includes response.body, ".listing-card__score"
    assert_includes response.body, ".runs-workbench"
    refute_includes response.body, ".flash {"
  end

  test "signed in user root goes to the listings portal" do
    sign_in create_user!(email: "portal@example.com")

    get root_url

    assert_response :success
    assert_includes response.body, "Scraped Apartments"
    assert_select "a[href='#{edit_notification_settings_path}']", text: "Notifications"
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

  test "signed in sidebar renders hybrid search workbench cards with counts" do
    user = create_user!(email: "sidebar-workbench@example.com")
    sign_in user
    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source_sidebar_workbench")
    search = user.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
    Listing.create!(listing_source: source, title: "Pocitos One", canonical_url: "https://example.test/pocitos-one", location_text: "Pocitos", in_scope: true)
    Listing.create!(listing_source: source, title: "Pocitos Two", canonical_url: "https://example.test/pocitos-two", location_text: "Pocitos", in_scope: true)

    get listings_path(search_id: search.id)

    assert_response :success
    assert_select ".search-workbench"
    assert_select ".search-sidebar__item .search-link__count", text: "2 listings"
    assert_select ".search-sidebar__item .search-sidebar__edit", text: "Edit"
  end

  test "signed in listings route shows an empty saved-search state when none exist" do
    sign_in create_user!(email: "empty-root@example.com")

    source = ListingSource.find_or_create_by!(adapter_key: "mock_source") do |listing_source|
      listing_source.name = "Mock Source"
    end
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
    source = ListingSource.find_or_create_by!(adapter_key: "mock_source") do |listing_source|
      listing_source.name = "Mock Source"
    end

    create_listing!(
      listing_source: source,
      title: "Pocitos Bright Loft",
      canonical_url: "https://example.test/listings/pocitos-bright-loft",
    location_text: "Pocitos, Montevideo",
    price_cents: 2100000,
    square_meters: 48,
    bedrooms: 2,
    expenses_cents: 450000,
    expenses_currency: "UYU",
    parking_spaces: 1,
    property_type: "Apartamento"
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
  assert_select "section.listings-grid .listing-card__image", count: 0
  assert_select "section.listings-grid article.listing-card h2", text: "Pocitos Bright Loft"
  assert_select "section.listings-grid article.listing-card h2", text: "Pocitos Patio Studio"
    assert_select "section.listings-grid article.listing-card .listing-card__price", text: "USD 17.500"
    assert_select "section.listings-grid article.listing-card .listing-card__facts dt", text: "Expenses"
    assert_select "section.listings-grid article.listing-card .listing-card__facts dd", text: "UYU 4.500"
  assert_select "section.listings-grid article.listing-card .listing-card__facts dt", text: "Parking"
  assert_select "section.listings-grid article.listing-card .listing-card__facts dd", text: "1"
  assert_select "section.listings-grid article.listing-card .listing-card__facts dt", text: "Type", count: 0
  assert_select "section.listings-grid article.listing-card .listing-card__facts dd", text: "Apartamento", count: 0
  assert_select "section.listings-grid article.listing-card .listing-card__fact--source", text: /Mock Source/
  assert_select "section.listings-grid article.listing-card a.listing-card__link[href='https://example.test/listings/pocitos-bright-loft'][target='_blank'][rel='noopener noreferrer']", count: 1
  assert_select "section.listings-grid article.listing-card .listing-card__location", text: "Pocitos, Montevideo"
    assert_select "section.listings-grid article.listing-card .listing-card__location", text: "POCITOS"
    assert_select "section.listings-grid article.listing-card .listing-card__facts dd", text: "2", count: 1
  assert_select "section.listings-grid article.listing-card .listing-card__facts dd", text: "1", count: 2
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

  test "feed presents the InfoCasas source without internal API terminology" do
    user = create_user!(email: "source-label@example.com")
    sign_in user
    search = user.search_preferences.create!(name: "Centro", location_query: "Centro")
    source = ListingSource.create!(name: "InfoCasas API", adapter_key: "info_casas_api")
    create_listing!(
      listing_source: source,
      title: "Centro rental",
      canonical_url: "https://example.test/centro-rental",
      location_text: "Centro"
    )

    get listings_path(search_id: search.id)

    assert_select ".listing-card__facts dd", text: "InfoCasas"
    assert_not_includes response.body, "InfoCasas API"
  end

  test "signed in feed ranks matches by score and explains the score" do
    user = create_user!(email: "ranked-feed@example.com")
    sign_in user
    search = user.search_preferences.create!(
      name: "Ranked Pocitos",
      location_query: "Pocitos",
      max_price_cents: 4_000_000,
      min_bedrooms: 1
    )
    source = ListingSource.create!(name: "Ranking Source", adapter_key: "ranking_source")
    create_listing!(
      listing_source: source,
      title: "Good Match",
      canonical_url: "https://example.test/good-match",
      location_text: "Pocitos",
      currency: "UYU",
      price_cents: 3_000_000,
      bedrooms: 2,
      square_meters: 55,
      expenses_cents: 0,
      parking_spaces: 0,
      property_type: "Apartamento"
    )
    create_listing!(
      listing_source: source,
      title: "Okay Match",
      canonical_url: "https://example.test/okay-match",
      location_text: "Pocitos",
      currency: "UYU",
      price_cents: 3_900_000,
      bedrooms: 1
    )

    get listings_path(search_id: search.id)

    assert_response :success
    assert_equal ["Good Match", "Okay Match"], css_select(".listing-card h2").map { |node| node.text.strip }
    assert_select ".listing-card", count: 2 do |cards|
      assert_select cards.first, ".listing-card__score", text: /100\/100 match/
      assert_select cards.first, ".listing-card__explanation", text: "25% under budget · 2 bedrooms · Complete details"
    end
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
