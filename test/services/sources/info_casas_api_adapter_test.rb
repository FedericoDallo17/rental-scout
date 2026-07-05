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
      test_case.send(:assert_legacy_map_polygon, results_grid_request.dig("variables", "params", "map_polygon"))
      test_case.send(:assert_legacy_map_polygon, search_url_request.dig("variables", "params", "map_polygon"))

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
      "bedroomsExactMode" => false,
      "bathroomsExactMode" => false,
      "operation_type_id" => 2,
      "property_type_id" => [2],
      "season" => nil,
      "dateFrom" => nil,
      "dateTo" => nil,
      "currencyID" => 2,
      "m2Currency" => 2,
      "guests" => nil,
      "projects" => nil,
      "minPrice" => nil,
      "maxPrice" => 42_000,
      "commonExpenses" => nil,
      "rooms" => nil,
      "mapView" => false,
      "neighborhood_id" => [],
      "estate_id" => nil,
      "bedrooms" => [1],
      "publicationDate" => 0,
      "m2Min" => 45,
      "m2Max" => nil,
      "map_bounds" => expected_legacy_map_bounds
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

  def expected_legacy_map_bounds
    [
      { "latitude" => -34.90992011790014, "longitude" => -56.144040857363876 },
      { "latitude" => -34.9071574328263, "longitude" => -56.14689472775572 },
      { "latitude" => -34.90706944769785, "longitude" => -56.150542532015976 },
      { "latitude" => -34.90889951895506, "longitude" => -56.15341786007994 },
      { "latitude" => -34.912717901670106, "longitude" => -56.15320328335875 },
      { "latitude" => -34.91354490125635, "longitude" => -56.15071419339293 },
      { "latitude" => -34.913527305607225, "longitude" => -56.14773157696837 },
      { "latitude" => -34.91006088917279, "longitude" => -56.14386919598692 },
      { "latitude" => -34.90992011790014, "longitude" => -56.144040857363876 }
    ]
  end

  def assert_legacy_map_polygon(actual_points)
    assert_equal 1073, actual_points.length
    assert_equal(
      [
        { "latitude" => -34.90992011790014, "longitude" => -56.144040857363876 },
        { "latitude" => -34.9099025214741, "longitude" => -56.144040857363876 },
        { "latitude" => -34.90988492504427, "longitude" => -56.144040857363876 }
      ],
      actual_points.first(3)
    )
    assert_equal(
      [
        { "latitude" => -34.91007848556491, "longitude" => -56.14389065365904 },
        { "latitude" => -34.91006088917279, "longitude" => -56.14389065365904 },
        { "latitude" => -34.91006088917279, "longitude" => -56.14386919598692 }
      ],
      actual_points.last(3)
    )
  end
end
