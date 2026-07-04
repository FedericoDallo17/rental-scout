require "test_helper"
require "net/http"

class Sources::InfoCasasApiAdapterTest < ActiveSupport::TestCase
  test "fetch_listings normalizes the legacy info casas payload into listing intake attributes" do
    adapter = Sources::InfoCasasApiAdapter.new
    stub_http_response(adapter, sample_response_body) do
      listings = adapter.fetch_listings

      assert_equal 1, listings.size
      assert_equal(
        {
          external_id: "123",
          title: "Apartamento en Pocitos",
          canonical_url: "https://www.infocasas.com.uy/alquiler/apartamento/pocitos/123",
          description: "Apartamento luminoso con terraza",
          price_cents: 3_500_000,
          currency: "UYU",
          location_text: "Pocitos, Montevideo",
          bedrooms: 2,
          square_meters: 58
        },
        listings.first.slice(
          :external_id,
          :title,
          :canonical_url,
          :description,
          :price_cents,
          :currency,
          :location_text,
          :bedrooms,
          :square_meters
        )
      )
    end
  end

  test "fetch_listings raises when the payload is malformed" do
    adapter = Sources::InfoCasasApiAdapter.new

    stub_http_response(adapter, JSON.generate([{ data: {} }])) do
      assert_raises(NoMethodError) do
        adapter.fetch_listings
      end
    end
  end

  private

  def sample_response_body
    JSON.generate([
      {
        data: {
          searchFast: {
            data: [
              {
                id: "123",
                title: "Apartamento en Pocitos",
                description: "Apartamento luminoso con terraza",
                link: "/alquiler/apartamento/pocitos/123",
                price: 35000,
                commonExpenses: 4500,
                facilities: ["9"],
                location: { name: "Pocitos, Montevideo" },
                bedrooms: 2,
                area: 58
              }
            ]
          }
        }
      }
    ])
  end

  def stub_http_response(adapter, body)
    response = Struct.new(:body).new(body)

    adapter.define_singleton_method(:http_response) do
      response
    end

    yield
  ensure
    adapter.singleton_class.remove_method(:http_response)
  end
end
