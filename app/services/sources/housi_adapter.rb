require "net/http"
require "nokogiri"
require "uri"

module Sources
  class HousiAdapter
    SEARCH_URI = URI("https://www.housi.com.uy/Buscar?operation=2&ptypes=2&locations=51731&min-roofed=30&min-price=&max-price=65000&currency=UYU&o=2,2&1=1")
    FRONTEND_BASE_URL = "https://www.housi.com.uy"
    OPEN_TIMEOUT_SECONDS = 5
    READ_TIMEOUT_SECONDS = 15

    HEADERS = {
      "accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      "user-agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36"
    }.freeze

    def fetch_listings
      cards.map { |card| normalized_listing(card) }.compact
    end

    private

    def cards
      Nokogiri::HTML(http_response.body).css("#propiedades [prop-id]")
    end

    def http_response
      Net::HTTP.start(
        SEARCH_URI.host,
        SEARCH_URI.port,
        use_ssl: true,
        open_timeout: OPEN_TIMEOUT_SECONDS,
        read_timeout: READ_TIMEOUT_SECONDS
      ) do |http|
        request = Net::HTTP::Get.new(SEARCH_URI)
        HEADERS.each { |header, value| request[header] = value }
        http.request(request)
      end
    end

    def normalized_listing(card)
      href = card.at_css("a.item")&.[]("href")
      return if href.blank?

      title = text_at(card, "h4")
      address = normalized_text(text_at(card, ".card-address"))
      price = text_at(card, ".fp_price")

      {
        external_id: card["prop-id"].to_s,
        title: title,
        canonical_url: URI.join(FRONTEND_BASE_URL, escaped_href(href)).to_s,
        price_cents: price_cents(price),
        currency: currency(price),
        location_text: [address, "Pocitos", "Montevideo"].compact_blank.join(", "),
        source_neighborhood: "Pocitos",
        source_city: "Montevideo",
        operation_type: "alquiler",
        bedrooms: bedrooms(title),
        square_meters: square_meters(card),
        expenses_cents: nil,
        expenses_currency: nil,
        parking_spaces: nil,
        property_type: text_at(card, ".prop-card-red-text")
      }
    end

    def text_at(node, selector)
      node.at_css(selector)&.text&.strip
    end

    def escaped_href(href)
      URI::DEFAULT_PARSER.escape(href)
    end

    def normalized_text(text)
      text.to_s.gsub(/\s+/, " ").strip.presence
    end

    def currency(price_text)
      price_text.to_s.match?(/USD|U\$S/i) ? "USD" : "UYU"
    end

    def price_cents(price_text)
      digits = price_text.to_s.gsub(/\D/, "")
      return if digits.blank?

      digits.to_i * 100
    end

    def bedrooms(title)
      return 0 if title.to_s.match?(/monoambiente/i)

      match = title.to_s.match(/(\d+)\s*dormitorios?/i)
      return unless match

      match[1].to_i
    end

    def square_meters(card)
      text = card.css("li").map(&:text).join(" ")
      match = text.match(/Área total construida:\s*(\d+)\s*m/i)
      return unless match

      match[1].to_i
    end
  end
end
