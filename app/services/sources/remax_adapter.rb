require "json"
require "net/http"
require "uri"

module Sources
  class RemaxAdapter
    ENDPOINT_URI = URI("https://api-ar.redremax.com/remaxweb-uy/api/listings/findAllWithEntrepreneurships?page=0&pageSize=50&sort=-createdAt&in=operationId:2&in=typeId:1,2,3,4,5,6,7,8&pricein=3:0:65000&gte=dimensionCovered:30&locations=in:::1441@%3Cb%3EPocitos%3C%2Fb%3E::::&landingPath=")
    FRONTEND_BASE_URL = "https://www.remax.com.uy"
    OPEN_TIMEOUT_SECONDS = 5
    READ_TIMEOUT_SECONDS = 15

    HEADERS = {
      "accept" => "application/json, text/plain, */*",
      "user-agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36"
    }.freeze

    def fetch_listings
      entries.map { |entry| normalized_listing(entry) }
    rescue JSON::ParserError, KeyError, TypeError
      []
    end

    private

    def entries
      payload.dig("data", "data") || []
    end

    def payload
      JSON.parse(http_response.body)
    end

    def http_response
      Net::HTTP.start(
        ENDPOINT_URI.host,
        ENDPOINT_URI.port,
        use_ssl: true,
        open_timeout: OPEN_TIMEOUT_SECONDS,
        read_timeout: READ_TIMEOUT_SECONDS
      ) do |http|
        request = Net::HTTP::Get.new(ENDPOINT_URI)
        HEADERS.each { |header, value| request[header] = value }
        http.request(request)
      end
    end

    def normalized_listing(entry)
      longitude, latitude = entry.dig("location", "coordinates")
      neighborhood = entry["geoLabel"].presence || "Pocitos"

      {
        external_id: entry.fetch("id").to_s,
        title: entry["title"],
        canonical_url: canonical_url(entry),
        price_cents: normalize_price(entry["price"]),
        currency: entry.dig("currency", "value"),
        location_text: [neighborhood, "Montevideo"].compact_blank.join(", "),
        source_neighborhood: neighborhood,
        source_city: "Montevideo",
        operation_type: operation_type(entry.dig("operation", "value")),
        bedrooms: integer_or_nil(entry["bedrooms"]),
        square_meters: integer_or_nil(entry["dimensionCovered"]),
        latitude: latitude,
        longitude: longitude
      }
    end

    def canonical_url(entry)
      slug = entry["slug"].presence || entry["id"].to_s
      "#{FRONTEND_BASE_URL}/listings/#{slug}/#{entry.fetch("id")}"
    end

    def operation_type(value)
      value == "rent" ? "alquiler" : value
    end

    def normalize_price(value)
      return if value.blank?

      value.to_i * 100
    end

    def integer_or_nil(value)
      return if value.blank?

      value.to_i
    end
  end
end
