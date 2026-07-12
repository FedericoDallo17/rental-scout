require "test_helper"

class BackfillInfoCasasCoordinatesJobTest < ActiveJob::TestCase
  test "runs backfill service against real adapter" do
    source = ListingSource.create!(name: "InfoCasas API", adapter_key: "info_casas_api")
    Listing.create!(
      listing_source: source,
      title: "Missing Coordinates",
      canonical_url: "https://www.infocasas.com.uy/alquiler/apartamento/cordon/1",
      external_id: "1",
      source_neighborhood: "Cordón",
      location_resolution_status: "fallback"
    )

    adapter = Object.new
    adapter.define_singleton_method(:detail_coordinates_for_url) do |_url|
      { latitude: -34.9057216, longitude: -56.1822016 }
    end

    original_new = Sources::InfoCasasApiAdapter.method(:new)
    Sources::InfoCasasApiAdapter.define_singleton_method(:new) { |*, **| adapter }

    result = BackfillInfoCasasCoordinatesJob.perform_now

    assert_equal 1, result.listings_seen_count
    assert_equal 1, result.listings_updated_count
    assert_not_nil source.listings.find_by!(external_id: "1").coordinates
  ensure
    Sources::InfoCasasApiAdapter.define_singleton_method(:new, original_new)
  end
end
