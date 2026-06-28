require "test_helper"

class ListingsControllerTest < ActionDispatch::IntegrationTest
  test "uses the selected saved search to filter the feed" do
    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
    Listing.create!(listing_source: source, title: "Apto Pocitos", canonical_url: "https://example.test/1", location_text: "Pocitos")
    Listing.create!(listing_source: source, title: "Centro Loft", canonical_url: "https://example.test/2", location_text: "Centro")
    pocitos = SearchPreference.create!(name: "Pocitos", location_query: "Pocitos")
    SearchPreference.create!(name: "Centro", location_query: "Centro")

    get listings_path(search_id: pocitos.id)

    assert_response :success
    assert_includes response.body, "Apto Pocitos"
    refute_includes response.body, "Centro Loft"
  end

  test "defaults to the first created saved search when no search is selected" do
    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
    Listing.create!(listing_source: source, title: "Apto Pocitos", canonical_url: "https://example.test/1", location_text: "Pocitos")
    Listing.create!(listing_source: source, title: "Centro Loft", canonical_url: "https://example.test/2", location_text: "Centro")
    SearchPreference.create!(name: "Pocitos", location_query: "Pocitos")
    SearchPreference.create!(name: "Centro", location_query: "Centro")

    get listings_path

    assert_response :success
    assert_includes response.body, "Browsing <strong>Pocitos</strong>"
    assert_includes response.body, "Apto Pocitos"
    refute_includes response.body, "Centro Loft"
  end

  test "selected saved search honors location price and bedroom fields" do
    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
    Listing.create!(
      listing_source: source,
      title: "Pocitos Family Apartment",
      canonical_url: "https://example.test/3",
      location_text: "Pocitos, Montevideo",
      price_cents: 2300000,
      bedrooms: 2
    )
    Listing.create!(
      listing_source: source,
      title: "Pocitos Studio",
      canonical_url: "https://example.test/4",
      location_text: "Pocitos",
      price_cents: 2100000,
      bedrooms: 0
    )
    Listing.create!(
      listing_source: source,
      title: "Pocitos Luxury Penthouse",
      canonical_url: "https://example.test/5",
      location_text: "Pocitos Nuevo",
      price_cents: 3200000,
      bedrooms: 3
    )
    Listing.create!(
      listing_source: source,
      title: "Centro Family Apartment",
      canonical_url: "https://example.test/6",
      location_text: "Centro, Montevideo",
      price_cents: 2200000,
      bedrooms: 2
    )
    pocitos = SearchPreference.create!(
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

  test "shows an empty state when there are no saved searches" do
    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
    Listing.create!(listing_source: source, title: "Apto Pocitos", canonical_url: "https://example.test/1")

    get listings_path

    assert_response :success
    assert_includes response.body, "Save your first search to start a feed tailored to you."
    assert_includes response.body, "0 listings"
    refute_includes response.body, "Apto Pocitos"
    refute_includes response.body, "Mock Source"
  end
end
