require "test_helper"
require "net/http"

class Sources::HousiAdapterTest < ActiveSupport::TestCase
  test "fetch_listings normalizes Housi search HTML into intake attributes" do
    adapter = Sources::HousiAdapter.new

    stub_net_http_start(response_body: housi_html) do
      listings = adapter.fetch_listings

      assert_equal 2, listings.size

      assert_equal(
        {
          external_id: "8148664",
          title: "Alquiler Apartamento monoambiente amoblado con vista al mar en Pocitos.",
          canonical_url: "https://www.housi.com.uy/p/8148664-Apartamento-en-Alquiler-en-Pocitos-Rambla-Gandhi--al-500",
          price_cents: 3_200_000,
          currency: "UYU",
          location_text: "Rambla Gandhi al 500, Pocitos, Montevideo",
          source_neighborhood: "Pocitos",
          source_city: "Montevideo",
          operation_type: "alquiler",
          bedrooms: 0,
          square_meters: 36
        },
        listings.first.slice(:external_id, :title, :canonical_url, :price_cents, :currency, :location_text, :source_neighborhood, :source_city, :operation_type, :bedrooms, :square_meters)
      )

      assert_equal "USD", listings.second[:currency]
      assert_equal 160_000, listings.second[:price_cents]
      assert_equal 2, listings.second[:bedrooms]
    end
  end

  test "fetch_listings escapes non ascii Housi URLs" do
    adapter = Sources::HousiAdapter.new

    stub_net_http_start(response_body: housi_html_with_non_ascii_url) do
      listing = adapter.fetch_listings.first

      assert_equal "8055496", listing[:external_id]
      assert_equal "https://www.housi.com.uy/p/8055496-Apartamento-en-Alquiler-en-Pocitos-Roque-Graseras-y-Bulevar-Espa%C3%B1a", listing[:canonical_url]
    end
  end

  test "fetch_listings uses explicit HTTP timeouts for Housi request" do
    adapter = Sources::HousiAdapter.new
    seen_request = false

    request_assertion = lambda do |host, port, options, request|
      assert_equal "www.housi.com.uy", host
      assert_equal 443, port
      assert_equal true, options[:use_ssl]
      assert options.key?(:open_timeout)
      assert options.key?(:read_timeout)
      assert_instance_of Net::HTTP::Get, request
      seen_request = true
    end

    stub_net_http_start(response_body: housi_html, request_assertion:) do
      adapter.fetch_listings
    end

    assert_equal true, seen_request
  end

  test "fetch_listings returns empty list when no Housi cards are present" do
    adapter = Sources::HousiAdapter.new

    stub_net_http_start(response_body: "<html><body><div id=\"propiedades\"></div></body></html>") do
      assert_equal [], adapter.fetch_listings
    end
  end

  private

  def housi_html
    <<~HTML
      <html>
        <body>
          <div id="propiedades">
            <div class="col-md-6 col-lg-6" prop-id="8148664">
              <a class="item" href="/p/8148664-Apartamento-en-Alquiler-en-Pocitos-Rambla-Gandhi--al-500">
                <span class="fp_price"><p>$32.000</p></span>
                <div class="details">
                  <div class="type_and_code">
                    <p class="prop-card-red-text">Apartamento</p>
                    <p>BAP8148664</p>
                  </div>
                  <h4>Alquiler Apartamento monoambiente amoblado con vista al mar en Pocitos.</h4>
                  <p class="card-address">Rambla Gandhi  al 500</p>
                  <ul>
                    <li>Alquiler</li>
                    <li>Área total construida: 36 m²</li>
                    <li>Ambientes: 1</li>
                  </ul>
                </div>
              </a>
            </div>
            <div class="col-md-6 col-lg-6" prop-id="8058423">
              <a class="item" href="/p/8058423-Apartamento-en-Alquiler-en-Pocitos-C.-Luis-C.-Bollo--al-2900">
                <span class="fp_price"><p>USD1.600</p></span>
                <div class="details">
                  <p class="prop-card-red-text">Apartamento</p>
                  <h4>Alquiler Apartamento 2 dormitorios amoblado y con vista al mar, piso alto en hermosa zona de Pocitos</h4>
                  <p class="card-address">C. Luis C. Bollo al 2900</p>
                  <ul><li>Alquiler</li><li>Área total construida: 76 m²</li></ul>
                </div>
              </a>
            </div>
          </div>
        </body>
      </html>
    HTML
  end

  def housi_html_with_non_ascii_url
    <<~HTML
      <html>
        <body>
          <div id="propiedades">
            <div prop-id="8055496">
              <a class="item" href="/p/8055496-Apartamento-en-Alquiler-en-Pocitos-Roque-Graseras-y-Bulevar-España">
                <span class="fp_price"><p>$45.000</p></span>
                <h4>Alquiler Apartamento 2 dormitorios al frente con balcón y garaje en Pocitos</h4>
                <p class="card-address">Roque Graseras y Bulevar España</p>
                <ul><li>Alquiler</li><li>Área total construida: 72 m²</li></ul>
              </a>
            </div>
          </div>
        </body>
      </html>
    HTML
  end

  def stub_net_http_start(response_body:, request_assertion: nil)
    original_start = Net::HTTP.method(:start)
    response = Struct.new(:body).new(response_body)
    http = Object.new
    http.define_singleton_method(:request) do |request|
      yield_args = Thread.current[:net_http_start_args]
      request_assertion&.call(*yield_args, request) if yield_args
      response
    end

    Net::HTTP.define_singleton_method(:start) do |host, port, **options, &block|
      Thread.current[:net_http_start_args] = [host, port, options]
      block.call(http)
    ensure
      Thread.current[:net_http_start_args] = nil
    end

    yield
  ensure
    Net::HTTP.define_singleton_method(:start) do |*args, **kwargs, &block|
      original_start.call(*args, **kwargs, &block)
    end
  end
end
