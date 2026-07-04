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

  test "signed in user defaults to the first created saved search when no search is selected" do
    user = create_user!(email: "default-search@example.com")
    sign_in user

    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
    Listing.create!(listing_source: source, title: "Apto Pocitos", canonical_url: "https://example.test/1", location_text: "Pocitos")
    Listing.create!(listing_source: source, title: "Centro Loft", canonical_url: "https://example.test/2", location_text: "Centro")
    user.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
    user.search_preferences.create!(name: "Centro", location_query: "Centro")

    get listings_path

    assert_response :success
    assert_includes response.body, "Browsing <strong>Pocitos</strong>"
    assert_includes response.body, "Apto Pocitos"
    refute_includes response.body, "Centro Loft"
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

    fallback = owner.search_preferences.create!(name: "Pocitos", location_query: "Pocitos")
    foreign_search = other_user.search_preferences.create!(name: "Centro", location_query: "Centro")

    get listings_path(search_id: foreign_search.id)

    assert_response :success
    assert_includes response.body, "Browsing <strong>#{fallback.name}</strong>"
    refute_includes response.body, "Browsing <strong>#{foreign_search.name}</strong>"
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
end
