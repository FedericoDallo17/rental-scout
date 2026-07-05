# Actual Scrapers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the working InfoCasas API scraper into Rental Scout Lite so an `info_casas_api` source can ingest real listings through the existing scraper pipeline.

**Architecture:** Keep the current `RunScrapersJob` → `Scraping::RunOrchestrator` → `Sources::AdapterRegistry` → `Scraping::ListingIntake` flow unchanged. Add a single `Sources::InfoCasasApiAdapter` that performs the remote request, parses the legacy payload shape, and returns normalized listing hashes for intake.

**Tech Stack:** Rails 8, Ruby, Minitest, Active Job, Active Record, JSON, Net::HTTP

## Global Constraints

- Keep the existing orchestration and intake flow unchanged.
- Port only one real source in this ticket: InfoCasas API.
- Do not build a reusable HTTP/API scraper framework yet.
- Follow TDD: no production code without a failing test first.
- Automated tests must not hit the live network; stub the remote response with a representative legacy-shaped payload.
- Prefer successful basic ingest over exhaustive field normalization.

---

## File structure

- Create: `app/services/sources/info_casas_api_adapter.rb` — new real-source adapter that performs the request and returns normalized listing hashes.
- Create: `test/services/sources/info_casas_api_adapter_test.rb` — unit coverage for adapter request parsing and normalization.
- Create: `test/services/sources/adapter_registry_test.rb` — regression coverage that `info_casas_api` resolves through the existing registry contract.
- Modify: `test/jobs/run_scrapers_job_test.rb` — end-to-end ingest coverage proving the orchestrator can persist InfoCasas listings through the current pipeline.

No schema, job, orchestrator, or intake changes are planned unless a failing test proves one is necessary.

### Task 1: Add adapter registry coverage and the minimal adapter class

**Files:**
- Create: `test/services/sources/adapter_registry_test.rb`
- Create: `app/services/sources/info_casas_api_adapter.rb`

**Interfaces:**
- Consumes: `ListingSource` with `adapter_key: "info_casas_api"`
- Produces: `Sources::InfoCasasApiAdapter.new.fetch_listings # => Array<Hash>`

- [ ] **Step 1: Write the failing registry test**

```ruby
require "test_helper"

class Sources::AdapterRegistryTest < ActiveSupport::TestCase
  test "resolves info_casas_api adapter from the adapter key" do
    source = ListingSource.new(name: "InfoCasas API", adapter_key: "info_casas_api")

    adapter = Sources::AdapterRegistry.resolve(source)

    assert_instance_of Sources::InfoCasasApiAdapter, adapter
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/rails test test/services/sources/adapter_registry_test.rb`

Expected: FAIL with `uninitialized constant Sources::InfoCasasApiAdapter`

- [ ] **Step 3: Write the minimal adapter class to satisfy registry resolution**

```ruby
module Sources
  class InfoCasasApiAdapter
    def fetch_listings
      []
    end
  end
end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bin/rails test test/services/sources/adapter_registry_test.rb`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add test/services/sources/adapter_registry_test.rb app/services/sources/info_casas_api_adapter.rb
git commit -m "test: cover info casas adapter registry resolution"
```

### Task 2: Implement InfoCasas API normalization in the adapter

**Files:**
- Modify: `app/services/sources/info_casas_api_adapter.rb`
- Create: `test/services/sources/info_casas_api_adapter_test.rb`

**Interfaces:**
- Consumes: `Sources::InfoCasasApiAdapter#fetch_listings`
- Produces: array entries shaped like:
  - `external_id: String`
  - `title: String`
  - `canonical_url: String`
  - `description: String | nil`
  - `price_cents: Integer | nil`
  - `currency: String`
  - `location_text: String | nil`
  - `bedrooms: Integer | nil`
  - `square_meters: Integer | nil`

- [ ] **Step 1: Write the failing adapter normalization test**

```ruby
require "test_helper"

class Sources::InfoCasasApiAdapterTest < ActiveSupport::TestCase
  test "fetch_listings normalizes the legacy info casas payload into listing intake attributes" do
    adapter = Sources::InfoCasasApiAdapter.new
    response = Struct.new(:body).new(sample_response_body)

    Net::HTTP.stub(:start, ->(*, **, &block) { block.call(FakeHttp.new(response)) }) do
      listings = adapter.fetch_listings

      assert_equal 1, listings.size
      assert_equal(
        {
          external_id: "123",
          title: "Apartamento en Pocitos",
          canonical_url: "https://www.infocasas.com.uy/alquiler/apartamento/pocitos/123",
          description: "Apartamento luminoso con terraza",
          price_cents: 3_500_000,
          currency: "UYU",
          location_text: "Pocitos, Montevideo",
          bedrooms: 2,
          square_meters: 58
        },
        listings.first.slice(
          :external_id,
          :title,
          :canonical_url,
          :description,
          :price_cents,
          :currency,
          :location_text,
          :bedrooms,
          :square_meters
        )
      )
    end
  end

  private

  FakeHttp = Struct.new(:response) do
    def request(_request)
      response
    end
  end

  def sample_response_body
    JSON.generate([
      {
        data: {
          searchFast: {
            data: [
              {
                id: "123",
                title: "Apartamento en Pocitos",
                description: "Apartamento luminoso con terraza",
                link: "/alquiler/apartamento/pocitos/123",
                price: 35000,
                commonExpenses: 4500,
                facilities: ["9"],
                location: { name: "Pocitos, Montevideo" },
                bedrooms: 2,
                area: 58
              }
            ]
          }
        }
      }
    ])
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/rails test test/services/sources/info_casas_api_adapter_test.rb`

Expected: FAIL because `fetch_listings` currently returns `[]`

- [ ] **Step 3: Replace the placeholder adapter with the minimal real implementation**

```ruby
require "json"
require "net/http"
require "uri"

module Sources
  class InfoCasasApiAdapter
    ENDPOINT_URI = URI("https://graph.infocasas.com.uy/graphql")
    FRONTEND_BASE_URL = "https://www.infocasas.com.uy"

    def fetch_listings
      payload.dig(0, :data, :searchFast, :data).to_a.map do |entry|
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
```

Implementation notes:

- Keep the request body intentionally small at first; preserve only the fields needed for basic ingest.
- If the live payload later requires more exact variables from `../home_scraper`, expand in a follow-up once automated ingest is green.
- Let malformed responses raise naturally; `RunOrchestrator` already records source failures.

- [ ] **Step 4: Run the focused adapter test to verify it passes**

Run: `bin/rails test test/services/sources/info_casas_api_adapter_test.rb`

Expected: PASS

- [ ] **Step 5: Run the registry test again to verify nothing regressed**

Run: `bin/rails test test/services/sources/adapter_registry_test.rb test/services/sources/info_casas_api_adapter_test.rb`

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add app/services/sources/info_casas_api_adapter.rb test/services/sources/info_casas_api_adapter_test.rb test/services/sources/adapter_registry_test.rb
git commit -m "feat: add info casas api adapter"
```

### Task 3: Prove orchestrated ingest persists InfoCasas listings through the current pipeline

**Files:**
- Modify: `test/jobs/run_scrapers_job_test.rb`

**Interfaces:**
- Consumes: `RunScrapersJob.perform_now`
- Consumes: `Sources::InfoCasasApiAdapter#fetch_listings`
- Produces: persisted `Listing`, `SeenListing`, `ScrapingRun`, and `ScrapingSourceRun` records for an `info_casas_api` source

- [ ] **Step 1: Write the failing job test for InfoCasas ingest**

Add this test near the existing adapter-resolution/job coverage:

```ruby
test "ingests listings from the info casas api adapter through the orchestrator" do
  ListingSource.create!(name: "InfoCasas API", adapter_key: "info_casas_api")

  Sources::InfoCasasApiAdapter.any_instance.stub(:fetch_listings, [
    {
      external_id: "123",
      title: "Apartamento en Pocitos",
      canonical_url: "https://www.infocasas.com.uy/alquiler/apartamento/pocitos/123",
      description: "Apartamento luminoso con terraza",
      price_cents: 3_500_000,
      currency: "UYU",
      location_text: "Pocitos, Montevideo",
      bedrooms: 2,
      square_meters: 58
    }
  ]) do
    run = RunScrapersJob.perform_now

    assert_equal "succeeded", run.status
    assert_equal 1, run.listings_seen_count
    assert_equal 1, run.listings_created_count
    assert_equal 1, run.scraping_source_runs.count
    assert_equal "succeeded", run.scraping_source_runs.first.status

    listing = Listing.last
    assert_equal "InfoCasas API", listing.listing_source.name
    assert_equal "123", listing.external_id
    assert_equal "Pocitos, Montevideo", listing.location_text
    assert_equal 3_500_000, listing.price_cents
    assert_equal "UYU", listing.currency
    assert_equal "Apartamento luminoso con terraza", listing.description
    assert_equal 1, SeenListing.count
  end
end
```

- [ ] **Step 2: Run the job test to verify it fails for the expected reason**

Run: `bin/rails test test/jobs/run_scrapers_job_test.rb`

Expected: FAIL because `any_instance` stubbing is not available in this test style, or because the test needs to stub the adapter constructor differently.

- [ ] **Step 3: Replace the stub with a constructor-level stub that matches this codebase’s test style**

Use this version if `any_instance` fails:

```ruby
test "ingests listings from the info casas api adapter through the orchestrator" do
  ListingSource.create!(name: "InfoCasas API", adapter_key: "info_casas_api")

  adapter = Object.new
  adapter.define_singleton_method(:fetch_listings) do
    [{
      external_id: "123",
      title: "Apartamento en Pocitos",
      canonical_url: "https://www.infocasas.com.uy/alquiler/apartamento/pocitos/123",
      description: "Apartamento luminoso con terraza",
      price_cents: 3_500_000,
      currency: "UYU",
      location_text: "Pocitos, Montevideo",
      bedrooms: 2,
      square_meters: 58
    }]
  end

  Sources::InfoCasasApiAdapter.stub(:new, adapter) do
    run = RunScrapersJob.perform_now

    assert_equal "succeeded", run.status
    assert_equal 1, run.listings_seen_count
    assert_equal 1, run.listings_created_count

    source_run = run.scraping_source_runs.first
    assert_equal "info_casas_api", source_run.listing_source.adapter_key
    assert_equal "succeeded", source_run.status
    assert_equal 1, source_run.listings_seen_count
    assert_equal 1, source_run.listings_created_count

    listing = Listing.last
    assert_equal "123", listing.external_id
    assert_equal "https://www.infocasas.com.uy/alquiler/apartamento/pocitos/123", listing.canonical_url
    assert_equal "Pocitos, Montevideo", listing.location_text
    assert_equal 3_500_000, listing.price_cents
    assert_equal "UYU", listing.currency
    assert_equal "Apartamento luminoso con terraza", listing.description
    assert_equal listing.id, SeenListing.last.listing_id
  end
end
```

- [ ] **Step 4: Run the job test to verify it passes**

Run: `bin/rails test test/jobs/run_scrapers_job_test.rb`

Expected: PASS

- [ ] **Step 5: Run the full focused scraper test set**

Run: `bin/rails test test/services/sources/adapter_registry_test.rb test/services/sources/info_casas_api_adapter_test.rb test/jobs/run_scrapers_job_test.rb test/services/scraping/listing_intake_test.rb`

Expected: PASS with no live-network access

- [ ] **Step 6: Commit**

```bash
git add test/jobs/run_scrapers_job_test.rb test/services/sources/adapter_registry_test.rb test/services/sources/info_casas_api_adapter_test.rb app/services/sources/info_casas_api_adapter.rb
git commit -m "test: cover info casas scraper ingestion"
```

## Self-review

- **Spec coverage:** The plan covers registry resolution, adapter normalization, and orchestrated ingest, while explicitly avoiding abstraction-first work, retries, and live-network automated tests.
- **Placeholder scan:** No `TBD`, `TODO`, or generic “add tests” placeholders remain; each task includes concrete code and commands.
- **Type consistency:** Every task uses the same adapter name (`Sources::InfoCasasApiAdapter`), key (`info_casas_api`), and return shape (`Array<Hash>` with normalized listing attributes).
