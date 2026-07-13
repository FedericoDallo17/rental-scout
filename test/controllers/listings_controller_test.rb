require "test_helper"

class ListingsControllerTest < ActionDispatch::IntegrationTest
  test "guest is redirected away from listings" do
    get listings_path

    assert_redirected_to new_user_session_path
  end

  test "signed in user uses the selected saved search to filter the feed" do
    user = create_user!(email: "filters@example.com")
    sign_in user

    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
    Listing.create!(listing_source: source, title: "Apto Pocitos", canonical_url: "https://example.test/1", location_text: "Pocitos")
    Listing.create!(listing_source: source, title: "Centro Loft", canonical_url: "https://example.test/2", location_text: "Centro")
    pocitos = user.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
    user.search_preferences.create!(name: "Centro", location_query: "Centro")

    get listings_path(search_id: pocitos.id)

    assert_response :success
    assert_includes response.body, "Apto Pocitos"
    refute_includes response.body, "Centro Loft"
  end

  test "signed in user defaults to the aggregate of all saved searches" do
    user = create_user!(email: "default-search@example.com")
    sign_in user

    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
    Listing.create!(listing_source: source, title: "Apto Pocitos", canonical_url: "https://example.test/1", location_text: "Pocitos")
    Listing.create!(listing_source: source, title: "Centro Loft", canonical_url: "https://example.test/2", location_text: "Centro")
    user.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
    user.search_preferences.create!(name: "Centro", location_query: "Centro")

    get listings_path

    assert_response :success
    assert_includes response.body, "All saved-search matches"
    assert_includes response.body, "Apto Pocitos"
    assert_includes response.body, "Centro Loft"
  end

  test "signed in user selected saved search honors location price and bedroom fields" do
    user = create_user!(email: "search-fields@example.com")
    sign_in user

    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
    Listing.create!(
      listing_source: source,
      title: "Pocitos Family Apartment",
    canonical_url: "https://example.test/3",
    location_text: "Pocitos, Montevideo",
    price_cents: 2300000,
    currency: "UYU",
    bedrooms: 2
  )
    Listing.create!(
      listing_source: source,
      title: "Pocitos Studio",
    canonical_url: "https://example.test/4",
    location_text: "Pocitos",
    price_cents: 2100000,
    currency: "UYU",
    bedrooms: 0
  )
    Listing.create!(
      listing_source: source,
      title: "Pocitos Luxury Penthouse",
    canonical_url: "https://example.test/5",
    location_text: "Pocitos Nuevo",
    price_cents: 3200000,
    currency: "UYU",
    bedrooms: 3
  )
    Listing.create!(
      listing_source: source,
      title: "Centro Family Apartment",
    canonical_url: "https://example.test/6",
    location_text: "Centro, Montevideo",
    price_cents: 2200000,
    currency: "UYU",
    bedrooms: 2
  )
    pocitos = user.search_preferences.create!(
      name: "Pocitos families",
      location_query: "pocitos",
      min_price_cents: 2000000,
      max_price_cents: 2500000,
      min_bedrooms: 2
    )

    get listings_path(search_id: pocitos.id)

    assert_response :success
    assert_includes response.body, "Pocitos Family Apartment"
    refute_includes response.body, "Pocitos Studio"
    refute_includes response.body, "Pocitos Luxury Penthouse"
    refute_includes response.body, "Centro Family Apartment"
  end

  test "signed in user sees an empty state when there are no saved searches" do
    sign_in create_user!(email: "empty-state@example.com")

    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
    Listing.create!(listing_source: source, title: "Apto Pocitos", canonical_url: "https://example.test/1")

    get listings_path

    assert_response :success
    assert_includes response.body, "Save your first search to start a feed tailored to you."
    assert_includes response.body, "0 listings"
    refute_includes response.body, "Apto Pocitos"
    refute_includes response.body, "Mock Source"
  end

  test "signed in user only sees their own saved searches in the sidebar" do
    owner = create_user!(email: "owner@example.com")
    other_user = create_user!(email: "other@example.com")
    sign_in owner

    owner.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
    other_user.search_preferences.create!(name: "Centro", location_query: "Centro")

    get listings_path

    assert_response :success
    assert_includes response.body, "Pocitos"
    refute_includes response.body, "Centro"
  end

  test "signed in user cannot activate another user's saved search" do
    owner = create_user!(email: "scoped@example.com")
    other_user = create_user!(email: "foreign@example.com")
    sign_in owner

    owner.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
    foreign_search = other_user.search_preferences.create!(name: "Centro", location_query: "Centro")

    get listings_path(search_id: foreign_search.id)

    assert_response :success
    assert_includes response.body, "All saved-search matches"
    refute_includes response.body, "Browsing <strong>#{foreign_search.name}</strong>"
  end

  test "clicking the active search points back to the aggregate feed" do
    user = create_user!(email: "clear-active@example.com")
    search = user.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
    sign_in user

    get listings_path(search_id: search.id)

    assert_select "a.search-link--active[href='#{listings_path}']", text: /Pocitos/
  end

  test "aggregate feed deduplicates listings and names every matching search" do
    user = create_user!(email: "aggregate-badges@example.com")
    source = ListingSource.create!(name: "Mock Source", adapter_key: "aggregate_badges_source")
    user.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
    user.search_preferences.create!(name: "Affordable", location_query: "Pocitos", max_price_cents: 4_000_000)
    Listing.create!(listing_source: source, title: "Shared apartment", canonical_url: "https://example.test/shared-card", location_text: "Pocitos", price_cents: 3_000_000, currency: "UYU", in_scope: true)
    sign_in user

    get listings_path

    assert_select ".listing-card", count: 1
    assert_select ".listing-card__matches", text: /Pocitos/
    assert_select ".listing-card__matches", text: /Affordable/
  end

  test "feed filters by source currency neighborhood and known expenses" do
    user = create_user!(email: "feed-controls@example.com")
    first_source = ListingSource.create!(name: "First Source", adapter_key: "feed_controls_first")
    second_source = ListingSource.create!(name: "Second Source", adapter_key: "feed_controls_second")
    user.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
    kept = Listing.create!(listing_source: first_source, title: "Kept apartment", canonical_url: "https://example.test/kept-controls", location_text: "Pocitos", source_neighborhood: "Pocitos", price_cents: 3_000_000, currency: "UYU", expenses_cents: 400_000, expenses_currency: "UYU", in_scope: true)
    Listing.create!(listing_source: second_source, title: "Other source", canonical_url: "https://example.test/other-source-controls", location_text: "Pocitos", source_neighborhood: "Pocitos", price_cents: 2_000_000, currency: "UYU", expenses_cents: 300_000, expenses_currency: "UYU", in_scope: true)
    Listing.create!(listing_source: first_source, title: "USD apartment", canonical_url: "https://example.test/usd-controls", location_text: "Pocitos", source_neighborhood: "Pocitos", price_cents: 90_000, currency: "USD", expenses_cents: 300_000, expenses_currency: "UYU", in_scope: true)
    sign_in user

    get listings_path, params: { source_id: first_source.id, neighborhood: "Pocitos", currency: "UYU", expenses_known: "1" }

    assert_select ".listing-card h2", text: kept.title
    assert_select ".listing-card", count: 1
  end

  test "feed sorts by ascending price within currency" do
    user = create_user!(email: "feed-sorting@example.com")
    source = ListingSource.create!(name: "Sort Source", adapter_key: "feed_sort_source")
    user.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
    Listing.create!(listing_source: source, title: "Higher", canonical_url: "https://example.test/higher-sort", location_text: "Pocitos", price_cents: 4_000_000, currency: "UYU", in_scope: true)
    Listing.create!(listing_source: source, title: "Lower", canonical_url: "https://example.test/lower-sort", location_text: "Pocitos", price_cents: 2_000_000, currency: "UYU", in_scope: true)
    sign_in user

    get listings_path, params: { sort: "price_low", currency: "UYU" }

    assert_equal ["Lower", "Higher"], css_select(".listing-card h2").map { |node| node.text.strip }
  end

  test "feed sorts known same-currency monthly totals before unknown totals" do
    user = create_user!(email: "monthly-sort@example.com")
    source = ListingSource.create!(name: "Monthly Source", adapter_key: "monthly_sort_source")
    user.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
    Listing.create!(listing_source: source, title: "Higher total", canonical_url: "https://example.test/higher-total", location_text: "Pocitos", price_cents: 3_000_000, currency: "UYU", expenses_cents: 500_000, expenses_currency: "UYU", in_scope: true)
    Listing.create!(listing_source: source, title: "Lower total", canonical_url: "https://example.test/lower-total", location_text: "Pocitos", price_cents: 3_200_000, currency: "UYU", expenses_cents: 100_000, expenses_currency: "UYU", in_scope: true)
    Listing.create!(listing_source: source, title: "Unknown total", canonical_url: "https://example.test/unknown-total", location_text: "Pocitos", price_cents: 2_000_000, currency: "UYU", expenses_cents: nil, in_scope: true)
    sign_in user

    get listings_path, params: { sort: "total_monthly", currency: "UYU" }

    assert_equal ["Lower total", "Higher total", "Unknown total"], css_select(".listing-card h2").map { |node| node.text.strip }
  end

  test "signed in user sees listings from any attached zone and not unresolved records" do
    user = create_user!(email: "zones@example.com")
    sign_in user
    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
    pocitos = create_zone("Pocitos", "pocitos", ["pocitos"], [[-56.17, -34.92], [-56.14, -34.92], [-56.14, -34.89], [-56.17, -34.89], [-56.17, -34.92]])
    malvin = create_zone("Malvin", "malvin", ["malvin", "malvín"], [[-56.11, -34.91], [-56.06, -34.91], [-56.06, -34.87], [-56.11, -34.87], [-56.11, -34.91]])
    Listing.create!(listing_source: source, title: "Pocitos Match", canonical_url: "https://example.test/10", coordinates: Zone::FACTORY.point(-56.16, -34.90), latitude: -34.90, longitude: -56.16, location_resolution_status: "spatial", in_scope: true)
    Listing.create!(listing_source: source, title: "Malvin Match", canonical_url: "https://example.test/11", coordinates: Zone::FACTORY.point(-56.082, -34.885), latitude: -34.885, longitude: -56.082, location_resolution_status: "spatial", in_scope: true)
    Listing.create!(listing_source: source, title: "Unresolved", canonical_url: "https://example.test/12", source_neighborhood: "Malvín", location_resolution_status: "unresolved", in_scope: true)
    search = user.search_preferences.create!(name: "Coast", location_query: "legacy", zones: [pocitos, malvin])

    get listings_path(search_id: search.id)

    assert_response :success
    assert_includes response.body, "Pocitos Match"
    assert_includes response.body, "Malvin Match"
    refute_includes response.body, "Unresolved"
  end

  test "signed in user sidebar renders zone backed search names" do
    user = create_user!(email: "sidebar-zones@example.com")
    sign_in user
    zone = create_zone("Pocitos", "pocitos", ["pocitos"], [[-56.17, -34.92], [-56.14, -34.92], [-56.14, -34.89], [-56.17, -34.89], [-56.17, -34.92]])
    user.search_preferences.create!(name: "Pocitos", location_query: "legacy", zones: [zone])

    get listings_path

    assert_response :success
    assert_includes response.body, "Pocitos"
  end

  private

  def create_user!(email:)
    User.create!(
      first_name: "Test",
      last_name: "User",
      email: email,
      password: "password123",
      password_confirmation: "password123"
    )
  end

  def create_zone(name, slug, aliases, coordinates)
    Zone.create!(
      name: name,
      slug: slug,
      aliases: aliases,
      geom: Zone.polygon_from_coordinates(coordinates)
    )
  end
end
