# MercadoLibre Source Implementation Plan

**For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) superpowers:executing-plans implement plan task-by-task. Steps use checkbox (`- [ ]`) syntax tracking.

**Goal:** Add MercadoLibre Uruguay as a second real source while preserving the existing adapter/intake pipeline.

**Architecture:** Create `Sources::MercadoLibreApiAdapter` that fetches a bounded MercadoLibre index response and returns normalized hashes accepted by `Scraping::ListingIntake`. Keep dedup source-local and make currency handling explicit so USD and UYU prices are not compared blindly.

**Tech Stack:** Rails 8, Minitest, WebMock-style HTTP stubs through existing test helpers, `Net::HTTP`, PostgreSQL/PostGIS.

---

### Task 1: Capture MercadoLibre Index Payload Shape

**Files:**
- Create: `test/fixtures/files/mercado_libre/search_apartments_montevideo.json`
- Modify: `docs/superpowers/plans/2026-07-12-mercado-libre-source.md`

**Payload Probe Result (2026-07-12):**
The bounded public API probe returned `{"message":"forbidden","error":"forbidden","status":403,"cause":[]}` from `https://api.mercadolibre.com/sites/MLU/search?q=apartamento%20alquiler%20montevideo&limit=2`. Browser-like headers did not change the API response, and the public website path asked for a MercadoLibre login. Do not implement normalization against guessed fields; obtain an allowed index payload sample or authenticated API path first.

- [ ] **Step 1: Run a bounded public API probe**

Run:

```bash
rtk proxy curl -s -L -H 'accept: application/json' -H 'user-agent: Mozilla/5.0' 'https://api.mercadolibre.com/sites/MLU/search?q=apartamento%20alquiler%20montevideo&limit=2'
```

Expected: either a JSON search response with a top-level `results` array, or a provider block response such as `{"message":"forbidden","error":"forbidden","status":403,"cause":[]}`.

- [ ] **Step 2: If the provider returns a real index payload, save a minimal fixture**

Create `test/fixtures/files/mercado_libre/search_apartments_montevideo.json` containing the top-level paging fields and two representative `results` entries. Keep only fields needed to test normalization: id, title, permalink, price, currency id, location/address attributes, category/listing type attributes, bedrooms/surface attributes, and coordinates if present.

- [ ] **Step 3: If the provider returns 403 or login gating, stop adapter implementation**

Record the response in this plan under a short "Payload Probe Result" note and do not implement a scraper workaround. Ask the human whether to provide an allowed payload sample, use authenticated API credentials, or defer MercadoLibre.

### Task 2: Add Adapter Normalization Tests

**Files:**
- Create: `test/services/sources/mercado_libre_api_adapter_test.rb`
- Read: `test/services/sources/info_casas_api_adapter_test.rb`

- [ ] **Step 1: Write failing normalization test**

Create a test that stubs `Net::HTTP.start` and returns the MercadoLibre fixture body:

```ruby
require "test_helper"
require "net/http"

class Sources::MercadoLibreApiAdapterTest < ActiveSupport::TestCase
  test "fetch_listings normalizes mercado libre search results into listing intake attributes" do
    adapter = Sources::MercadoLibreApiAdapter.new(page_throttle_seconds: 0)
    response = Struct.new(:body, :code).new(file_fixture("mercado_libre/search_apartments_montevideo.json").read, "200")

    stub_net_http_start(->(*, **, &block) { block.call(http_with_response(response)) }) do
      listing = adapter.fetch_listings.first

      assert_equal "MLU123", listing[:external_id]
      assert_equal "Apartamento en alquiler en Pocitos", listing[:title]
      assert_equal "https://apartamento.example.test/MLU123", listing[:canonical_url]
      assert_equal 35_000_00, listing[:price_cents]
      assert_equal "UYU", listing[:currency]
      assert_equal "Pocitos, Montevideo", listing[:location_text]
      assert_equal "Pocitos", listing[:source_neighborhood]
      assert_equal "Montevideo", listing[:source_city]
      assert_equal "alquiler", listing[:operation_type]
      assert_equal 2, listing[:bedrooms]
      assert_equal 58, listing[:square_meters]
    end
  end

  private

  def http_with_response(response)
    Object.new.tap do |http|
      http.define_singleton_method(:request) { |_| response }
    end
  end
end
```

Adjust expected keys only to match the captured fixture, not assumptions from InfoCasas.

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```bash
rtk rbenv exec ruby bin/rails test test/services/sources/mercado_libre_api_adapter_test.rb
```

Expected: FAIL with `uninitialized constant Sources::MercadoLibreApiAdapter`.

### Task 3: Implement MercadoLibre Adapter

**Files:**
- Create: `app/services/sources/mercado_libre_api_adapter.rb`

- [ ] **Step 1: Add minimal adapter class**

Implement:

```ruby
require "json"
require "net/http"
require "uri"

module Sources
  class MercadoLibreApiAdapter
    ENDPOINT_URI = URI("https://api.mercadolibre.com/sites/MLU/search")
    OPEN_TIMEOUT_SECONDS = 5
    READ_TIMEOUT_SECONDS = 15
    RESULTS_PER_PAGE = 50
    DEFAULT_PAGE_THROTTLE_SECONDS = 1.0
    MAX_PAGES = 10

    class UnexpectedResponseError < StandardError; end

    def initialize(page_throttle_seconds: DEFAULT_PAGE_THROTTLE_SECONDS)
      @page_throttle_seconds = page_throttle_seconds
    end

    def fetch_listings
      listings = []

      1.upto(MAX_PAGES) do |page|
        payload = payload(page)
        results = Array(payload[:results])
        listings.concat(results.map { |entry| normalized_listing(entry) })
        break if results.size < RESULTS_PER_PAGE

        sleep @page_throttle_seconds if @page_throttle_seconds.positive?
      end

      listings
    end

    private

    def payload(page)
      response = http_response(page)
      raise UnexpectedResponseError, "MercadoLibre returned HTTP #{response.code}" unless response.code.to_i == 200

      JSON.parse(response.body, symbolize_names: true)
    end

    def http_response(page)
      uri = ENDPOINT_URI.dup
      uri.query = URI.encode_www_form(
        q: "apartamento alquiler montevideo",
        limit: RESULTS_PER_PAGE,
        offset: (page - 1) * RESULTS_PER_PAGE
      )

      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: true,
        open_timeout: OPEN_TIMEOUT_SECONDS,
        read_timeout: READ_TIMEOUT_SECONDS
      ) do |http|
        request = Net::HTTP::Get.new(uri)
        request["accept"] = "application/json"
        request["user-agent"] = "RentalScoutLite/1.0"
        http.request(request)
      end
    end

    def normalized_listing(entry)
      {
        external_id: entry[:id].to_s,
        title: entry[:title],
        canonical_url: entry[:permalink],
        description: nil,
        price_cents: normalize_price(entry[:price]),
        currency: entry[:currency_id],
        location_text: location_text(entry),
        source_neighborhood: neighborhood(entry),
        source_city: city(entry),
        operation_type: operation_type(entry),
        bedrooms: attribute_integer(entry, "BEDROOMS"),
        square_meters: attribute_integer(entry, "COVERED_AREA") || attribute_integer(entry, "TOTAL_AREA"),
        latitude: latitude(entry),
        longitude: longitude(entry)
      }
    end

    def normalize_price(price)
      return if price.blank?

      BigDecimal(price.to_s).mult(100).to_i
    end

    def location_text(entry)
      [neighborhood(entry), city(entry)].compact_blank.join(", ").presence
    end

    def neighborhood(entry)
      entry.dig(:location, :neighborhood, :name).presence ||
        entry.dig(:address, :neighborhood_name).presence
    end

    def city(entry)
      entry.dig(:location, :city, :name).presence ||
        entry.dig(:address, :city_name).presence
    end

    def operation_type(entry)
      text = [entry[:title], entry[:permalink], entry[:listing_type_id], entry[:category_id]].compact.join(" ").downcase
      return "alquiler" if text.include?("alquiler") || text.include?("rent")
    end

    def attribute_integer(entry, id)
      attribute = Array(entry[:attributes]).find { |attrs| attrs[:id].to_s == id }
      value = attribute&.dig(:value_struct, :number) || attribute&.dig(:value_name)
      return if value.blank?

      value.to_i
    end

    def latitude(entry)
      entry.dig(:location, :latitude) || entry.dig(:geolocation, :latitude)
    end

    def longitude(entry)
      entry.dig(:location, :longitude) || entry.dig(:geolocation, :longitude)
    end
  end
end
```

Revise field readers against the captured fixture before making the test pass.

- [ ] **Step 2: Run the focused test**

Run:

```bash
rtk rbenv exec ruby bin/rails test test/services/sources/mercado_libre_api_adapter_test.rb
```

Expected: PASS.

### Task 4: Add Currency-Safe Feed Filtering

**Files:**
- Modify: `app/models/search_preference.rb`
- Modify: `app/models/listing.rb`
- Test: `test/models/listing_test.rb`

- [ ] **Step 1: Write failing mixed-currency feed test**

Add a test proving UYU saved-search budgets do not treat USD listings as UYU:

```ruby
test "for_search_feed applies price bounds only to UYU listings for now" do
  search = search_preferences(:pocitos)
  search.update!(min_price_cents: 20_000_00, max_price_cents: 40_000_00)

  source = listing_sources(:mock_source)
  uyu_listing = Listing.create!(
    listing_source: source,
    title: "UYU Pocitos",
    canonical_url: "https://example.test/uyu",
    price_cents: 35_000_00,
    currency: "UYU",
    location_text: "Pocitos, Montevideo",
    source_neighborhood: "Pocitos",
    source_city: "Montevideo",
    operation_type: "alquiler",
    in_scope: true
  )
  Listing.create!(
    listing_source: source,
    title: "USD Pocitos",
    canonical_url: "https://example.test/usd",
    price_cents: 1_000_00,
    currency: "USD",
    location_text: "Pocitos, Montevideo",
    source_neighborhood: "Pocitos",
    source_city: "Montevideo",
    operation_type: "alquiler",
    in_scope: true
  )

  assert_includes Listing.for_search_feed(search), uyu_listing
  assert_not_includes Listing.for_search_feed(search).map(&:title), "USD Pocitos"
end
```

- [ ] **Step 2: Implement minimal currency assumption**

Add to `SearchPreference`:

```ruby
def price_currency
  "UYU"
end
```

Update `Listing.for_search_feed` before price bounds:

```ruby
if search_preference.min_price_cents.present? || search_preference.max_price_cents.present?
  listings = listings.where(currency: search_preference.price_currency)
end
```

- [ ] **Step 3: Run model test**

Run:

```bash
rtk rbenv exec ruby bin/rails test test/models/listing_test.rb
```

Expected: PASS.

### Task 5: Add Source Seed

**Files:**
- Modify: `db/seeds.rb`
- Test: `test/config/bootstrap_config_test.rb`

- [ ] **Step 1: Add seed record**

Add:

```ruby
ListingSource.find_or_create_by!(adapter_key: "mercado_libre_api") do |source|
  source.name = "MercadoLibre API"
end
```

- [ ] **Step 2: Add or update seed assertion**

In `test/config/bootstrap_config_test.rb`, assert that seed content includes `mercado_libre_api` if that file already checks seed structure. If no seed assertion exists, add a narrow test that reads `db/seeds.rb` and checks for the adapter key.

- [ ] **Step 3: Run config test**

Run:

```bash
rtk rbenv exec ruby bin/rails test test/config/bootstrap_config_test.rb
```

Expected: PASS.

### Task 6: Document Dedup Decision and Update Status

**Files:**
- Modify: `.ai/STATUS.md`
- Create: `.ai/decisions/adr-mercado-libre-source.md`

- [ ] **Step 1: Add ADR**

Create an ADR stating:

```markdown
# ADR: MercadoLibre Source Boundary

## Status
Accepted (2026-07-12)

## Context
MercadoLibre is the second real source. Existing dedup is source-local, and currency conversion is not implemented.

## Decision
MercadoLibre enters through the standard source adapter pipeline. Currency is stored from provider payload without conversion. Search price bounds only apply to the assumed UYU budget currency. Cross-source dedup remains source-local for this ticket; fuzzy dedup is deferred.

## Consequences
The app can ingest a second real source without risky false currency comparisons or false duplicate merges. Duplicate cards across sources remain possible.
```

- [ ] **Step 2: Update `.ai/STATUS.md`**

Move current task from "Needs implementation plan before coding" to implementation status, and mention the MercadoLibre payload probe result.

### Task 7: Final Verification

**Files:**
- All changed files

- [ ] **Step 1: Run focused tests**

Run:

```bash
rtk rbenv exec ruby bin/rails test test/services/sources/mercado_libre_api_adapter_test.rb test/models/listing_test.rb test/config/bootstrap_config_test.rb
```

Expected: PASS.

- [ ] **Step 2: Run full suite**

Run:

```bash
rtk rbenv exec ruby bin/rails test
```

Expected: PASS.

- [ ] **Step 3: Review diff**

Run:

```bash
rtk git diff
```

Expected: only MercadoLibre ticket/spec/plan/adapter/tests, currency-safe filtering, seed, ADR, and status updates are changed.

- [ ] **Step 4: Commit**

Run:

```bash
rtk git add .ai/tickets/018-mercado-libre-source.md docs/superpowers/specs/2026-07-12-mercado-libre-source-design.md docs/superpowers/plans/2026-07-12-mercado-libre-source.md
rtk git commit -m "docs: plan mercado libre source"
```

After implementation:

```bash
rtk git add app test db .ai
rtk git commit -m "feat: add mercado libre source"
```
