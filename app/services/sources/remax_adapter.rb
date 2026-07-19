require "json"
require "net/http"
require "uri"

module Sources
  class RemaxAdapter
    attr_writer :on_request

    ENDPOINT_URI = URI("https://api-ar.redremax.com/remaxweb-uy/api/listings/findAllWithEntrepreneurships?page=0&pageSize=50&sort=-createdAt&in=operationId:2&in=typeId:1,2,3,4,5,6,7,8&pricein=3:0:65000&gte=dimensionCovered:30&landingPath=")
    FRONTEND_BASE_URL = "https://www.remax.com.uy"
    OPEN_TIMEOUT_SECONDS = 5
    READ_TIMEOUT_SECONDS = 15
    RECENT_PAGE_LIMIT = 3
    RECONCILIATION_PAGE_LIMIT = 20

    HEADERS = {
      "accept" => "application/json, text/plain, */*",
      "user-agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36"
    }.freeze

    def initialize(on_request: nil)
      @on_request = on_request
    end

    def fetch_listings(known_external_ids: Set.new, reconciliation: false)
      listings = []
      page_signatures = Set.new
      page_limit = reconciliation ? RECONCILIATION_PAGE_LIMIT : RECENT_PAGE_LIMIT

      page_limit.times do |page|
        page_entries = entries(page:)
        break if page_entries.empty?

        page_ids = page_entries.filter_map { |entry| entry["id"]&.to_s }
        signature = page_ids.sort
        break if page_signatures.include?(signature)

        page_signatures << signature
        listings.concat(page_entries.filter_map { |entry| normalized_listing(entry) })
        break if !reconciliation && page_ids.intersect?(known_external_ids.to_a)
      end

      listings
    rescue JSON::ParserError, KeyError, TypeError
      []
    end

    private

    def entries(page:)
      payload(page:).dig("data", "data") || []
    end

    def payload(page:)
      JSON.parse(http_response(page:).body)
    end

    def http_response(page:)
      uri = request_uri(page:)
      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: true,
        open_timeout: OPEN_TIMEOUT_SECONDS,
        read_timeout: READ_TIMEOUT_SECONDS
      ) do |http|
        request = Net::HTTP::Get.new(uri)
        HEADERS.each { |header, value| request[header] = value }
        @on_request&.call
        http.request(request)
      end
    end

    def request_uri(page:)
      uri = ENDPOINT_URI.dup
      pairs = URI.decode_www_form(uri.query)
      pairs.map! { |key, value| key == "page" ? [key, page.to_s] : [key, value] }
      uri.query = URI.encode_www_form(pairs)
      uri
    end

    def normalized_listing(entry)
      longitude, latitude = entry.dig("location", "coordinates")
      label = entry["geoLabel"].presence
      return unless label

      location_parts = label.split(",").map(&:strip).reject(&:blank?)
      return if location_parts.size < 2

      neighborhood = location_parts.first
      city = location_parts.last

      {
        external_id: entry.fetch("id").to_s,
        title: entry["title"],
        canonical_url: canonical_url(entry),
        price_cents: normalize_price(entry["price"]),
        currency: entry.dig("currency", "value"),
        location_text: [neighborhood, city].uniq.join(", "),
        source_neighborhood: neighborhood,
        source_city: city,
        operation_type: operation_type(entry.dig("operation", "value")),
        bedrooms: integer_or_nil(entry["bedrooms"]),
        square_meters: integer_or_nil(entry["dimensionCovered"]),
        expenses_cents: normalize_price(entry["expensesPrice"]),
        expenses_currency: entry.dig("expensesCurrency", "value"),
        parking_spaces: nil,
        property_type: entry.dig("type", "value"),
        latitude: latitude,
        longitude: longitude
      }
    end

    def canonical_url(entry)
      slug = entry["slug"].presence || entry["id"].to_s
      "#{FRONTEND_BASE_URL}/listings/#{slug}"
    end

    def location_text(label)
      return label if label.to_s.downcase.include?("montevideo")

      [label, "Montevideo"].compact_blank.join(", ")
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
