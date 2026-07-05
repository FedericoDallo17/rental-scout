require "test_helper"

class ListingTest < ActiveSupport::TestCase
  test "spatially_resolvable scope returns listings with coordinates" do
    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
    Listing.create!(listing_source: source, title: "Spatial", canonical_url: "https://example.test/spatial", location_resolution_status: "spatial", latitude: -34.90, longitude: -56.16, coordinates: Zone::FACTORY.point(-56.16, -34.90))
    Listing.create!(listing_source: source, title: "Fallback", canonical_url: "https://example.test/fallback", location_resolution_status: "fallback", source_neighborhood: "Pocitos")

    assert_equal ["Spatial"], Listing.spatially_resolvable.pluck(:title)
  end

  test "for_search_feed scopes listings by location query" do
    user = User.create!(
      first_name: "Listing",
      last_name: "Owner",
      email: "listing-owner@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
    matching = Listing.create!(listing_source: source, title: "Apto Pocitos", canonical_url: "https://example.test/1", location_text: "Pocitos")
    Listing.create!(listing_source: source, title: "Centro Loft", canonical_url: "https://example.test/2", location_text: "Centro")
    search = user.search_preferences.create!(name: "Pocitos search", location_query: "Pocitos")

    assert_equal [matching], Listing.for_search_feed(search).to_a
  end

  test "for_search_feed applies partial location, price, and bedroom filters" do
    user = User.create!(
      first_name: "Listing",
      last_name: "Owner",
      email: "listing-owner-2@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
    matching = Listing.create!(
      listing_source: source,
      title: "Pocitos Two Bedroom",
      canonical_url: "https://example.test/3",
      location_text: "Pocitos, Montevideo",
      price_cents: 2200000,
      bedrooms: 2
    )
    Listing.create!(
      listing_source: source,
      title: "Pocitos Too Cheap",
      canonical_url: "https://example.test/4",
      location_text: "Pocitos Nuevo",
      price_cents: 1400000,
      bedrooms: 2
    )
    Listing.create!(
      listing_source: source,
      title: "Pocitos Studio",
      canonical_url: "https://example.test/5",
      location_text: "POCITOS",
      price_cents: 2100000,
      bedrooms: 0
    )
    Listing.create!(
      listing_source: source,
      title: "Centro Match Price",
      canonical_url: "https://example.test/6",
      location_text: "Centro, Montevideo",
      price_cents: 2100000,
      bedrooms: 2
    )
    Listing.create!(
      listing_source: source,
      title: "Pocitos Too Expensive",
      canonical_url: "https://example.test/7",
      location_text: "Pocitos",
      price_cents: 2600000,
      bedrooms: 2
    )
    search = user.search_preferences.create!(
      name: "Pocitos two bedrooms",
      location_query: "pocitos",
      min_price_cents: 1800000,
      max_price_cents: 2400000,
      min_bedrooms: 2
    )

    assert_equal [matching], Listing.for_search_feed(search).to_a
  end

  test "requires source and canonical url" do
    listing = Listing.new(title: "Apto")

    assert_not listing.valid?
    assert_includes listing.errors[:listing_source], "must exist"
    assert_includes listing.errors[:canonical_url], "can't be blank"
  end

  test "prevents destroy when notification events reference it" do
    source = ListingSource.create!(name: "mock_source", adapter_key: "mock")
    listing = Listing.create!(listing_source: source, title: "Apto", canonical_url: "https://example.test/1")
    NotificationEvent.create!(
      listing: listing,
      listing_source: source,
      event_kind: "new_listing",
      status: "sent",
      idempotency_key: "evt-1"
    )

    assert_raises(ActiveRecord::DeleteRestrictionError) do
      listing.destroy
    end
  end

  test "validates external id uniqueness within a source" do
    source = ListingSource.create!(name: "mock_source", adapter_key: "mock")
    Listing.create!(listing_source: source, title: "Apto 1", canonical_url: "https://example.test/1", external_id: "abc")

    duplicate = Listing.new(listing_source: source, title: "Apto 2", canonical_url: "https://example.test/2", external_id: "abc")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:external_id], "has already been taken"
  end

  test "enforces external id uniqueness at the database layer within a source" do
    source = ListingSource.create!(name: "mock_source", adapter_key: "mock")
    Listing.create!(listing_source: source, title: "Apto 1", canonical_url: "https://example.test/1", external_id: "abc")

    duplicate = Listing.new(listing_source: source, title: "Apto 2", canonical_url: "https://example.test/2", external_id: "abc")

    assert_raises(ActiveRecord::RecordNotUnique) do
      duplicate.save!(validate: false)
    end
  end
end
