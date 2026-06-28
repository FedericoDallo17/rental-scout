require "test_helper"

class ListingsFlowTest < ActionDispatch::IntegrationTest
  test "root redirects into listings portal" do
    get root_url

    assert_response :success
    assert_includes response.body, "Scraped Apartments"
  end

  test "layout includes the application stylesheet asset" do
    get root_url

    assert_response :success
    assert_match %r{<link[^>]+href="[^"]*application[^"]*\.css[^"]*"}, response.body
  end

  test "application stylesheet asset is served" do
    get "/stylesheets/application.css"

    assert_response :success
    assert_match ":root", response.body
  end

  test "root defaults to the first saved search feed" do
    SearchPreference.create!(name: "Centro", location_query: "Centro")
    SearchPreference.create!(name: "Pocitos", location_query: "Pocitos")

    get root_url

    assert_response :success
    assert_includes response.body, "Centro"
    assert_select ".feed-header__context", text: /Browsing Centro/
    assert_select ".feed-header__refresh-cue", text: /Updated automatically/
    assert_select "nav.search-sidebar__nav a.search-link.search-link--active .search-link__name", text: "Centro"
  end

  test "root shows an empty saved-search state when none exist" do
    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
    create_listing!(
      listing_source: source,
      title: "Centro Loft",
      canonical_url: "https://example.test/listings/centro-loft",
      location_text: "Centro"
    )

    get root_url

    assert_response :success
    assert_select ".feed-header__context", count: 0
    assert_select ".feed-header__count", text: "0 listings"
    assert_select ".feed-empty-state", text: /Save your first search to start a feed tailored to you/
    assert_select "section.listings-grid article.listing-card", count: 0
    assert_no_match "Centro Loft", response.body
  end

  test "homepage shows saved searches sidebar and listings grid" do
    pocitos = SearchPreference.create!(name: "Pocitos", location_query: "Pocitos")
    SearchPreference.create!(name: "Centro", location_query: "Centro")
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

    get root_url(search_id: pocitos.id)

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

  test "listings index is available" do
    get listings_url

    assert_response :success
    assert_includes response.body, "Scraped Apartments"
  end

  private

  def create_listing!(**attributes)
    Listing.create!({
      currency: "USD",
      raw_payload: {},
      external_id: SecureRandom.uuid
    }.merge(attributes))
  end
end
