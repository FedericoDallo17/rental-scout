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
    assert_select "[data-onboarding-welcome] h1", text: "Your next place could be about to ring."
    assert_select "a[href='#{new_search_preference_path}']", text: "Set up my first search"
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

  test "neighborhood filter uses the same canonical zones and aliases as saved searches" do
    user = create_user!(email: "canonical-neighborhood-filter@example.com")
    source = ListingSource.create!(name: "Canonical Source", adapter_key: "canonical_filter_source")
    pocitos = create_zone("Pocitos", "pocitos", ["pocitos", "pocitos nuevo"], [[-56.17, -34.92], [-56.14, -34.92], [-56.14, -34.89], [-56.17, -34.89], [-56.17, -34.92]])
    centro = create_zone("Centro", "centro", ["centro"], [[-56.21, -34.92], [-56.17, -34.92], [-56.17, -34.89], [-56.21, -34.89], [-56.21, -34.92]])
    user.search_preferences.create!(name: "Both zones", location_query: "legacy", zones: [pocitos, centro])
    Listing.create!(listing_source: source, title: "Pocitos canonical", canonical_url: "https://example.test/pocitos-canonical", source_neighborhood: "Pocitos", location_resolution_status: "fallback", in_scope: true)
    Listing.create!(listing_source: source, title: "Pocitos Nuevo alias", canonical_url: "https://example.test/pocitos-nuevo-alias", source_neighborhood: "Pocitos", location_resolution_status: "spatial", coordinates: Zone::FACTORY.point(-56.16, -34.90), raw_payload: { source_neighborhood: "Pocitos Nuevo", source_city: "Montevideo" }, in_scope: true)
    Listing.create!(listing_source: source, title: "Centro listing", canonical_url: "https://example.test/centro-canonical", source_neighborhood: "Centro", location_resolution_status: "fallback", in_scope: true)
    sign_in user

    get listings_path, params: { neighborhood: "pocitos" }

    assert_response :success
    assert_select "select[name='neighborhood'] option[value='pocitos']", text: "Pocitos"
    assert_select "select[name='neighborhood'] option", text: "Pocitos Nuevo", count: 0
    assert_includes response.body, "Pocitos canonical"
    assert_includes response.body, "Pocitos Nuevo alias"
    assert_select ".listing-card__location", text: "Pocitos Nuevo, Montevideo"
    assert_not_includes response.body, "Centro listing"
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

  test "feed filters by rent price range" do
    user = create_user!(email: "rent-range@example.com")
    source = ListingSource.create!(name: "Rent Range Source", adapter_key: "rent_range_source")
    user.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
    Listing.create!(listing_source: source, title: "Below range", canonical_url: "https://example.test/below-rent-range", location_text: "Pocitos", price_cents: 2_000_000, currency: "UYU", in_scope: true)
    Listing.create!(listing_source: source, title: "Inside range", canonical_url: "https://example.test/inside-rent-range", location_text: "Pocitos", price_cents: 3_000_000, currency: "UYU", in_scope: true)
    Listing.create!(listing_source: source, title: "Above range", canonical_url: "https://example.test/above-rent-range", location_text: "Pocitos", price_cents: 4_000_000, currency: "UYU", in_scope: true)
    sign_in user

    get listings_path, params: { currency: "UYU", cost_basis: "rent", min_price: "25000", max_price: "35000" }

    assert_select ".listing-card h2", text: "Inside range"
    assert_select ".listing-card", count: 1
    assert_select "input[name='min_price'][value='25000']"
    assert_select "input[name='max_price'][value='35000']"
  end

  test "feed filters by minimum bedrooms" do
    user = create_user!(email: "bedroom-filter@example.com")
    source = ListingSource.create!(name: "Bedroom Filter Source", adapter_key: "bedroom_filter_source")
    user.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
    Listing.create!(listing_source: source, title: "One bedroom", canonical_url: "https://example.test/one-bedroom-filter", location_text: "Pocitos", bedrooms: 1, in_scope: true)
    Listing.create!(listing_source: source, title: "Two bedrooms", canonical_url: "https://example.test/two-bedroom-filter", location_text: "Pocitos", bedrooms: 2, in_scope: true)
    Listing.create!(listing_source: source, title: "Three bedrooms", canonical_url: "https://example.test/three-bedroom-filter", location_text: "Pocitos", bedrooms: 3, in_scope: true)
    Listing.create!(listing_source: source, title: "Bedrooms unknown", canonical_url: "https://example.test/unknown-bedroom-filter", location_text: "Pocitos", bedrooms: nil, in_scope: true)
    sign_in user

    get listings_path, params: { min_bedrooms: "2" }

    assert_response :success
    assert_includes response.body, "Two bedrooms"
    assert_includes response.body, "Three bedrooms"
    assert_not_includes response.body, "One bedroom"
    assert_not_includes response.body, "Bedrooms unknown"
    assert_select "select[name='min_bedrooms'] option[value='2'][selected='selected']"
  end

  test "feed filters by rent plus same-currency expenses" do
    user = create_user!(email: "total-range@example.com")
    source = ListingSource.create!(name: "Total Range Source", adapter_key: "total_range_source")
    user.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
    Listing.create!(listing_source: source, title: "Matching total", canonical_url: "https://example.test/matching-total-range", location_text: "Pocitos", price_cents: 3_000_000, currency: "UYU", expenses_cents: 500_000, expenses_currency: "UYU", in_scope: true)
    Listing.create!(listing_source: source, title: "High total", canonical_url: "https://example.test/high-total-range", location_text: "Pocitos", price_cents: 3_400_000, currency: "UYU", expenses_cents: 700_000, expenses_currency: "UYU", in_scope: true)
    Listing.create!(listing_source: source, title: "Unknown expenses", canonical_url: "https://example.test/unknown-total-range", location_text: "Pocitos", price_cents: 3_000_000, currency: "UYU", expenses_cents: nil, in_scope: true)
    Listing.create!(listing_source: source, title: "Mismatched expenses", canonical_url: "https://example.test/mismatched-total-range", location_text: "Pocitos", price_cents: 3_000_000, currency: "UYU", expenses_cents: 100, expenses_currency: "USD", in_scope: true)
    sign_in user

    get listings_path, params: { currency: "UYU", cost_basis: "total", max_price: "38000" }

    assert_select ".listing-card h2", text: "Matching total"
    assert_select ".listing-card", count: 1
    assert_select "input[name='include_expenses'][type='checkbox'][checked='checked']"
    assert_select "input[name='currency'][value='UYU'][checked='checked']"
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

  test "feed filters by surface area and can include or exclude unknown values" do
    user = create_user!(email: "area-filter@example.com")
    source = ListingSource.create!(name: "Area Source", adapter_key: "area_filter_source")
    user.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
    Listing.create!(listing_source: source, title: "Inside area", canonical_url: "https://example.test/inside-area", location_text: "Pocitos", square_meters: 55, in_scope: true)
    Listing.create!(listing_source: source, title: "Outside area", canonical_url: "https://example.test/outside-area", location_text: "Pocitos", square_meters: 85, in_scope: true)
    Listing.create!(listing_source: source, title: "Unknown area", canonical_url: "https://example.test/unknown-area", location_text: "Pocitos", square_meters: nil, in_scope: true)
    sign_in user

    get listings_path, params: { min_square_meters: "45", max_square_meters: "65", include_unknown_area: "1" }

    assert_includes response.body, "Inside area"
    assert_includes response.body, "Unknown area"
    assert_not_includes response.body, "Outside area"
    assert_select "input[name='min_square_meters'][value='45']"
    assert_select "input[name='max_square_meters'][value='65']"

    get listings_path, params: { min_square_meters: "45", max_square_meters: "65", include_unknown_area: "0" }

    assert_includes response.body, "Inside area"
    assert_not_includes response.body, "Unknown area"
  end

  test "feed filters maximum expenses by currency and keeps unknown values by default" do
    user = create_user!(email: "expenses-filter@example.com")
    source = ListingSource.create!(name: "Expenses Source", adapter_key: "expenses_filter_source")
    user.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
    Listing.create!(listing_source: source, title: "Affordable expenses", canonical_url: "https://example.test/affordable-expenses", location_text: "Pocitos", currency: "USD", expenses_cents: 500_000, expenses_currency: "UYU", in_scope: true)
    Listing.create!(listing_source: source, title: "High expenses", canonical_url: "https://example.test/high-expenses", location_text: "Pocitos", currency: "USD", expenses_cents: 900_000, expenses_currency: "UYU", in_scope: true)
    Listing.create!(listing_source: source, title: "Unknown expenses filter", canonical_url: "https://example.test/unknown-expenses-filter", location_text: "Pocitos", currency: "USD", expenses_cents: nil, in_scope: true)
    sign_in user

    get listings_path, params: { max_expenses: "6000", expenses_currency: "UYU" }

    assert_includes response.body, "Affordable expenses"
    assert_includes response.body, "Unknown expenses filter"
    assert_not_includes response.body, "High expenses"

    get listings_path, params: { max_expenses: "6000", expenses_currency: "UYU", include_unknown_expenses: "0" }

    assert_includes response.body, "Affordable expenses"
    assert_not_includes response.body, "Unknown expenses filter"
  end

  test "feed sorts price per square meter in SQL with missing values last" do
    user = create_user!(email: "price-per-area-sort@example.com")
    source = ListingSource.create!(name: "Area Sort Source", adapter_key: "area_sort_source")
    user.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
    Listing.create!(listing_source: source, title: "Higher per meter", canonical_url: "https://example.test/higher-per-meter", location_text: "Pocitos", price_cents: 10_000_000, currency: "UYU", square_meters: 50, in_scope: true)
    Listing.create!(listing_source: source, title: "Lower per meter", canonical_url: "https://example.test/lower-per-meter", location_text: "Pocitos", price_cents: 9_000_000, currency: "UYU", square_meters: 90, in_scope: true)
    Listing.create!(listing_source: source, title: "Unknown per meter", canonical_url: "https://example.test/unknown-per-meter", location_text: "Pocitos", price_cents: 8_000_000, currency: "UYU", square_meters: nil, in_scope: true)
    sign_in user

    get listings_path, params: { sort: "price_per_m2_low", currency: "UYU" }

    assert_equal ["Lower per meter", "Higher per meter", "Unknown per meter"], css_select(".listing-card h2").map { |node| node.text.strip }
    assert_select ".listing-card__facts", text: /UYU 1\.000/
  end

  test "feed exposes property type and parking controls only when data is available" do
    user = create_user!(email: "metadata-filter@example.com")
    source = ListingSource.create!(name: "Metadata Source", adapter_key: "metadata_filter_source")
    user.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
    Listing.create!(listing_source: source, title: "Apartment with parking", canonical_url: "https://example.test/apartment-parking", location_text: "Pocitos", property_type: "Apartamento", parking_spaces: 1, in_scope: true)
    Listing.create!(listing_source: source, title: "House without parking", canonical_url: "https://example.test/house-no-parking", location_text: "Pocitos", property_type: "Casa", parking_spaces: 0, in_scope: true)
    sign_in user

    get listings_path, params: { property_type: "Apartamento", parking_required: "1" }

    assert_select "select[name='property_type'] option[value='Apartamento'][selected='selected']"
    assert_select "input[name='parking_required'][checked='checked']"
    assert_includes response.body, "Apartment with parking"
    assert_not_includes response.body, "House without parking"
  end

  test "feed paginates SQL results and preserves the total count" do
    user = create_user!(email: "feed-pagination@example.com")
    source = ListingSource.create!(name: "Pagination Source", adapter_key: "pagination_source")
    user.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
    26.times do |index|
      Listing.create!(listing_source: source, title: "Paged #{index}", canonical_url: "https://example.test/paged-#{index}", location_text: "Pocitos", in_scope: true, created_at: index.minutes.ago)
    end
    sign_in user

    get listings_path

    assert_select ".feed-header__count", text: "26 listings"
    assert_select ".listing-card", count: 24
    assert_select ".feed-pagination", text: /Page 1 of 2/
    assert_select ".feed-pagination a[href='#{listings_path(page: 2)}']", text: "Next"

    get listings_path, params: { page: 2 }

    assert_select ".listing-card", count: 2
    assert_select ".feed-pagination", text: /Page 2 of 2/
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
