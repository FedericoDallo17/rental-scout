require "test_helper"

class Zones::ImportMontevideoNeighborhoodsTest < ActiveSupport::TestCase
  test "imports and updates an authoritative multipolygon neighborhood" do
    importer = Zones::ImportMontevideoNeighborhoods.new

    first = importer.call(json: geojson("CERRO"))
    second = importer.call(json: geojson("CERRO"))
    zone = Zone.find_by!(slug: "cerro")

    assert_equal 1, first.created_count
    assert_equal 0, first.updated_count
    assert_equal 0, second.created_count
    assert_equal 1, second.updated_count
    assert_equal "Cerro", zone.name
    assert_includes zone.aliases, "villa del cerro"
    assert_equal Zones::ImportMontevideoNeighborhoods::SOURCE_URL, zone.source_url
    assert zone.geom.present?
  end

  private

  def geojson(name)
    JSON.generate(
      type: "FeatureCollection",
      features: [{
        type: "Feature",
        properties: { gid: 35, barrio: name },
        geometry: {
          type: "MultiPolygon",
          coordinates: [[[
            [-56.27, -34.91], [-56.22, -34.91], [-56.22, -34.86],
            [-56.27, -34.86], [-56.27, -34.91]
          ]]]
        }
      }]
    )
  end
end
