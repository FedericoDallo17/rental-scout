require "test_helper"

class Scraping::ListingGeometryBuilderTest < ActiveSupport::TestCase
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
    assert_nil result[:coordinates]
  end
end
