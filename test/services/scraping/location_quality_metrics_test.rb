require "test_helper"

class Scraping::LocationQualityMetricsTest < ActiveSupport::TestCase
  test "counts resolution states and provider disagreements with authoritative polygons" do
    source = ListingSource.create!(name: "Metrics", adapter_key: "metrics")
    Zone.create!(
      name: "Buceo",
      slug: "buceo",
      aliases: ["buceo"],
      source_key: Zones::ImportMontevideoNeighborhoods::SOURCE_KEY,
      source_feature_id: "metrics-buceo",
      source_url: Zones::ImportMontevideoNeighborhoods::SOURCE_URL,
      geom: Zone.polygon_from_coordinates([
        [-56.15, -34.92], [-56.11, -34.92], [-56.11, -34.88],
        [-56.15, -34.88], [-56.15, -34.92]
      ])
    )
    Listing.create!(listing_source: source, title: "Spatial", canonical_url: "https://example.test/spatial-metric", coordinates: Zone::FACTORY.point(-56.13, -34.90), location_resolution_status: "spatial", raw_payload: { source_neighborhood: "Centro" })
    Listing.create!(listing_source: source, title: "Fallback", canonical_url: "https://example.test/fallback-metric", location_resolution_status: "fallback")
    Listing.create!(listing_source: source, title: "Unresolved", canonical_url: "https://example.test/unresolved-metric", location_resolution_status: "unresolved")

    result = Scraping::LocationQualityMetrics.new.call

    assert_equal 1, result.spatial_count
    assert_equal 1, result.fallback_count
    assert_equal 1, result.unresolved_count
    assert_equal 1, result.provider_mismatch_count
    source_result = result.by_source.find { |row| row.source_id == source.id }
    assert_equal 3, source_result.total_count
    assert_equal 1, source_result.spatial_count
    assert_equal 1, source_result.fallback_count
    assert_equal 1, source_result.unresolved_count
    assert_equal 33, source_result.coverage_percentage
  end
end
