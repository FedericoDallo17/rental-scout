require "json"
require "net/http"
require "uri"
require_relative "info_casas_legacy_map"

module Sources
  class InfoCasasApiAdapter
    ENDPOINT_URI = URI("https://graph.infocasas.com.uy/graphql")
    FRONTEND_BASE_URL = "https://www.infocasas.com.uy"
    OPEN_TIMEOUT_SECONDS = 5
    READ_TIMEOUT_SECONDS = 15
    LEGACY_HEADERS = {
      accept: "*/*",
      "accept-language": "es-419,es;q=0.9",
      authorization: "",
      "content-type": "application/json",
      "ic-user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36",
      priority: "u=1, i",
      "sec-ch-ua": "  \"Chromium\";v=\"136\", \"Google Chrome\";v=\"136\", \"Not.A/Brand\";v=\"99\"",
      "sec-ch-ua-mobile": "?0",
      "sec-ch-ua-platform": "\"Windows\"",
      "sec-fetch-dest": "empty",
      "sec-fetch-mode": "cors",
      "sec-fetch-site": "same-site",
      "x-cookiepot": "3",
      "x-origin": "www.infocasas.com.uy"
    }.freeze
    RESULTS_GRID_QUERY = <<~GRAPHQL.freeze
      query ResultsGird_v2($rows: Int!, $params: SearchParamsInput!, $page: Int, $source: Int) {
        searchFast(params: $params, first: $rows, page: $page, source: $source)
      }
    GRAPHQL
    SEARCH_URL_QUERY = <<~GRAPHQL.chomp.freeze
      query searchUrl($params: SearchParamsInput!) {
        searchUrl(params: $params) {
          url
          __typename
        }
      }
    GRAPHQL

    def fetch_listings
      payload.dig(0, :data, :searchFast, :data).map do |entry|
        location_name = entry.dig(:location, :name)

        {
          external_id: entry[:id].to_s,
          title: entry[:title],
          canonical_url: URI.join(FRONTEND_BASE_URL, entry[:link]).to_s,
          description: entry[:description],
          price_cents: normalize_price(entry[:price]),
          currency: "UYU",
          location_text: location_name,
          source_neighborhood: location_name,
          source_city: source_city(location_name),
          operation_type: operation_type(entry[:link]),
          bedrooms: integer_or_nil(entry[:bedrooms]),
          square_meters: integer_or_nil(entry[:area]),
          latitude: entry[:lat] || entry.dig(:location, :lat),
          longitude: entry[:lng] || entry.dig(:location, :lng)
        }
      end
    end

    private

    def payload
      JSON.parse(http_response.body, symbolize_names: true)
    end

    def http_response
      Net::HTTP.start(
        ENDPOINT_URI.host,
        ENDPOINT_URI.port,
        use_ssl: true,
        open_timeout: OPEN_TIMEOUT_SECONDS,
        read_timeout: READ_TIMEOUT_SECONDS
      ) do |http|
        request = Net::HTTP::Post.new(ENDPOINT_URI)
        LEGACY_HEADERS.each do |header, value|
          request[header] = value
        end
        request.body = request_body
        http.request(request)
      end
    end

    def request_body
      JSON.generate([
        {
          operationName: "ResultsGird_v2",
          variables: {
            rows: 50,
            params: legacy_search_params,
            page: 1,
            source: 0
          },
          query: RESULTS_GRID_QUERY
        },
        {
          operationName: "searchUrl",
          variables: {
            params: legacy_search_params
          },
          query: SEARCH_URL_QUERY
        }
      ])
    end

    def legacy_search_params
      {
        page: 1,
        order: 2,
        operation_type_id: 2,
        property_type_id: [2],
        currencyID: 2,
        m2Currency: 2,
        mapView: false,
        estate_id: [10],
        neighborhood_id: [],
        bedrooms: nil,
        publicationDate: nil,
        minPrice: nil,
        maxPrice: nil,
        m2Min: nil,
        m2Max: nil,
        map_polygon: [],
        map_bounds: []
      }
    end

    def normalize_price(price)
      return if price.blank?

      price.to_i * 100
    end

    def integer_or_nil(value)
      return if value.blank?

      value.to_i
    end

    def source_city(location_name)
      return if location_name.blank? || !location_name.include?(",")

      location_name.split(",").last.strip.presence
    end

    def operation_type(link)
      link.to_s.split("/").reject(&:blank?).first.presence
    end
  end
end
