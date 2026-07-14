require "test_helper"
require "net/http"

class Sources::InfoCasasApiAdapterTest < ActiveSupport::TestCase
  test "fetch_listings normalizes the legacy info casas payload into listing intake attributes" do
    adapter = Sources::InfoCasasApiAdapter.new(page_throttle_seconds: 0, detail_throttle_seconds: 0)
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
          expenses_cents: 450_000,
          expenses_currency: "UYU",
          location_text: "Pocitos, Montevideo",
          source_neighborhood: "Pocitos, Montevideo",
          source_city: "Montevideo",
          operation_type: "alquiler",
          bedrooms: 2,
          square_meters: 58,
          latitude: -34.885,
          longitude: -56.082
        },
        listings.first.slice(
          :external_id,
          :title,
          :canonical_url,
          :description,
          :price_cents,
          :currency,
          :expenses_cents,
          :expenses_currency,
          :location_text,
          :source_neighborhood,
          :source_city,
          :operation_type,
          :bedrooms,
          :square_meters,
          :latitude,
          :longitude
        )
      )
    end
  end

  test "fetch_listings leaves expenses empty when InfoCasas does not publish common expenses" do
    adapter = Sources::InfoCasasApiAdapter.new
    entry = info_casas_entry(id: 124)
    entry[:commonExpenses] = nil

    stub_http_response(adapter, stubbed_info_casas_response_for([entry])) do
      listing = adapter.fetch_listings.first

      assert_nil listing[:expenses_cents]
      assert_equal "UYU", listing[:expenses_currency]
    end
  end

  test "fetch_listings preserves rent currency while expenses remain in pesos" do
    adapter = Sources::InfoCasasApiAdapter.new
    uyu_entry = info_casas_entry(id: 124, currency: "$", currency_id: 2)
    usd_entry = info_casas_entry(id: 125, price: 3500, currency: "U$S", currency_id: 1)

    stub_http_response(adapter, stubbed_info_casas_response_for([uyu_entry, usd_entry])) do
      uyu_listing, usd_listing = adapter.fetch_listings

      assert_equal "UYU", uyu_listing[:currency]
      assert_equal "USD", usd_listing[:currency]
      assert_equal 350_000, usd_listing[:price_cents]
      assert_equal "UYU", uyu_listing[:expenses_currency]
      assert_equal "UYU", usd_listing[:expenses_currency]
    end
  end

  test "fetch_listings requests broad montevideo inventory without legacy map filters" do
    adapter = Sources::InfoCasasApiAdapter.new(page_throttle_seconds: 0, detail_throttle_seconds: 0)

    params = adapter.send(:legacy_search_params)

    assert_equal [], params[:map_polygon]
    assert_equal [], params[:map_bounds]
    assert_equal 10, params[:estate_id]
    assert_equal [1, 2], params[:property_type_id]
    assert_equal 1, params[:publicationDate]
    assert_nil params[:currencyID]
  end

  test "reconciliation removes the publication date window" do
    adapter = Sources::InfoCasasApiAdapter.new

    params = adapter.send(:legacy_search_params, reconciliation: true)

    assert_nil params[:publicationDate]
    assert_equal 1, adapter.send(:legacy_search_params)[:publicationDate]
  end

  test "fetch_listings requests every recent page until results are exhausted" do
    adapter = Sources::InfoCasasApiAdapter.new(page_throttle_seconds: 0, detail_throttle_seconds: 0)
    test_case = self
    requested_pages = []

    http = Object.new
    http.define_singleton_method(:request) do |request|
      page = JSON.parse(request.body).first.fetch("variables").fetch("page")
      requested_pages << page
      entries = if page == 1
        Array.new(50) { |index| test_case.send(:info_casas_entry, id: index + 1) }
      else
        [
          test_case.send(:info_casas_entry, id: 51, title: "Casa reciente 51"),
          test_case.send(:info_casas_entry, id: 52, title: "Casa reciente 52")
        ]
      end

      Struct.new(:body).new(test_case.send(:stubbed_info_casas_response_for, entries))
    end

    stub_net_http_start(->(*, **, &block) { block.call(http) }) do
      listings = adapter.fetch_listings

      assert_equal [1, 2], requested_pages
      assert_equal 52, listings.size
      assert_equal %w[1 52], [listings.first[:external_id], listings.last[:external_id]]
    end
  end

  test "fetch_listings returns coordinates and source metadata" do
    adapter = Sources::InfoCasasApiAdapter.new

    response = stubbed_info_casas_response(
      id: 123,
      title: "Apto Malvin",
      location_name: "Malvín, Montevideo",
      latitude: -34.885,
      longitude: -56.082
    )

    stub_http_response(adapter, response) do
      listing = adapter.fetch_listings.first

      assert_equal -34.885, listing[:latitude]
      assert_equal -56.082, listing[:longitude]
      assert_equal "Malvín, Montevideo", listing[:source_neighborhood]
      assert_equal "Montevideo", listing[:source_city]
    end
  end

  test "fetch_listings derives scope metadata from the provider payload" do
    adapter = Sources::InfoCasasApiAdapter.new

    response = stubbed_info_casas_response(
      id: 456,
      title: "Casa en Peninsula",
      link: "/venta/casa/peninsula/456",
      location_name: "Peninsula, Punta del Este",
      latitude: -34.962,
      longitude: -54.947
    )

    stub_http_response(adapter, response) do
      listing = adapter.fetch_listings.first

      assert_equal "Punta del Este", listing[:source_city]
      assert_equal "venta", listing[:operation_type]
    end
  end

  test "fetch_listings normalizes live provider metadata for internal filtering" do
    adapter = Sources::InfoCasasApiAdapter.new
    entry = info_casas_entry(
      id: 789,
      title: "Apartamento reciente en Prado",
      link: "/apartamento-reciente-en-prado/789",
      location_name: nil,
      latitude: nil,
      longitude: nil,
      area: nil,
      operation_type_id: 2,
      property_type_id: 2,
      neighborhood: "Prado",
      estate: "Montevideo",
      m2: 40
    )

    stub_http_response(adapter, stubbed_info_casas_response_for([entry])) do
      listing = adapter.fetch_listings.first

      assert_equal "Prado, Montevideo", listing[:location_text]
      assert_equal "Prado", listing[:source_neighborhood]
      assert_equal "Montevideo", listing[:source_city]
      assert_equal "alquiler", listing[:operation_type]
      assert_equal 40, listing[:square_meters]
      assert_nil listing[:latitude]
      assert_nil listing[:longitude]
    end
  end

  test "fetch_listings corrects a conflicting Centro fallback for Villa del Cerro" do
    adapter = Sources::InfoCasasApiAdapter.new
    entry = info_casas_entry(
      id: 193982167,
      title: "Casa en alquiler c/ cochera en Villa del Cerro",
      link: "/casa-en-alquiler-c-cochera-en-villa-del-cerro/193982167",
      location_name: "Centro, Montevideo",
      neighborhood: "Centro",
      estate: "Montevideo"
    )

    stub_http_response(adapter, stubbed_info_casas_response_for([entry])) do
      listing = adapter.fetch_listings.first

      assert_equal "Cerro, Montevideo", listing[:location_text]
      assert_equal "Cerro", listing[:source_neighborhood]
      assert_equal "Montevideo", listing[:source_city]
    end
  end

  test "fetch_listings corrects a conflicting Centro fallback when Buceo is misspelled with a zero" do
    adapter = Sources::InfoCasasApiAdapter.new
    entry = info_casas_entry(
      id: 193979816,
      title: "ALQUILER | Casas en Buce0 2 dormitorios garaje $42000",
      link: "/alquiler-casas-en-buce0-2-dormitorios-garaje-42000/193979816",
      location_name: "Centro, Montevideo",
      neighborhood: "Centro",
      estate: "Montevideo"
    )

    stub_http_response(adapter, stubbed_info_casas_response_for([entry])) do
      listing = adapter.fetch_listings.first

      assert_equal "Buceo, Montevideo", listing[:location_text]
      assert_equal "Buceo", listing[:source_neighborhood]
      assert_equal "Montevideo", listing[:source_city]
    end
  end

  test "fetch_listings never fetches detail pages inline" do
    adapter = Sources::InfoCasasApiAdapter.new(page_throttle_seconds: 0, detail_throttle_seconds: 0)
    detail_fetch_attempted = false
    adapter.define_singleton_method(:detail_response) do |*|
      detail_fetch_attempted = true
      raise "inline detail fetch attempted"
    end

    entry = info_casas_entry(id: 1, latitude: nil, longitude: nil)
    stub_http_response(adapter, stubbed_info_casas_response_for([entry])) do
      listing = adapter.fetch_listings.first

      assert_not detail_fetch_attempted, "fetch_listings must not fetch detail pages (adr-no-inline-detail-fetch)"
      assert_nil listing[:latitude]
      assert_nil listing[:longitude]
    end
  end

  test "fetch_listings raises UnexpectedResponseError when payload malformed" do
    adapter = Sources::InfoCasasApiAdapter.new(page_throttle_seconds: 0, detail_throttle_seconds: 0)

    stub_http_response(adapter, JSON.generate([{ data: {} }])) do
      assert_raises(Sources::InfoCasasApiAdapter::UnexpectedResponseError) do
        adapter.fetch_listings
      end
    end
  end

  test "fetch_listings stops at max page guard when every page is full" do
    adapter = Sources::InfoCasasApiAdapter.new(page_throttle_seconds: 0, detail_throttle_seconds: 0)
    test_case = self
    requested_pages = []

    http = Object.new
    http.define_singleton_method(:request) do |request|
      page = JSON.parse(request.body).first.fetch("variables").fetch("page")
      requested_pages << page
      entries = Array.new(50) { |index| test_case.send(:info_casas_entry, id: (page * 1000) + index) }

      Struct.new(:body).new(test_case.send(:stubbed_info_casas_response_for, entries))
    end

    stub_net_http_start(->(*, **, &block) { block.call(http) }) do
      listings = adapter.fetch_listings

      assert_equal Sources::InfoCasasApiAdapter::MAX_PAGES, requested_pages.size
      assert_equal 50 * Sources::InfoCasasApiAdapter::MAX_PAGES, listings.size
    end
  end

  test "detail_coordinates_for_url returns empty hash and logs when detail fetch fails" do
    adapter = Sources::InfoCasasApiAdapter.new(page_throttle_seconds: 0, detail_throttle_seconds: 0)
    adapter.define_singleton_method(:detail_response) { |*| raise Net::ReadTimeout }
    logged = []

    original_warn = Rails.logger.method(:warn)
    Rails.logger.define_singleton_method(:warn) { |message| logged << message }
    begin
      assert_equal({}, adapter.detail_coordinates_for_url("https://www.infocasas.com.uy/x/1"))
    ensure
      Rails.logger.define_singleton_method(:warn, original_warn)
    end

    assert_match(/detail coordinate fetch failed/, logged.join)
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

  test "fetch_listings sends the legacy InfoCasas request shape" do
    adapter = Sources::InfoCasasApiAdapter.new
    test_case = self
    response = Struct.new(:body).new(sample_response_body)
    http = Object.new

    http.define_singleton_method(:request) do |request|
      request_headers = request.each_header.to_h
      request_body = JSON.parse(request.body)
      expected_headers = test_case.send(:expected_legacy_request_headers)
      expected_results_grid_variables = test_case.send(:expected_legacy_results_grid_variables)
      expected_search_params = test_case.send(:expected_legacy_search_params)
      expected_results_grid_query = test_case.send(:expected_results_grid_query)
      expected_search_url_query = test_case.send(:expected_search_url_query)

      test_case.assert_equal expected_headers, request_headers.slice(*expected_headers.keys)
      test_case.assert_equal 2, request_body.size

      results_grid_request = request_body.fetch(0)
      search_url_request = request_body.fetch(1)
      test_case.assert_equal [], results_grid_request.dig("variables", "params", "map_polygon")
      test_case.assert_equal [], search_url_request.dig("variables", "params", "map_polygon")

      test_case.assert_equal "ResultsGird_v2", results_grid_request.fetch("operationName")
      test_case.assert_equal expected_results_grid_variables, test_case.send(:strip_map_polygon, results_grid_request.fetch("variables"))
      test_case.assert_equal expected_results_grid_query, results_grid_request.fetch("query")

      test_case.assert_equal "searchUrl", search_url_request.fetch("operationName")
      test_case.assert_equal({ "params" => expected_search_params }, test_case.send(:strip_map_polygon, search_url_request.fetch("variables")))
      test_case.assert_equal expected_search_url_query, search_url_request.fetch("query")

      response
    end

    stub_net_http_start(->(*, **, &block) { block.call(http) }) do
      adapter.fetch_listings
    end
  end

  private

  def sample_response_body
    stubbed_info_casas_response(
      id: "123",
      title: "Apartamento en Pocitos",
      description: "Apartamento luminoso con terraza",
      link: "/alquiler/apartamento/pocitos/123",
      price: 35000,
      location_name: "Pocitos, Montevideo",
      bedrooms: 2,
      area: 58,
      latitude: -34.885,
      longitude: -56.082
    )
  end

  def stubbed_info_casas_response(id:, title:, location_name:, latitude:, longitude:, description: "Apartamento luminoso con terraza", link: "/alquiler/apartamento/pocitos/123", price: 35000, bedrooms: 2, area: 58)
    stubbed_info_casas_response_for([
      info_casas_entry(
        id: id,
        title: title,
        description: description,
        link: link,
        price: price,
        location_name: location_name,
        bedrooms: bedrooms,
        area: area,
        latitude: latitude,
        longitude: longitude
      )
    ])
  end

  def stubbed_info_casas_response_for(entries)
    JSON.generate([
      {
        data: {
          searchFast: {
            data: entries
          }
        }
      }
    ])
  end

  def info_casas_entry(
    id:,
    title: "Apartamento en Pocitos",
    description: "Apartamento luminoso con terraza",
    link: "/alquiler/apartamento/pocitos/123",
    price: 35000,
    location_name: "Pocitos, Montevideo",
    bedrooms: 2,
    area: 58,
    m2: nil,
    latitude: -34.885,
    longitude: -56.082,
    operation_type_id: nil,
    property_type_id: nil,
    neighborhood: nil,
    estate: nil,
    currency: "$",
    currency_id: 2
  )
    {
      id: id,
      title: title,
      description: description,
      link: link,
      price: price,
      currency: currency,
      currency_id: currency_id,
      operation_type_id: operation_type_id,
      property_type_id: property_type_id,
      commonExpenses: 4500,
      facilities: ["9"],
      location: location_name ? { name: location_name, lat: latitude, lng: longitude } : nil,
      neighborhood: neighborhood,
      estate: estate,
      lat: latitude,
      lng: longitude,
      bedrooms: bedrooms,
      area: area,
      m2: m2
    }
  end

  def stub_http_response(adapter, body)
    response = Struct.new(:body).new(body)

    adapter.define_singleton_method(:http_response) do |*|
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

  def expected_legacy_request_headers
    {
      "accept" => "*/*",
      "accept-language" => "es-419,es;q=0.9",
      "authorization" => "",
      "content-type" => "application/json",
      "ic-user-agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36",
      "priority" => "u=1, i",
      "sec-ch-ua" => "  \"Chromium\";v=\"136\", \"Google Chrome\";v=\"136\", \"Not.A/Brand\";v=\"99\"",
      "sec-ch-ua-mobile" => "?0",
      "sec-ch-ua-platform" => "\"Windows\"",
      "sec-fetch-dest" => "empty",
      "sec-fetch-mode" => "cors",
      "sec-fetch-site" => "same-site",
      "x-cookiepot" => "3",
      "x-origin" => "www.infocasas.com.uy"
    }
  end

  def expected_legacy_results_grid_variables
    {
      "rows" => 50,
      "params" => expected_legacy_search_params,
      "page" => 1,
      "source" => 0
    }
  end

  def expected_legacy_search_params
    {
      "page" => 1,
      "order" => 2,
      "operation_type_id" => 2,
      "property_type_id" => [1, 2],
      "currencyID" => nil,
      "m2Currency" => 2,
      "mapView" => false,
      "estate_id" => 10,
      "neighborhood_id" => [],
      "bedrooms" => nil,
      "publicationDate" => 1,
      "minPrice" => nil,
      "maxPrice" => nil,
      "m2Min" => nil,
      "m2Max" => nil,
      "map_bounds" => []
    }
  end

  def strip_map_polygon(variables)
    variables.deep_dup.tap do |copy|
      copy.fetch("params").delete("map_polygon")
    end
  end

  def expected_results_grid_query
    "query ResultsGird_v2($rows: Int!, $params: SearchParamsInput!, $page: Int, $source: Int) {\n  searchFast(params: $params, first: $rows, page: $page, source: $source)\n}\n"
  end

  def expected_search_url_query
    "query searchUrl($params: SearchParamsInput!) {\n  searchUrl(params: $params) {\n    url\n    __typename\n  }\n}"
  end

end
