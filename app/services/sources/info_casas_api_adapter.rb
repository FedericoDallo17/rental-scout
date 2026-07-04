require "json"
require "net/http"
require "uri"

module Sources
  class InfoCasasApiAdapter
    ENDPOINT_URI = URI("https://graph.infocasas.com.uy/graphql")
    FRONTEND_BASE_URL = "https://www.infocasas.com.uy"

    def fetch_listings
      payload.dig(0, :data, :searchFast, :data).map do |entry|
        {
          external_id: entry[:id].to_s,
          title: entry[:title],
          canonical_url: URI.join(FRONTEND_BASE_URL, entry[:link]).to_s,
          description: entry[:description],
          price_cents: normalize_price(entry[:price]),
          currency: "UYU",
          location_text: entry.dig(:location, :name),
          bedrooms: integer_or_nil(entry[:bedrooms]),
          square_meters: integer_or_nil(entry[:area])
        }
      end
    end

    private

    def payload
      JSON.parse(http_response.body, symbolize_names: true)
    end

    def http_response
      Net::HTTP.start(ENDPOINT_URI.host, ENDPOINT_URI.port, use_ssl: true) do |http|
        request = Net::HTTP::Post.new(ENDPOINT_URI)
        request["accept"] = "*/*"
        request["content-type"] = "application/json"
        request["x-origin"] = "www.infocasas.com.uy"
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
            params: {
              page: 1,
              order: 2,
              operation_type_id: 2,
              property_type_id: [2],
              currencyID: 2,
              maxPrice: 42000,
              bedrooms: [1],
              m2Min: 45
            },
            page: 1,
            source: 0
          },
          query: "query ResultsGird_v2($rows: Int!, $params: SearchParamsInput!, $page: Int, $source: Int) { searchFast(params: $params, first: $rows, page: $page, source: $source) }"
        }
      ])
    end

    def normalize_price(price)
      return if price.blank?

      price.to_i * 100
    end

    def integer_or_nil(value)
      return if value.blank?

      value.to_i
    end
  end
end
