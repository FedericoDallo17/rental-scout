require "test_helper"
require "net/http"

class Sources::InfoCasasDetailGeoTest < ActiveSupport::TestCase
  test "detail_coordinates_for_url extracts geo from JSON-LD in detail html" do
    adapter = Sources::InfoCasasApiAdapter.new(page_throttle_seconds: 0, detail_throttle_seconds: 0)
    detail_html = <<~HTML
      <!DOCTYPE html>
      <html>
        <head>
          <script type="application/ld+json">
            {"@context":"https://schema.org","@type":"RentAction","object":{"@type":"SingleFamilyResidence","address":"Constituyente 1555","geo":{"@type":"GeoCoordinates","latitude":-34.9057216,"longitude":-56.1822016}}}
          </script>
        </head>
      </html>
    HTML
    adapter.define_singleton_method(:detail_response) do |_canonical_url|
      Struct.new(:body).new(detail_html)
    end

    coordinates = adapter.detail_coordinates_for_url("https://www.infocasas.com.uy/apartamento-en-cordon-con-mapa/790")

    assert_equal(-34.9057216, coordinates[:latitude])
    assert_equal(-56.1822016, coordinates[:longitude])
  end

  test "detail_coordinates_for_url returns empty hash when the html has no geo block" do
    adapter = Sources::InfoCasasApiAdapter.new(page_throttle_seconds: 0, detail_throttle_seconds: 0)
    adapter.define_singleton_method(:detail_response) do |_canonical_url|
      Struct.new(:body).new("<!DOCTYPE html><html><head></head></html>")
    end

    assert_equal({}, adapter.detail_coordinates_for_url("https://www.infocasas.com.uy/sin-mapa/1"))
  end
end
