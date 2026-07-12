require "test_helper"

class Scraping::BackfillInfoCasasCoordinatesTest < ActiveSupport::TestCase
  test "backfills coordinates from the listing detail page" do
    source = ListingSource.create!(name: "InfoCasas API", adapter_key: "info_casas_api")
    other_source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
    coordless = Listing.create!(
      listing_source: source,
      title: "Missing Coordinates",
      canonical_url: "https://www.infocasas.com.uy/alquiler/apartamento/cordon/1",
      external_id: "1",
      source_neighborhood: "Cordón",
      location_resolution_status: "fallback"
    )
    Listing.create!(
      listing_source: source,
      title: "Already Spatial",
      canonical_url: "https://www.infocasas.com.uy/alquiler/apartamento/cordon/2",
      external_id: "2",
      location_resolution_status: "spatial",
      latitude: -34.9,
      longitude: -56.18,
      coordinates: Zone::FACTORY.point(-56.18, -34.9)
    )
    Listing.create!(
      listing_source: other_source,
      title: "Other Source",
      canonical_url: "https://example.test/listings/1",
      external_id: "3",
      source_neighborhood: "Centro",
      location_resolution_status: "fallback"
    )

    adapter = fake_adapter(
      "https://www.infocasas.com.uy/alquiler/apartamento/cordon/1" => {
        latitude: -34.9057216,
        longitude: -56.1822016
      }
    )

    result = Scraping::BackfillInfoCasasCoordinates.new.call(adapter: adapter)

    assert_equal 1, result.listings_seen_count
    assert_equal 1, result.listings_updated_count
    coordless.reload
    assert_in_delta(-34.9057216, coordless.latitude.to_f, 0.000001)
    assert_not_nil coordless.coordinates
    assert_equal "spatial", coordless.location_resolution_status
  end

  test "leaves listing untouched when detail page yields no coordinates" do
    source = ListingSource.create!(name: "InfoCasas API", adapter_key: "info_casas_api")
    coordless = Listing.create!(
      listing_source: source,
      title: "Missing Coordinates",
      canonical_url: "https://www.infocasas.com.uy/alquiler/apartamento/cordon/1",
      external_id: "1",
      source_neighborhood: "Cordón",
      location_resolution_status: "fallback"
    )

    result = Scraping::BackfillInfoCasasCoordinates.new.call(adapter: fake_adapter({}))

    assert_equal 1, result.listings_seen_count
    assert_equal 0, result.listings_updated_count
    assert_nil coordless.reload.latitude
    assert_nil coordless.coordinates
    assert_equal "fallback", coordless.location_resolution_status
  end

  test "respects explicit external ids" do
    source = ListingSource.create!(name: "InfoCasas API", adapter_key: "info_casas_api")
    first = Listing.create!(
      listing_source: source,
      title: "First",
      canonical_url: "https://www.infocasas.com.uy/alquiler/apartamento/cordon/1",
      external_id: "1",
      source_neighborhood: "Cordón",
      location_resolution_status: "fallback"
    )
    second = Listing.create!(
      listing_source: source,
      title: "Second",
      canonical_url: "https://www.infocasas.com.uy/alquiler/apartamento/cordon/2",
      external_id: "2",
      source_neighborhood: "Cordón",
      location_resolution_status: "fallback"
    )
    adapter = fake_adapter(
      first.canonical_url => { latitude: -34.9057216, longitude: -56.1822016 },
      second.canonical_url => { latitude: -34.91, longitude: -56.19 }
    )

    result = Scraping::BackfillInfoCasasCoordinates.new.call(external_ids: ["2"], adapter: adapter)

    assert_equal 1, result.listings_seen_count
    assert_equal 1, result.listings_updated_count
    assert_nil first.reload.latitude
    assert_in_delta(-34.91, second.reload.latitude.to_f, 0.000001)
  end

  test "respects limit" do
    source = ListingSource.create!(name: "InfoCasas API", adapter_key: "info_casas_api")
    first = Listing.create!(
      listing_source: source,
      title: "First",
      canonical_url: "https://www.infocasas.com.uy/alquiler/apartamento/cordon/1",
      external_id: "1",
      source_neighborhood: "Cordón",
      location_resolution_status: "fallback"
    )
    second = Listing.create!(
      listing_source: source,
      title: "Second",
      canonical_url: "https://www.infocasas.com.uy/alquiler/apartamento/cordon/2",
      external_id: "2",
      source_neighborhood: "Cordón",
      location_resolution_status: "fallback"
    )
    adapter = fake_adapter(
      first.canonical_url => { latitude: -34.9057216, longitude: -56.1822016 },
      second.canonical_url => { latitude: -34.91, longitude: -56.19 }
    )

    result = Scraping::BackfillInfoCasasCoordinates.new.call(limit: 1, adapter: adapter)

    assert_equal 1, result.listings_seen_count
    assert_equal 1, result.listings_updated_count
    assert_equal 1, [first.reload, second.reload].count { |listing| listing.coordinates.present? }
  end

  private

  def fake_adapter(coordinates_by_url)
    Object.new.tap do |adapter|
      adapter.define_singleton_method(:detail_coordinates_for_url) do |canonical_url|
        coordinates_by_url.fetch(canonical_url, {})
      end
    end
  end
end
