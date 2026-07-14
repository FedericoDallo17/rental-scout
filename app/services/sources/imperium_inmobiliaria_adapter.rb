require "json"
require "net/http"
require "nokogiri"
require "uri"

module Sources
  class ImperiumInmobiliariaAdapter
    ENDPOINT_URI = URI("https://imperium-prod.herokuapp.com/api/listing-properties")
    FRONTEND_BASE_URL = "https://www.inmobiliariaimperium.com"
    OPEN_TIMEOUT_SECONDS = 5
    READ_TIMEOUT_SECONDS = 15
    RECENT_PAGE_LIMIT = 3
    RECONCILIATION_PAGE_LIMIT = 20

    QUERY = {
      currentPage: 0,
      bathrooms: "Todos",
      bedrooms: "Todos",
      state: "Montevideo",
      type: "Todos",
      operation: "Alquiler",
      region: "Todos",
      range: "$20.000 a $55.000",
      parking_lots: "Todos",
      has_patio: "Todos",
      has_balcony: "Todos",
      has_kitchen: "Todos"
    }.freeze

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

        page_ids = page_properties.filter_map { |property| property["id"]&.to_s }
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
      rows = payload(page:).dig("response", "result") || []
      rows.filter_map { |row| row["property"] }
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
      uri.query = URI.encode_www_form(QUERY.merge(currentPage: page))
      uri
    end

    def normalized_listing(property)
      return unless residential?(property)
      return if integer_or_nil(property["bedrooms"]).to_i.zero?

      {
        external_id: property.fetch("id").to_s,
        title: property["title"],
        canonical_url: "#{FRONTEND_BASE_URL}/propiedad/#{property.fetch("id")}",
        description: plain_description(property["description"]),
        price_cents: normalize_price(property["price"]),
        currency: property["currency"],
        location_text: property["street"].presence || [property["city"], "Montevideo"].compact_blank.join(", "),
        source_neighborhood: property["city"].presence,
        source_city: "Montevideo",
        operation_type: "alquiler",
        bedrooms: integer_or_nil(property["bedrooms"]),
        square_meters: integer_or_nil(property["area"]),
        expenses_cents: nil,
        expenses_currency: nil,
        parking_spaces: integer_or_nil(property["parking"]),
        property_type: property["typeProperty"]
      }
    end

    def residential?(property)
      property["typeProperty"].to_s.downcase.in?(["apartamento", "casa"])
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
