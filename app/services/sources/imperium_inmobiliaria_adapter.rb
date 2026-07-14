require "json"
require "net/http"
require "nokogiri"
require "uri"

module Sources
  class ImperiumInmobiliariaAdapter
    ENDPOINT_URI = URI("https://imperium-backend-production-9783.up.railway.app/api/v2/public/properties")
    FRONTEND_BASE_URL = "https://www.inmobiliariaimperium.com"
    OPEN_TIMEOUT_SECONDS = 5
    READ_TIMEOUT_SECONDS = 15
    RECENT_PAGE_LIMIT = 3
    RECONCILIATION_PAGE_LIMIT = 20
    PROPERTY_TYPES = {
      "apartment" => "Apartamento",
      "house" => "Casa"
    }.freeze

    QUERY = { limit: 12, operation: "rent" }.freeze

    HEADERS = {
      "accept" => "application/json, text/plain, */*",
      "user-agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36"
    }.freeze

    def fetch_listings(known_external_ids: Set.new, reconciliation: false)
      listings = []
      page_signatures = Set.new
      page_limit = reconciliation ? RECONCILIATION_PAGE_LIMIT : RECENT_PAGE_LIMIT

      page_limit.times do |page|
        page_properties = properties(page:)
        break if page_properties.empty?

        page_ids = page_properties.filter_map { |property| property["propertyId"]&.to_s }
        signature = page_ids.sort
        break if page_signatures.include?(signature)

        page_signatures << signature
        listings.concat(page_properties.filter_map do |property|
          normalized_listing(property)
        rescue KeyError, TypeError
          nil
        end)
        break if !reconciliation && page_ids.intersect?(known_external_ids.to_a)
      end

      listings
    rescue JSON::ParserError
      []
    end

    private

    def properties(page:)
      payload(page:)["data"] || []
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
        http.request(request)
      end
    end

    def request_uri(page:)
      uri = ENDPOINT_URI.dup
      uri.query = URI.encode_www_form(QUERY.merge(page: page + 1))
      uri
    end

    def normalized_listing(property)
      return unless residential?(property)
      features = property["features"] || {}
      pricing = property["pricing"] || {}
      location = property["location"] || {}
      return if integer_or_nil(features["bedrooms"]).to_i.zero?

      {
        external_id: property.fetch("propertyId").to_s,
        title: property["title"],
        canonical_url: "#{FRONTEND_BASE_URL}/propiedades/#{property.fetch("propertyId")}",
        description: plain_description(property["description"]),
        price_cents: normalize_price(pricing["rentPrice"]),
        currency: pricing["currency"],
        location_text: location["address"].presence || [location["city"], location["state"]].compact_blank.uniq.join(", "),
        source_neighborhood: neighborhood(location),
        source_city: location["state"].presence || location["city"].presence,
        operation_type: "alquiler",
        bedrooms: integer_or_nil(features["bedrooms"]),
        square_meters: integer_or_nil(features["totalArea"] || features["coveredArea"]),
        expenses_cents: normalize_price(pricing["monthlyExpenses"]),
        expenses_currency: pricing["monthlyExpenses"].present? ? pricing["expensesCurrency"] : nil,
        parking_spaces: integer_or_nil(features["garages"]),
        property_type: PROPERTY_TYPES.fetch(property["type"].to_s.downcase)
      }
    end

    def residential?(property)
      PROPERTY_TYPES.key?(property["type"].to_s.downcase)
    end

    def neighborhood(location)
      city = location["city"].presence
      state = location["state"].presence
      city unless city&.casecmp?(state.to_s)
    end

    def plain_description(html)
      return if html.blank?

      Nokogiri::HTML(html).text.squish
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
