require "test_helper"

class ListingTest < ActiveSupport::TestCase
  test "spatially_resolvable scope returns listings with coordinates" do
    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
    Listing.create!(listing_source: source, title: "Spatial", canonical_url: "https://example.test/spatial", location_resolution_status: "spatial", latitude: -34.90, longitude: -56.16, coordinates: Zone::FACTORY.point(-56.16, -34.90))
    Listing.create!(listing_source: source, title: "Status Only", canonical_url: "https://example.test/status-only", location_resolution_status: "spatial")
    Listing.create!(listing_source: source, title: "Coordinates Only", canonical_url: "https://example.test/coordinates-only", location_resolution_status: "fallback", coordinates: Zone::FACTORY.point(-56.17, -34.91))

    assert_equal ["Coordinates Only", "Spatial"], Listing.spatially_resolvable.order(:title).pluck(:title)
  end

  test "for_search_feed scopes listings by location query for searches without zones" do
    user = create_user!("listing-owner@example.com")
    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
    matching = Listing.create!(listing_source: source, title: "Apto Pocitos", canonical_url: "https://example.test/1", location_text: "Pocitos", in_scope: true)
    Listing.create!(listing_source: source, title: "Centro Loft", canonical_url: "https://example.test/2", location_text: "Centro", in_scope: true)
    search = user.search_preferences.create!(name: "Pocitos search", location_query: "Pocitos")

    assert_equal [matching], Listing.for_search_feed(search).to_a
  end

  test "for_search_feed applies scalar filters" do
    user = create_user!("listing-owner-2@example.com")
    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
    matching = Listing.create!(
      listing_source: source,
      title: "Pocitos Match",
      canonical_url: "https://example.test/5",
      location_text: "Pocitos",
      price_cents: 2100000,
      bedrooms: 2,
      in_scope: true
    )
    Listing.create!(
      listing_source: source,
      title: "Centro Match Price",
      canonical_url: "https://example.test/6",
      location_text: "Centro, Montevideo",
      price_cents: 2100000,
      bedrooms: 2,
      in_scope: true
    )
    Listing.create!(
      listing_source: source,
      title: "Pocitos Too Expensive",
      canonical_url: "https://example.test/7",
      location_text: "Pocitos",
      price_cents: 2600000,
      bedrooms: 2,
      in_scope: true
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

  test "for_search_feed matches any attached zone spatially" do
    user = create_user!("listing-owner-3@example.com")
    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
    pocitos = create_zone("Pocitos", "pocitos", ["pocitos"], [[-56.17, -34.92], [-56.14, -34.92], [-56.14, -34.89], [-56.17, -34.89], [-56.17, -34.92]])
    malvin = create_zone("Malvin", "malvin", ["malvin", "malvín"], [[-56.11, -34.91], [-56.06, -34.91], [-56.06, -34.87], [-56.11, -34.87], [-56.11, -34.91]])
    matching = Listing.create!(
      listing_source: source,
      title: "Apto Malvin",
      canonical_url: "https://example.test/8",
      latitude: -34.885,
      longitude: -56.082,
      coordinates: Zone::FACTORY.point(-56.082, -34.885),
      location_resolution_status: "spatial",
      in_scope: true
    )
    Listing.create!(
      listing_source: source,
      title: "Centro Loft",
      canonical_url: "https://example.test/9",
      latitude: -34.905,
      longitude: -56.19,
      coordinates: Zone::FACTORY.point(-56.19, -34.905),
      location_resolution_status: "spatial",
      in_scope: true
    )
    search = user.search_preferences.create!(name: "Coast", location_query: "legacy", zones: [pocitos, malvin])

    assert_equal [matching], Listing.for_search_feed(search).to_a
  end

  test "for_search_feed falls back to aliases and excludes unresolved records" do
    user = create_user!("listing-owner-4@example.com")
    source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
    malvin = create_zone("Malvin", "malvin", ["malvin", "malvín"], [[-56.11, -34.91], [-56.06, -34.91], [-56.06, -34.87], [-56.11, -34.87], [-56.11, -34.91]])
    matching = Listing.create!(
      listing_source: source,
      title: "Fallback Malvin",
      canonical_url: "https://example.test/fallback-malvin",
      source_neighborhood: "Malvín",
      location_resolution_status: "fallback",
      in_scope: true
    )
    Listing.create!(
      listing_source: source,
      title: "Unresolved Malvin",
      canonical_url: "https://example.test/unresolved-malvin",
      source_neighborhood: "Malvín",
      location_resolution_status: "unresolved",
      in_scope: true
    )
    Listing.create!(
      listing_source: source,
      title: "Rejected Malvin",
      canonical_url: "https://example.test/rejected-malvin",
      source_neighborhood: "Malvín",
      location_resolution_status: "fallback",
      in_scope: false
    )
    search = user.search_preferences.create!(name: "Malvin", location_query: "legacy", zones: [malvin])

    assert_equal [matching], Listing.for_search_feed(search).to_a
  end

  test "requires source canonical url" do
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

  test "validates external id uniqueness within source" do
    source = ListingSource.create!(name: "mock_source", adapter_key: "mock")
    Listing.create!(listing_source: source, title: "Apto 1", canonical_url: "https://example.test/1", external_id: "abc")

    duplicate = Listing.new(listing_source: source, title: "Apto 2", canonical_url: "https://example.test/2", external_id: "abc")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:external_id], "has already been taken"
  end

  test "enforces external id uniqueness database layer within source" do
    source = ListingSource.create!(name: "mock_source", adapter_key: "mock")
    Listing.create!(listing_source: source, title: "Apto 1", canonical_url: "https://example.test/1", external_id: "abc")

    duplicate = Listing.new(listing_source: source, title: "Apto 2", canonical_url: "https://example.test/2", external_id: "abc")

    assert_raises(ActiveRecord::RecordNotUnique) do
      duplicate.save!(validate: false)
    end
  end

  private

  def create_user!(email)
    User.create!(
      first_name: "Listing",
      last_name: "Owner",
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
