require "test_helper"

class Scraping::ListingGeometryBuilderTest < ActiveSupport::TestCase
  test "coordinates use an authoritative imported neighborhood for labels" do
    Zone.create!(
      name: "Buceo",
      slug: "buceo",
      aliases: ["buceo"],
      source_key: Zones::ImportMontevideoNeighborhoods::SOURCE_KEY,
      source_feature_id: "1",
      source_url: Zones::ImportMontevideoNeighborhoods::SOURCE_URL,
      geom: Zone.polygon_from_coordinates([
        [-56.15, -34.92], [-56.11, -34.92], [-56.11, -34.88],
        [-56.15, -34.88], [-56.15, -34.92]
      ])
    )

    result = Scraping::ListingGeometryBuilder.new.call(attributes: {
      latitude: -34.90,
      longitude: -56.13,
      source_city: "Montevideo",
      source_neighborhood: "Centro",
      location_text: "Centro, Montevideo"
    })

    assert_equal "Buceo", result[:source_neighborhood]
    assert_equal "Centro, Montevideo", result[:location_text]
    assert_equal "spatial", result[:location_resolution_status]
  end

  test "builds coordinates and marks listing spatially resolvable" do
    result = Scraping::ListingGeometryBuilder.new.call(attributes: {
      latitude: -34.9012,
      longitude: -56.1645,
      source_neighborhood: "Pocitos"
    })

    assert_equal "spatial", result[:location_resolution_status]
    assert_equal(-34.9012, result[:latitude])
    assert_equal(-56.1645, result[:longitude])
    assert result[:coordinates].present?
  end

  test "marks listing unresolved when no coordinates or fallback neighborhood exist" do
    result = Scraping::ListingGeometryBuilder.new.call(attributes: {
      location_text: "Montevideo"
    })

    assert_equal "unresolved", result[:location_resolution_status]
    assert_nil result[:latitude]
    assert_nil result[:longitude]
    assert_nil result[:coordinates]
  end

  test "marks listing fallback from source neighborhood and clears stale geometry" do
    result = Scraping::ListingGeometryBuilder.new.call(attributes: {
      latitude: "",
      longitude: "",
      source_neighborhood: "Pocitos"
    })

    assert_equal "fallback", result[:location_resolution_status]
    assert_equal "Pocitos", result[:source_neighborhood]
    assert_nil result[:latitude]
    assert_nil result[:longitude]
    assert_nil result[:coordinates]
  end
end
