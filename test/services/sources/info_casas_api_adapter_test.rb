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

  test "fetch_listings uses explicit HTTP timeouts for the InfoCasas request" do
    adapter = Sources::InfoCasasApiAdapter.new
    test_case = self
    response = Struct.new(:body).new(sample_response_body)
    request_received = false
    http = Object.new
    http.define_singleton_method(:request) do |request|
      request_received = true
      test_case.assert_instance_of Net::HTTP::Post, request
      response
    end

    net_http_start = lambda do |host, port, **options, &block|
      test_case.assert_equal "graph.infocasas.com.uy", host
      test_case.assert_equal 443, port
      test_case.assert_equal true, options[:use_ssl]
      test_case.assert options.key?(:open_timeout), "expected open_timeout to be set"
      test_case.assert options.key?(:read_timeout), "expected read_timeout to be set"

      block.call(http)
    end

    stub_net_http_start(net_http_start) do
      adapter.fetch_listings
    end

    assert_equal true, request_received
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

  def stub_net_http_start(callable)
    original_start = Net::HTTP.method(:start)
    Net::HTTP.define_singleton_method(:start, callable)
    yield
  ensure
    Net::HTTP.define_singleton_method(:start) do |*args, **kwargs, &block|
      original_start.call(*args, **kwargs, &block)
    end
  end
end
