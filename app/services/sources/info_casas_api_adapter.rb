require "json"
require "net/http"
require "uri"

module Sources
  class InfoCasasApiAdapter
    ENDPOINT_URI = URI("https://graph.infocasas.com.uy/graphql")
    FRONTEND_BASE_URL = "https://www.infocasas.com.uy"
    OPEN_TIMEOUT_SECONDS = 5
    READ_TIMEOUT_SECONDS = 15
    RESULTS_PER_PAGE = 50
    LAST_HOUR_PUBLICATION_DATE = 1
    MAX_PAGES = 40
    DEFAULT_PAGE_THROTTLE_SECONDS = 1.0
    DEFAULT_DETAIL_THROTTLE_SECONDS = 0.5
    EXPLICIT_TITLE_NEIGHBORHOODS = {
      "buce0" => "Buceo",
      "villa del cerro" => "Cerro"
    }.freeze
    PRICE_CURRENCIES = {
      "$" => "UYU",
      "UY$" => "UYU",
      "UYU" => "UYU",
      "U$S" => "USD",
      "US$" => "USD",
      "USD" => "USD"
    }.freeze

    class UnexpectedResponseError < StandardError; end
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

    def initialize(page_throttle_seconds: DEFAULT_PAGE_THROTTLE_SECONDS, detail_throttle_seconds: DEFAULT_DETAIL_THROTTLE_SECONDS)
      @page_throttle_seconds = page_throttle_seconds
      @detail_throttle_seconds = detail_throttle_seconds
    end

    def fetch_listings
      page = 1
      listings = []

      loop do
        entries = payload(page).dig(0, :data, :searchFast, :data)
        raise UnexpectedResponseError, "missing searchFast data on page #{page}" unless entries.is_a?(Array)

        listings.concat(entries.map { |entry| normalized_listing(entry) })
        break if entries.size < RESULTS_PER_PAGE || page >= MAX_PAGES

        page += 1
        sleep(@page_throttle_seconds) if @page_throttle_seconds.positive?
      end

      listings
    end

    def detail_coordinates_for_url(canonical_url)
      sleep(@detail_throttle_seconds) if @detail_throttle_seconds.positive?
      detail_coordinates_from_html(detail_response(canonical_url).body)
    rescue StandardError => error
      Rails.logger.warn("[InfoCasasApiAdapter] detail coordinate fetch failed #{canonical_url}: #{error.class}: #{error.message}")
      {}
    end

    private

    def normalized_listing(entry)
      location_name = location_text(entry)
      title_neighborhood = explicit_title_neighborhood(entry[:title])
      neighborhood = title_neighborhood || entry[:neighborhood].presence || location_name
      location_name = [neighborhood, entry[:estate]].compact_blank.join(", ") if title_neighborhood

      {
        external_id: entry[:id].to_s,
        title: entry[:title],
        canonical_url: URI.join(FRONTEND_BASE_URL, entry[:link]).to_s,
        description: entry[:description],
        price_cents: normalize_price(entry[:price]),
        currency: normalize_currency(entry[:currency]),
        expenses_cents: normalize_price(entry[:commonExpenses]),
        expenses_currency: "UYU",
        location_text: location_name,
        source_neighborhood: neighborhood,
        source_city: entry[:estate].presence || source_city(location_name),
        operation_type: operation_type_from_id(entry[:operation_type_id]) || operation_type(entry[:link]),
        bedrooms: integer_or_nil(entry[:bedrooms]),
        square_meters: integer_or_nil(entry[:area] || entry[:m2]),
        latitude: entry[:lat] || entry.dig(:location, :lat),
        longitude: entry[:lng] || entry.dig(:location, :lng)
      }
    end

    def payload(page)
      JSON.parse(http_response(page).body, symbolize_names: true)
    end

    def http_response(page)
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
        request.body = request_body(page:)
        http.request(request)
      end
    end

    def detail_response(canonical_url)
      uri = URI(canonical_url)
      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: OPEN_TIMEOUT_SECONDS,
        read_timeout: READ_TIMEOUT_SECONDS
      ) do |http|
        request = Net::HTTP::Get.new(uri)
        request["accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
        request["user-agent"] = LEGACY_HEADERS[:"ic-user-agent"]
        http.request(request)
      end
    end

    def detail_coordinates_from_html(html)
      json_ld_scripts(html).each do |script|
        parsed = JSON.parse(script, symbolize_names: true)
        geo = parsed.dig(:object, :geo)
        next unless geo

        latitude = geo[:latitude] || geo["latitude"]
        longitude = geo[:longitude] || geo["longitude"]
        return { latitude: latitude, longitude: longitude } if latitude && longitude
      rescue JSON::ParserError
        next
      end

      {}
    end

    def json_ld_scripts(html)
      html.scan(/<script[^>]+type="application\/ld\+json"[^>]*>(.*?)<\/script>/m).flatten
    end

    def request_body(page: 1)
      JSON.generate([
        {
          operationName: "ResultsGird_v2",
          variables: {
            rows: RESULTS_PER_PAGE,
            params: legacy_search_params(page:),
            page: page,
            source: 0
          },
          query: RESULTS_GRID_QUERY
        },
        {
          operationName: "searchUrl",
          variables: {
            params: legacy_search_params(page:)
          },
          query: SEARCH_URL_QUERY
        }
      ])
    end

    def legacy_search_params(page: 1)
      {
        page: page,
        order: 2,
        operation_type_id: 2,
        property_type_id: [1, 2],
        currencyID: nil,
        m2Currency: 2,
        mapView: false,
        estate_id: 10,
        neighborhood_id: [],
        bedrooms: nil,
        publicationDate: LAST_HOUR_PUBLICATION_DATE,
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

    def normalize_currency(currency)
      PRICE_CURRENCIES[currency.to_s.strip.upcase]
    end

    def integer_or_nil(value)
      return if value.blank?

      value.to_i
    end

    def location_text(entry)
      entry.dig(:location, :name).presence ||
        [entry[:neighborhood], entry[:estate]].compact_blank.join(", ").presence
    end

    def source_city(location_name)
      return if location_name.blank? || !location_name.include?(",")

      location_name.split(",").last.strip.presence
    end

    def explicit_title_neighborhood(title)
      normalized_title = ActiveSupport::Inflector.transliterate(title.to_s).downcase

      EXPLICIT_TITLE_NEIGHBORHOODS.find do |phrase, _neighborhood|
        normalized_title.match?(/\b#{Regexp.escape(phrase)}\b/)
      end&.last
    end

    def operation_type_from_id(operation_type_id)
      return "alquiler" if operation_type_id.to_i == 2
    end

    def operation_type(link)
      link.to_s.split("/").reject(&:blank?).first.presence
    end
  end
end
