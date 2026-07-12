require "test_helper"
require "net/http"

class Sources::ImperiumInmobiliariaAdapterTest < ActiveSupport::TestCase
  test "fetch_listings normalizes Imperium API properties into intake attributes" do
    adapter = Sources::ImperiumInmobiliariaAdapter.new

    stub_net_http_start(response_body: imperium_response_body) do
      listings = adapter.fetch_listings

      assert_equal 1, listings.size
      listing = listings.first

      assert_equal "MLU695091687", listing[:external_id]
      assert_equal "ALQUILER | Apartamento 2 Dormitorios en Pocitos", listing[:title]
      assert_equal "https://www.inmobiliariaimperium.com/propiedad/MLU695091687", listing[:canonical_url]
      assert_equal 5_350_000, listing[:price_cents]
      assert_equal "UYU", listing[:currency]
      assert_equal "Coronel Alegre 1195, 11300 Montevideo, Uruguay", listing[:location_text]
      assert_equal "Pocitos", listing[:source_neighborhood]
      assert_equal "Montevideo", listing[:source_city]
      assert_equal "alquiler", listing[:operation_type]
      assert_equal 2, listing[:bedrooms]
      assert_equal 76, listing[:square_meters]
    end
  end

  test "fetch_listings filters Imperium rows that cannot represent residential bedroom listings" do
    adapter = Sources::ImperiumInmobiliariaAdapter.new

    stub_net_http_start(response_body: imperium_response_body) do
      external_ids = adapter.fetch_listings.map { |listing| listing[:external_id] }

      assert_equal ["MLU695091687"], external_ids
    end
  end

  test "fetch_listings uses explicit HTTP timeouts for Imperium request" do
    adapter = Sources::ImperiumInmobiliariaAdapter.new
    seen_request = false

    request_assertion = lambda do |host, port, options, request|
      assert_equal "imperium-prod.herokuapp.com", host
      assert_equal 443, port
      assert_equal true, options[:use_ssl]
      assert options.key?(:open_timeout)
      assert options.key?(:read_timeout)
      assert_instance_of Net::HTTP::Get, request
      assert_match(/operation=Alquiler/, request.path)
      seen_request = true
    end

    stub_net_http_start(response_body: imperium_response_body, request_assertion:) do
      adapter.fetch_listings
    end

    assert_equal true, seen_request
  end

  private

  def imperium_response_body
    JSON.generate(
      success: true,
      response: {
        result: [
          {
            property: {
              id: "MLU695091687",
              title: "ALQUILER | Apartamento 2 Dormitorios en Pocitos",
              description: "<p>Excelente apartamento de diseño en alquiler en Pocitos</p>",
              price: "53500",
              currency: "UYU",
              city: "Pocitos",
              area: "76",
              bedrooms: "2",
              parking: "1",
              typeProperty: "Apartamento",
              street: "Coronel Alegre 1195, 11300 Montevideo, Uruguay"
            }
          },
          {
            property: {
              id: "MLU974573946",
              title: "ALQUILER | Local en Montevideo con 63 m² de Espacio",
              price: "55000",
              currency: "UYU",
              city: "Pocitos",
              area: "63",
              bedrooms: nil,
              typeProperty: "Local",
              street: "Avenida General Rivera 2735, Montevideo, Uruguay"
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
