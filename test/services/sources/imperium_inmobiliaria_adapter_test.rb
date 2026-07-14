require "test_helper"
require "net/http"

class Sources::ImperiumInmobiliariaAdapterTest < ActiveSupport::TestCase
  test "fetch_listings normalizes Imperium API properties into intake attributes" do
    adapter = Sources::ImperiumInmobiliariaAdapter.new

    stub_net_http_start(response_body: imperium_response_body) do
      listings = adapter.fetch_listings

      assert_equal 1, listings.size
      listing = listings.first

      assert_equal "IMP-2026-2101", listing[:external_id]
      assert_equal "ALQUILER | Apartamento 2 Dormitorios en Pocitos", listing[:title]
      assert_equal "https://www.inmobiliariaimperium.com/propiedades/IMP-2026-2101", listing[:canonical_url]
      assert_equal 5_350_000, listing[:price_cents]
      assert_equal "UYU", listing[:currency]
      assert_equal "Coronel Alegre 1195, 11300 Montevideo, Uruguay", listing[:location_text]
      assert_equal "Pocitos", listing[:source_neighborhood]
      assert_equal "Montevideo", listing[:source_city]
      assert_equal "alquiler", listing[:operation_type]
      assert_equal 2, listing[:bedrooms]
      assert_equal 76, listing[:square_meters]
      assert_equal 450_000, listing[:expenses_cents]
      assert_equal "UYU", listing[:expenses_currency]
      assert_equal 1, listing[:parking_spaces]
      assert_equal "Apartamento", listing[:property_type]
    end
  end

  test "fetch_listings filters Imperium rows that cannot represent residential bedroom listings" do
    adapter = Sources::ImperiumInmobiliariaAdapter.new

    stub_net_http_start(response_body: imperium_response_body) do
      external_ids = adapter.fetch_listings.map { |listing| listing[:external_id] }

      assert_equal ["IMP-2026-2101"], external_ids
    end
  end

  test "fetch_listings exposes only the Apartamento and Casa property types" do
    adapter = Sources::ImperiumInmobiliariaAdapter.new
    body = JSON.parse(imperium_response_body)
    house = body.fetch("data").first.deep_dup
    house["propertyId"] = "IMP-HOUSE"
    house["type"] = "house"
    body.fetch("data") << house

    stub_net_http_start(response_body: JSON.generate(body)) do
      assert_equal ["Apartamento", "Casa"], adapter.fetch_listings.map { |listing| listing[:property_type] }
    end
  end

  test "fetch_listings skips malformed Imperium rows without dropping valid listings" do
    adapter = Sources::ImperiumInmobiliariaAdapter.new

    stub_net_http_start(response_body: imperium_response_body(include_malformed: true)) do
      external_ids = adapter.fetch_listings.map { |listing| listing[:external_id] }

      assert_equal ["IMP-2026-2101"], external_ids
    end
  end

  test "fetch_listings does not invent Pocitos when Imperium omits the neighborhood" do
    adapter = Sources::ImperiumInmobiliariaAdapter.new
    body = JSON.parse(imperium_response_body)
    property = body.dig("data", 0)
    property["location"]["city"] = "Montevideo"

    stub_net_http_start(response_body: JSON.generate(body)) do
      listing = adapter.fetch_listings.first

      assert_nil listing[:source_neighborhood]
      assert_equal "Coronel Alegre 1195, 11300 Montevideo, Uruguay", listing[:location_text]
    end
  end

  test "fetch_listings uses explicit HTTP timeouts for Imperium request" do
    adapter = Sources::ImperiumInmobiliariaAdapter.new
    seen_request = false
    request_assertion = lambda do |host, port, options, request|
      assert_equal "imperium-backend-production-9783.up.railway.app", host
      assert_equal 443, port
      assert_equal true, options[:use_ssl]
      assert options.key?(:open_timeout)
      assert options.key?(:read_timeout)
      assert_instance_of Net::HTTP::Get, request
      assert_match(/operation=rent/, request.path)
      assert_match(/limit=12/, request.path)
      seen_request = true
    end

    stub_net_http_start(response_body: imperium_response_body, request_assertion:) do
      adapter.fetch_listings
    end

    assert_equal true, seen_request
  end

  test "fetch_listings stops recent pagination after a page reaches a known id" do
    adapter = Sources::ImperiumInmobiliariaAdapter.new
    requested_pages = []

    stub_paginated_responses(
      {
        1 => imperium_response_body(id: "NEW-1"),
        2 => imperium_response_body(id: "IMP-2026-2101"),
        3 => imperium_response_body(id: "OLD-1")
      },
      requested_pages:
    ) do
      listings = adapter.fetch_listings(known_external_ids: Set["IMP-2026-2101"])

      assert_equal [1, 2], requested_pages
      assert_equal %w[NEW-1 IMP-2026-2101], listings.map { |listing| listing[:external_id] }
    end
  end

  private

  def imperium_response_body(include_malformed: false, id: "IMP-2026-2101")
    rows = [
      {
        propertyId: id,
        title: "ALQUILER | Apartamento 2 Dormitorios en Pocitos",
        description: "<p>Excelente apartamento de diseño en alquiler en Pocitos</p>",
        type: "apartment",
        pricing: { rentPrice: 53500, currency: "UYU", monthlyExpenses: 4500, expensesCurrency: "UYU" },
        location: { address: "Coronel Alegre 1195, 11300 Montevideo, Uruguay", city: "Pocitos", state: "Montevideo" },
        features: { totalArea: 76, bedrooms: 2, garages: 1 }
      },
      {
        propertyId: "IMP-COMMERCIAL",
        title: "ALQUILER | Local en Montevideo con 63 m² de Espacio",
        type: "commercial",
        pricing: { rentPrice: 55000, currency: "UYU" },
        location: { address: "Avenida General Rivera 2735, Montevideo, Uruguay", city: "Pocitos", state: "Montevideo" },
        features: { totalArea: 63 }
      }
    ]

    rows << { title: "Malformed apartment", type: "apartment", features: { bedrooms: 1 } } if include_malformed

    JSON.generate(
      success: true,
      data: rows,
      pagination: { page: 1, limit: 12, total: rows.size, totalPages: 1 }
    )
  end

  def stub_paginated_responses(responses, requested_pages:)
    original_start = Net::HTTP.method(:start)
    http = Object.new
    http.define_singleton_method(:request) do |request|
      page = URI.decode_www_form(URI.parse("https://example.test#{request.path}").query).to_h.fetch("page").to_i
      requested_pages << page
      Struct.new(:body).new(responses.fetch(page, JSON.generate(success: true, data: [])))
    end
    Net::HTTP.define_singleton_method(:start) { |_host, _port, **_options, &block| block.call(http) }

    yield
  ensure
    Net::HTTP.define_singleton_method(:start) do |*args, **kwargs, &block|
      original_start.call(*args, **kwargs, &block)
    end
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
