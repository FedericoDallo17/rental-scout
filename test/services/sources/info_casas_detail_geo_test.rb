require "test_helper"
require "net/http"

class Sources::InfoCasasDetailGeoTest < ActiveSupport::TestCase
  test "fetch_listings extracts coordinates from listing detail html when search payload omits them" do
    adapter = Sources::InfoCasasApiAdapter.new
    entry = {
      id: 790,
      title: "Apartamento en Cordón con mapa",
      description: "Apartamento en Cordón",
      link: "/apartamento-en-cordon-con-mapa/790",
      price: 31_000,
      operation_type_id: 2,
      property_type_id: 2,
      commonExpenses: 5200,
      facilities: [],
      neighborhood: "Cordón",
      estate: "Montevideo",
      bedrooms: 1,
      area: nil,
      m2: nil,
      lat: nil,
      lng: nil
    }

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

    stub_search_response(adapter, [entry]) do
      adapter.define_singleton_method(:detail_response) do |_canonical_url|
        Struct.new(:body).new(detail_html)
      end

      listing = adapter.fetch_listings.first

      assert_equal(-34.9057216, listing[:latitude])
      assert_equal(-56.1822016, listing[:longitude])
    ensure
      adapter.singleton_class.remove_method(:detail_response)
    end
  end

  private

  def stub_search_response(adapter, entries)
    response = Struct.new(:body).new(JSON.generate([{ data: { searchFast: { data: entries } } }]))
    adapter.define_singleton_method(:http_response) do |_page|
      response
    end
    yield
  ensure
    adapter.singleton_class.remove_method(:http_response)
  end
end
