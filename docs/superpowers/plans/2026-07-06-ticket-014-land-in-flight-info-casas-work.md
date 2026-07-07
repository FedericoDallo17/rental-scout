# Ticket 014: Land In-Flight InfoCasas Work — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix and commit the three mingled uncommitted change sets in the working tree: header restyle, InfoCasas adapter enrichment, and the coordinate backfill (which is functionally broken as written).

**Architecture:** The working tree (as of commit `c83e81c`) already contains most of the code. Task 1 lands the style changes untouched except a comment fix. Task 2 hardens the enriched adapter (max-page guard, throttling, loud errors) and exposes a public per-URL detail-coordinate fetch. Task 3 rewrites the backfill to use that per-URL fetch instead of trawling the last-hour search feed (where stale listings never appear).

**Tech Stack:** Rails 8, Minitest, Net::HTTP (no HTTP-mocking gem — tests stub via `define_singleton_method`, see `test/services/sources/info_casas_api_adapter_test.rb:323-343`).

## Global Constraints

- **PRECONDITION:** the uncommitted working tree from 2026-07-06 must be present (`git status` shows modified adapter/css/layout/tests and untracked backfill files). If it is gone, stop and report.
- Do not use `git add -A` or `git add .` — stage exact paths only; unrelated change sets coexist in the tree until the final task.
- Full suite must stay green after every commit: `bin/rails test` → `0 failures, 0 errors`.
- The audit context behind every fix is `docs/superpowers/reports/2026-07-06-state-of-the-project.md` ("The uncommitted working tree").

---

### Task 1: Land the header/style change set

**Files:**
- Modify: `public/stylesheets/application.css:1-6` (comment only)
- Commit (already-modified, no further edits): `app/views/layouts/application.html.erb`, `app/assets/stylesheets/application.css`, `test/integration/authentication_flow_test.rb`, `test/integration/listings_flow_test.rb`

**Interfaces:**
- Produces: nothing consumed by later tasks; independent commit.

- [ ] **Step 1: Restore the honest mirror comment**

`public/stylesheets/application.css` is a hand-maintained byte-identical mirror of `app/assets/stylesheets/application.css` (there is no Propshaft/Sprockets in the Gemfile; the layout's `stylesheet_link_tag "application"` resolves to the public file). The working-tree diff replaced its header with false Propshaft boilerplate. Replace the leading comment block (the first `/* ... */` block, lines 1–~9) of **`public/stylesheets/application.css` only** with:

```css
/*
 * Hand-maintained mirror of app/assets/stylesheets/application.css.
 * There is no asset pipeline in this app; the layout serves this file directly.
 * When you edit app/assets/stylesheets/application.css, copy the styles here too.
 */
```

Leave `app/assets/stylesheets/application.css` untouched. The two files intentionally differ only in this header from now on.

- [ ] **Step 2: Run the integration tests that cover the restyle**

Run: `bin/rails test test/integration/authentication_flow_test.rb test/integration/listings_flow_test.rb`
Expected: PASS (these tests were already updated in the working tree for the new header markup).

- [ ] **Step 3: Commit the style change set**

```bash
git add app/views/layouts/application.html.erb app/assets/stylesheets/application.css public/stylesheets/application.css test/integration/authentication_flow_test.rb test/integration/listings_flow_test.rb
git commit -m "style: brand app header and flash styling"
```

---

### Task 2: Harden the enriched InfoCasas adapter

**Files:**
- Modify: `app/services/sources/info_casas_api_adapter.rb`
- Modify: `test/services/sources/info_casas_api_adapter_test.rb`
- Commit (already new in tree): `test/services/sources/info_casas_detail_geo_test.rb`

**Interfaces:**
- Produces: `Sources::InfoCasasApiAdapter#detail_coordinates_for_url(canonical_url) -> {latitude:, longitude:} | {}` (public), `Sources::InfoCasasApiAdapter::UnexpectedResponseError`, constructor keywords `page_throttle_seconds:` (default `1.0`) and `detail_throttle_seconds:` (default `0.5`). Task 3 and `AdapterRegistry` (`.new` with no args) depend on these signatures.

- [ ] **Step 1: Write the failing tests**

Add to `test/services/sources/info_casas_api_adapter_test.rb` (inside the class, above `private`):

```ruby
test "fetch_listings raises UnexpectedResponseError when the payload is malformed" do
  adapter = Sources::InfoCasasApiAdapter.new(page_throttle_seconds: 0, detail_throttle_seconds: 0)

  stub_http_response(adapter, JSON.generate([{ data: {} }])) do
    assert_raises(Sources::InfoCasasApiAdapter::UnexpectedResponseError) do
      adapter.fetch_listings
    end
  end
end

test "fetch_listings stops at the max page guard when every page is full" do
  adapter = Sources::InfoCasasApiAdapter.new(page_throttle_seconds: 0, detail_throttle_seconds: 0)
  test_case = self
  requested_pages = []

  http = Object.new
  http.define_singleton_method(:request) do |request|
    page = JSON.parse(request.body).first.fetch("variables").fetch("page")
    requested_pages << page
    entries = Array.new(50) { |index| test_case.send(:info_casas_entry, id: (page * 1000) + index) }
    Struct.new(:body).new(test_case.send(:stubbed_info_casas_response_for, entries))
  end

  stub_net_http_start(->(*, **, &block) { block.call(http) }) do
    listings = adapter.fetch_listings

    assert_equal Sources::InfoCasasApiAdapter::MAX_PAGES, requested_pages.size
    assert_equal 50 * Sources::InfoCasasApiAdapter::MAX_PAGES, listings.size
  end
end

test "detail_coordinates_for_url returns empty hash and logs when the detail fetch fails" do
  adapter = Sources::InfoCasasApiAdapter.new(page_throttle_seconds: 0, detail_throttle_seconds: 0)
  adapter.define_singleton_method(:detail_response) { |*| raise Net::ReadTimeout }

  logged = []
  Rails.logger.stub(:warn, ->(message) { logged << message }) do
    assert_equal({}, adapter.detail_coordinates_for_url("https://www.infocasas.com.uy/x/1"))
  end
  assert_match(/detail coordinate fetch failed/, logged.join)
end
```

Also delete the now-superseded test `"fetch_listings raises when the payload is malformed"` (the one asserting `NoMethodError`, currently at lines 161-169).

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/sources/info_casas_api_adapter_test.rb`
Expected: FAIL — `NameError: uninitialized constant ... UnexpectedResponseError`, `unknown keyword: :page_throttle_seconds`.

- [ ] **Step 3: Implement the adapter changes**

In `app/services/sources/info_casas_api_adapter.rb`:

(a) Below `LAST_HOUR_PUBLICATION_DATE = 1` add:

```ruby
MAX_PAGES = 40
DEFAULT_PAGE_THROTTLE_SECONDS = 1.0
DEFAULT_DETAIL_THROTTLE_SECONDS = 0.5

class UnexpectedResponseError < StandardError; end
```

(b) Add a constructor right above `def fetch_listings`:

```ruby
def initialize(page_throttle_seconds: DEFAULT_PAGE_THROTTLE_SECONDS, detail_throttle_seconds: DEFAULT_DETAIL_THROTTLE_SECONDS)
  @page_throttle_seconds = page_throttle_seconds
  @detail_throttle_seconds = detail_throttle_seconds
end
```

(c) Replace the body of `fetch_listings` (currently lines 44-57) with:

```ruby
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
```

(d) Add the public per-URL method directly below `fetch_listings` (above `private`):

```ruby
def detail_coordinates_for_url(canonical_url)
  sleep(@detail_throttle_seconds) if @detail_throttle_seconds.positive?
  detail_coordinates_from_html(detail_response(canonical_url).body)
rescue StandardError => error
  Rails.logger.warn("[InfoCasasApiAdapter] detail coordinate fetch failed for #{canonical_url}: #{error.class}: #{error.message}")
  {}
end
```

(e) Replace the private `detail_coordinates_for(entry)` (currently lines 110-115) with a delegation:

```ruby
def detail_coordinates_for(entry)
  detail_coordinates_for_url(URI.join(FRONTEND_BASE_URL, entry[:link]).to_s)
end
```

- [ ] **Step 4: Zero the throttle in existing multi-request tests**

In `test/services/sources/info_casas_api_adapter_test.rb`, the test `"fetch_listings requests every recent page until results are exhausted"` instantiates `Sources::InfoCasasApiAdapter.new` and now sleeps 1s between pages. Change that instantiation (and any other test that paginates or hits the detail path, including all of `test/services/sources/info_casas_detail_geo_test.rb`) to:

```ruby
adapter = Sources::InfoCasasApiAdapter.new(page_throttle_seconds: 0, detail_throttle_seconds: 0)
```

- [ ] **Step 5: Run the full suite**

Run: `bin/rails test`
Expected: PASS, `0 failures, 0 errors` (backfill tests still pass because they stub `fetch_listings` wholesale; they are rewritten in Task 3).

- [ ] **Step 6: Commit the adapter change set**

```bash
git add app/services/sources/info_casas_api_adapter.rb test/services/sources/info_casas_api_adapter_test.rb test/services/sources/info_casas_detail_geo_test.rb
git commit -m "feat: paginate and enrich info casas acquisition"
```

---

### Task 3: Rewrite the coordinate backfill to fetch detail pages directly

**Files:**
- Rewrite: `app/services/scraping/backfill_info_casas_coordinates.rb`
- Modify: `app/jobs/backfill_info_casas_coordinates_job.rb` (unchanged code, committed here)
- Create: `test/services/scraping/backfill_info_casas_coordinates_test.rb`
- Rewrite: `test/jobs/backfill_info_casas_coordinates_job_test.rb`

**Interfaces:**
- Consumes: `Sources::InfoCasasApiAdapter#detail_coordinates_for_url` from Task 2.
- Produces: `Scraping::BackfillInfoCasasCoordinates#call(limit: nil, external_ids: nil, adapter: Sources::InfoCasasApiAdapter.new) -> Result(listings_seen_count:, listings_updated_count:)`.

Why the rewrite: the current service calls `adapter.fetch_listings` per 20-listing batch, but `fetch_listings` filters to listings published in the last hour — stale coordless rows never appear there, so the backfill is a no-op in production (green tests hid this by stubbing `fetch_listings`). Each coordless listing already stores its `canonical_url`; fetch its detail page directly.

- [ ] **Step 1: Write the failing service test**

Create `test/services/scraping/backfill_info_casas_coordinates_test.rb`:

```ruby
require "test_helper"

class Scraping::BackfillInfoCasasCoordinatesTest < ActiveSupport::TestCase
  test "backfills coordinates from each listing's detail page" do
    source = ListingSource.create!(name: "InfoCasas API", adapter_key: "info_casas_api")
    other_source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")

    coordless = Listing.create!(
      listing_source: source,
      title: "Missing Coordinates",
      canonical_url: "https://www.infocasas.com.uy/alquiler/apartamento/cordon/1",
      external_id: "1",
      source_neighborhood: "Cordón",
      location_resolution_status: "fallback"
    )
    Listing.create!(
      listing_source: source,
      title: "Already Spatial",
      canonical_url: "https://www.infocasas.com.uy/alquiler/apartamento/cordon/2",
      external_id: "2",
      location_resolution_status: "spatial",
      latitude: -34.9,
      longitude: -56.18,
      coordinates: Zone::FACTORY.point(-56.18, -34.9)
    )
    Listing.create!(
      listing_source: other_source,
      title: "Other Source",
      canonical_url: "https://example.test/listings/1",
      external_id: "3",
      source_neighborhood: "Centro",
      location_resolution_status: "fallback"
    )

    adapter = fake_adapter("https://www.infocasas.com.uy/alquiler/apartamento/cordon/1" => { latitude: -34.9057216, longitude: -56.1822016 })

    result = Scraping::BackfillInfoCasasCoordinates.new.call(adapter: adapter)

    assert_equal 1, result.listings_seen_count
    assert_equal 1, result.listings_updated_count
    coordless.reload
    assert_in_delta(-34.9057216, coordless.latitude.to_f, 0.000001)
    assert_not_nil coordless.coordinates
    assert_equal "spatial", coordless.location_resolution_status
  end

  test "leaves the listing untouched when the detail page yields no coordinates" do
    source = ListingSource.create!(name: "InfoCasas API", adapter_key: "info_casas_api")
    listing = Listing.create!(
      listing_source: source,
      title: "No Geo",
      canonical_url: "https://www.infocasas.com.uy/alquiler/apartamento/cordon/9",
      external_id: "9",
      source_neighborhood: "Cordón",
      location_resolution_status: "fallback"
    )

    result = Scraping::BackfillInfoCasasCoordinates.new.call(adapter: fake_adapter({}))

    assert_equal 1, result.listings_seen_count
    assert_equal 0, result.listings_updated_count
    assert_nil listing.reload.coordinates
    assert_equal "fallback", listing.location_resolution_status
  end

  test "respects limit and external_ids filters" do
    source = ListingSource.create!(name: "InfoCasas API", adapter_key: "info_casas_api")
    %w[1 2 3].each do |external_id|
      Listing.create!(
        listing_source: source,
        title: "Missing #{external_id}",
        canonical_url: "https://www.infocasas.com.uy/alquiler/apartamento/cordon/#{external_id}",
        external_id: external_id,
        source_neighborhood: "Cordón",
        location_resolution_status: "fallback"
      )
    end
    adapter = fake_adapter(
      "https://www.infocasas.com.uy/alquiler/apartamento/cordon/2" => { latitude: -34.91, longitude: -56.19 }
    )

    result = Scraping::BackfillInfoCasasCoordinates.new.call(external_ids: ["2"], limit: 5, adapter: adapter)

    assert_equal 1, result.listings_seen_count
    assert_equal 1, result.listings_updated_count
    assert_nil source.listings.find_by!(external_id: "1").latitude
    assert_in_delta(-34.91, source.listings.find_by!(external_id: "2").latitude.to_f, 0.000001)
  end

  private

  def fake_adapter(coordinates_by_url)
    adapter = Object.new
    adapter.define_singleton_method(:detail_coordinates_for_url) do |url|
      coordinates_by_url.fetch(url, {})
    end
    adapter
  end
end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bin/rails test test/services/scraping/backfill_info_casas_coordinates_test.rb`
Expected: FAIL — `unknown keyword: :adapter` (current service has no adapter injection) and count-method mismatches.

- [ ] **Step 3: Rewrite the service**

Replace the entire contents of `app/services/scraping/backfill_info_casas_coordinates.rb` with:

```ruby
module Scraping
  class BackfillInfoCasasCoordinates
    BATCH_SIZE = 20

    Result = Struct.new(:listings_seen_count, :listings_updated_count, keyword_init: true)

    def call(limit: nil, external_ids: nil, adapter: Sources::InfoCasasApiAdapter.new)
      source = ListingSource.find_by!(adapter_key: "info_casas_api")
      geometry_builder = Scraping::ListingGeometryBuilder.new

      seen_count = 0
      updated_count = 0

      relation = source.listings
        .where(coordinates: nil)
        .where.not(location_resolution_status: "unresolved")
      relation = relation.where(external_id: Array(external_ids).map(&:to_s)) if external_ids.present?
      relation = relation.limit(limit) if limit.present?

      relation.find_each(batch_size: BATCH_SIZE) do |listing|
        seen_count += 1
        coordinates = adapter.detail_coordinates_for_url(listing.canonical_url)
        next if coordinates[:latitude].blank? || coordinates[:longitude].blank?

        attrs = geometry_builder.call(
          attributes: {
            latitude: coordinates[:latitude],
            longitude: coordinates[:longitude],
            source_neighborhood: listing.source_neighborhood
          }
        )
        listing.update!(attrs.slice(:latitude, :longitude, :coordinates, :location_resolution_status))
        updated_count += 1
      end

      Result.new(listings_seen_count: seen_count, listings_updated_count: updated_count)
    end
  end
end
```

Notes: no `OpenStruct`, no `ListingIntake` (this service only repairs geometry — it must not overwrite listing attributes from a stale payload), no full-feed fetch. Rate limiting lives inside `detail_coordinates_for_url` (Task 2). The `unresolved` exclusion is kept: those rows have no neighborhood fallback and their detail pages were already tried at intake time.

- [ ] **Step 4: Rewrite the job test**

Replace the entire contents of `test/jobs/backfill_info_casas_coordinates_job_test.rb` with:

```ruby
require "test_helper"

class BackfillInfoCasasCoordinatesJobTest < ActiveJob::TestCase
  test "runs the backfill service against the real adapter" do
    source = ListingSource.create!(name: "InfoCasas API", adapter_key: "info_casas_api")
    Listing.create!(
      listing_source: source,
      title: "Missing Coordinates",
      canonical_url: "https://www.infocasas.com.uy/alquiler/apartamento/cordon/1",
      external_id: "1",
      source_neighborhood: "Cordón",
      location_resolution_status: "fallback"
    )

    adapter = Object.new
    adapter.define_singleton_method(:detail_coordinates_for_url) do |_url|
      { latitude: -34.9057216, longitude: -56.1822016 }
    end
    original_new = Sources::InfoCasasApiAdapter.method(:new)
    Sources::InfoCasasApiAdapter.define_singleton_method(:new) { |*, **| adapter }

    result = BackfillInfoCasasCoordinatesJob.perform_now

    assert_equal 1, result.listings_seen_count
    assert_equal 1, result.listings_updated_count
    assert_not_nil source.listings.find_by!(external_id: "1").coordinates
  ensure
    Sources::InfoCasasApiAdapter.define_singleton_method(:new, original_new)
  end
end
```

The job itself (`app/jobs/backfill_info_casas_coordinates_job.rb`) needs no code change.

- [ ] **Step 5: Run the full suite**

Run: `bin/rails test`
Expected: PASS, `0 failures, 0 errors`.

- [ ] **Step 6: Commit the backfill change set and verify the tree is clean**

```bash
git add app/services/scraping/backfill_info_casas_coordinates.rb app/jobs/backfill_info_casas_coordinates_job.rb test/services/scraping/backfill_info_casas_coordinates_test.rb test/jobs/backfill_info_casas_coordinates_job_test.rb
git commit -m "feat: backfill info casas coordinates from detail pages"
git status --short
```

Expected `git status`: only `.superpowers/brainstorm/` remains untracked (session scratch — leave it). Update `.ai/STATUS.md` (mark Ticket 014 done, next is 015) and commit that as `docs: mark ticket 014 complete`.
