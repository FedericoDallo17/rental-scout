require "test_helper"
require "net/http"

class Sources::RemaxAdapterTest < ActiveSupport::TestCase
  test "fetch_listings normalizes RedREMAX API results into intake attributes" do
    adapter = Sources::RemaxAdapter.new

    stub_net_http_start(response_body: remax_response_body) do
      listing = adapter.fetch_listings.first

      assert_equal "30206", listing[:external_id]
      assert_equal "ALQUILER Pocitos 1 dormitorio balcón garage", listing[:title]
      assert_equal "https://www.remax.com.uy/listings/alquiler-pocitos-1-dormitorio-balcon-garage/30206", listing[:canonical_url]
      assert_equal 3_800_000, listing[:price_cents]
      assert_equal "UYU", listing[:currency]
      assert_equal "Pocitos, Montevideo", listing[:location_text]
      assert_equal "Pocitos", listing[:source_neighborhood]
      assert_equal "Montevideo", listing[:source_city]
      assert_equal "alquiler", listing[:operation_type]
      assert_equal 1, listing[:bedrooms]
      assert_equal 42, listing[:square_meters]
      assert_equal 500_000, listing[:expenses_cents]
      assert_equal "UYU", listing[:expenses_currency]
      assert_nil listing[:parking_spaces]
      assert_equal "departamento_estandar", listing[:property_type]
      assert_equal(-34.908573, listing[:latitude])
      assert_equal(-56.1483782, listing[:longitude])
    end
  end

  test "fetch_listings does not duplicate Montevideo when RedREMAX geo label already includes city" do
    adapter = Sources::RemaxAdapter.new

    stub_net_http_start(response_body: remax_response_body(geo_label: "Pocitos, Montevideo")) do
      listing = adapter.fetch_listings.first

      assert_equal "Pocitos, Montevideo", listing[:location_text]
      assert_equal "Pocitos", listing[:source_neighborhood]
      assert_equal "Montevideo", listing[:source_city]
    end
  end

  test "fetch_listings uses explicit HTTP timeouts for RedREMAX request" do
    adapter = Sources::RemaxAdapter.new
    seen_request = false
    request_assertion = lambda do |host, port, options, request|
      assert_equal "api-ar.redremax.com", host
      assert_equal 443, port
      assert_equal true, options[:use_ssl]
      assert options.key?(:open_timeout)
      assert options.key?(:read_timeout)
      assert_instance_of Net::HTTP::Get, request
      seen_request = true
    end

    stub_net_http_start(response_body: remax_response_body, request_assertion:) do
      adapter.fetch_listings
    end

    assert_equal true, seen_request
  end

  test "fetch_listings returns empty list for malformed RedREMAX payload" do
    adapter = Sources::RemaxAdapter.new

    stub_net_http_start(response_body: JSON.generate(data: {})) do
      assert_equal [], adapter.fetch_listings
    end
  end

  private

  def remax_response_body(geo_label: "Pocitos")
    JSON.generate(
      data: {
        data: [
          {
            id: 30206,
            title: "ALQUILER Pocitos 1 dormitorio balcón garage",
            slug: "alquiler-pocitos-1-dormitorio-balcon-garage",
            price: 38_000,
            expensesPrice: 5_000,
            expensesCurrency: { value: "UYU" },
            currency: { value: "UYU" },
            operation: { value: "rent" },
            type: { value: "departamento_estandar" },
            bedrooms: 1,
            dimensionCovered: 42,
            geoLabel: geo_label,
            location: {
              type: "Point",
              coordinates: [-56.1483782, -34.908573]
            }
          }
        ]
      }
    )
  end

  def stub_net_http_start(response_body:, request_assertion: nil)
    original_start = Net::HTTP.method(:start)
    response = Struct.new(:body).new(response_body)
    http = Object.new
    http.define_singleton_method(:request) do |request|
      yield_args = Thread.current[:net_http_start_args]
      request_assertion&.call(*yield_args, request) if yield_args
      response
    end

    Net::HTTP.define_singleton_method(:start) do |host, port, **options, &block|
      Thread.current[:net_http_start_args] = [host, port, options]
      block.call(http)
    ensure
      Thread.current[:net_http_start_args] = nil
    end

    yield
  ensure
    Net::HTTP.define_singleton_method(:start) do |*args, **kwargs, &block|
      original_start.call(*args, **kwargs, &block)
    end
  end
end
