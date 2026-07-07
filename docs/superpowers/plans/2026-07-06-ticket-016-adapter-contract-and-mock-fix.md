# Ticket 016: Adapter Contract and Mock Adapter Fix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enforce the normalized listing attribute contract at intake (fail loudly instead of silently marking listings out of scope), fix `MockSourceAdapter` so the seeded demo feed shows listings, and delete the dead `info_casas_legacy_map.rb`.

**Architecture:** Validation lives at the intake boundary (`Scraping::ListingIntake`), not in a base adapter class — it catches contract violations from any adapter regardless of implementation style (per `adr-adapter-contract`). A violation raises `ListingIntake::InvalidAttributesError`; `Scraping::RunOrchestrator#process_source` already rescues per source and marks that source run `failed` without killing the run (`app/services/scraping/run_orchestrator.rb:46-48`).

**Tech Stack:** Rails 8, Minitest.

## Global Constraints

- **PRECONDITION:** Ticket 014's plan has been executed (the backfill no longer calls `ListingIntake`, so intake validation cannot break geometry backfills). If 014 hasn't landed, stop and report.
- Required attribute keys (exactly these, per `adr-adapter-contract`): `title`, `canonical_url`, `source_city`, `operation_type`. `external_id` stays optional (`Listing` allows nil, `app/models/listing.rb:10`).
- Full suite green after every commit: `bin/rails test` → `0 failures, 0 errors`.

---

### Task 1: Intake contract validation

**Files:**
- Modify: `app/services/scraping/listing_intake.rb`
- Create: `test/services/scraping/listing_intake_contract_test.rb`
- Possibly modify: existing tests that call `ListingIntake#call` or `RunOrchestrator` with incomplete attributes (see Step 5)

**Interfaces:**
- Produces: `Scraping::ListingIntake::InvalidAttributesError`, `Scraping::ListingIntake::REQUIRED_ATTRIBUTES`. Task 2's mock adapter must satisfy this contract.

- [ ] **Step 1: Write the failing test**

Create `test/services/scraping/listing_intake_contract_test.rb`:

```ruby
require "test_helper"

class Scraping::ListingIntakeContractTest < ActiveSupport::TestCase
  setup do
    @source = ListingSource.create!(name: "InfoCasas API", adapter_key: "info_casas_api")
    @valid_attributes = {
      external_id: "1",
      title: "Apto Centro",
      canonical_url: "https://www.infocasas.com.uy/alquiler/apartamento/centro/1",
      source_city: "Montevideo",
      operation_type: "alquiler"
    }
  end

  test "accepts attributes satisfying the contract" do
    listing = Scraping::ListingIntake.new.call(listing_source: @source, attributes: @valid_attributes)

    assert listing.persisted?
    assert listing.in_scope?
  end

  test "raises naming every missing required attribute" do
    error = assert_raises(Scraping::ListingIntake::InvalidAttributesError) do
      Scraping::ListingIntake.new.call(
        listing_source: @source,
        attributes: @valid_attributes.except(:source_city, :operation_type)
      )
    end

    assert_match "source_city", error.message
    assert_match "operation_type", error.message
    assert_match @valid_attributes[:canonical_url], error.message
    assert_equal 0, Listing.count
  end

  test "orchestrator marks the source run failed when an adapter violates the contract" do
    ListingSource.where.not(id: @source.id).update_all(active: false)
    bad_adapter = Object.new
    bad_adapter.define_singleton_method(:fetch_listings) do
      [{ external_id: "1", title: "No scope fields", canonical_url: "https://example.test/1" }]
    end
    original_resolve = Sources::AdapterRegistry.method(:resolve)
    Sources::AdapterRegistry.define_singleton_method(:resolve) { |_source| bad_adapter }

    run = Scraping::RunOrchestrator.new.call

    source_run = run.scraping_source_runs.find_by!(listing_source: @source)
    assert_equal "failed", source_run.status
    assert_match "source_city", source_run.error_message
    assert_equal "completed_with_failures", run.status
  ensure
    Sources::AdapterRegistry.define_singleton_method(:resolve, original_resolve)
  end
end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bin/rails test test/services/scraping/listing_intake_contract_test.rb`
Expected: FAIL — `NameError: uninitialized constant Scraping::ListingIntake::InvalidAttributesError`.

- [ ] **Step 3: Implement the contract in intake**

In `app/services/scraping/listing_intake.rb`, add inside the class (above `def call`):

```ruby
class InvalidAttributesError < StandardError; end

REQUIRED_ATTRIBUTES = %i[title canonical_url source_city operation_type].freeze
```

Then make `call` validate first (current `call` is at lines 3-10):

```ruby
def call(listing_source:, attributes:, scraping_run: nil)
  validate_attributes!(attributes)

  listing, was_new_record = persist_listing(listing_source:, attributes:, scraping_run:)

  upsert_seen_listing(listing_source:, listing:, attributes:, scraping_run:)

  listing.instance_variable_set(:@created_by_intake, was_new_record)
  listing
end
```

And add to the private section:

```ruby
def validate_attributes!(attributes)
  missing = REQUIRED_ATTRIBUTES.select { |key| attributes[key].blank? }
  return if missing.empty?

  raise InvalidAttributesError,
    "missing required listing attributes: #{missing.join(', ')} (canonical_url=#{attributes[:canonical_url].inspect})"
end
```

- [ ] **Step 4: Run the new test file**

Run: `bin/rails test test/services/scraping/listing_intake_contract_test.rb`
Expected: PASS.

- [ ] **Step 5: Run the full suite and repair violating fixtures**

Run: `bin/rails test`

Existing tests that feed incomplete attributes through `ListingIntake` or `RunOrchestrator` will now raise. Expect failures in mock-adapter/orchestrator ingestion tests (the mock adapter is fixed in Task 2 — if the only failures are mock-sourced, proceed to Task 2 and re-run) and in any intake/service test whose attribute hashes lack `source_city`/`operation_type` — fix those by adding `source_city: "Montevideo", operation_type: "alquiler"` to the test attribute hashes. Grep to find them:

```bash
grep -rln "ListingIntake" test/
```

Do NOT weaken the contract to make a test pass; fix the test data.

- [ ] **Step 6: Commit** (only once the suite is green — if mock-adapter tests still fail, finish Task 2 first and commit both together as this message)

```bash
git add app/services/scraping/listing_intake.rb test/services/scraping/listing_intake_contract_test.rb <any repaired test files>
git commit -m "feat: enforce listing attribute contract at intake"
```

---

### Task 2: Fix the mock adapter to satisfy the contract

**Files:**
- Modify: `app/services/sources/mock_source_adapter.rb` (only `fetch_listings`, at the bottom of the file — do not edit the `LISTINGS` literal)
- Modify: `test/services/sources/mock_source_adapter_test.rb` (or wherever mock adapter expectations live — `grep -rln "MockSourceAdapter" test/`)

**Interfaces:**
- Consumes: `Scraping::ListingIntake::REQUIRED_ATTRIBUTES` contract from Task 1.
- Produces: mock listings that are `in_scope` and zone-matchable via `source_neighborhood`.

- [ ] **Step 1: Write the failing test**

Add to the mock adapter's test file:

```ruby
test "fetch_listings satisfies the intake contract and is zone-matchable" do
  listings = Sources::MockSourceAdapter.new.fetch_listings

  listings.each do |listing|
    Scraping::ListingIntake::REQUIRED_ATTRIBUTES.each do |key|
      assert listing[key].present?, "expected #{listing[:external_id]} to have #{key}"
    end
    assert_equal "Montevideo", listing[:source_city]
    assert_equal "alquiler", listing[:operation_type]
    assert listing[:source_neighborhood].present?
  end

  pocitos = listings.find { |listing| listing[:external_id] == "mock-pocitos-2d-01" }
  assert_equal "Pocitos", pocitos[:source_neighborhood]
end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bin/rails test test/services/sources/mock_source_adapter_test.rb`
Expected: FAIL — `expected mock-pocitos-2d-01 to have source_city`.

- [ ] **Step 3: Implement**

Replace `fetch_listings` in `app/services/sources/mock_source_adapter.rb` (currently `LISTINGS.map { ... transform_values ... }`) with:

```ruby
def fetch_listings
  LISTINGS.map do |listing|
    duplicated = listing.transform_values { |value| value.is_a?(String) ? value.dup : value }
    duplicated.merge(
      source_neighborhood: duplicated[:location_text].split(",").first.strip,
      source_city: "Montevideo",
      operation_type: "alquiler"
    )
  end
end
```

`source_neighborhood` derives from `location_text` (every mock entry is `"<Neighborhood>, Montevideo"`), which makes mock listings `location_resolution_status: "fallback"` and therefore matchable by the seeded zones' aliases (Pocitos/Centro) — so zone-based saved searches in the demo show results, not just `location_query` searches.

- [ ] **Step 4: Run the full suite**

Run: `bin/rails test`
Expected: PASS, `0 failures, 0 errors`. If orchestrator/feed tests assert mock listings were previously `in_scope: false` or absent from the feed, update those expectations — visible mock listings is the new intended behavior.

- [ ] **Step 5: Verify the demo feed end-to-end**

```bash
bin/rails runner 'Scraping::RunOrchestrator.new.call; search = User.find_by!(email: "demo@example.com").search_preferences.first; puts Listing.for_search_feed(search).count'
```

Expected: a number greater than 0 (was 0 before this ticket). Requires seeded dev DB (`bin/rails db:seed` if needed). Note this runs the real InfoCasas adapter too if that source is active — to keep it offline, first run `bin/rails runner 'ListingSource.find_by(adapter_key: "info_casas_api").update!(active: false)'` and re-activate after.

- [ ] **Step 6: Commit**

```bash
git add app/services/sources/mock_source_adapter.rb test/services/sources/mock_source_adapter_test.rb <any updated expectation files>
git commit -m "fix: emit scope metadata from mock source adapter"
```

---

### Task 3: Delete the dead legacy map

**Files:**
- Delete: `app/services/sources/info_casas_legacy_map.rb`
- Modify: `app/services/sources/info_casas_api_adapter.rb:4` (remove `require_relative "info_casas_legacy_map"`)

**Interfaces:** none — the file defines `MAP_BOUNDS`/`MAP_POLYGON` constants nothing references (adapter sends `map_polygon: []`, `map_bounds: []`).

- [ ] **Step 1: Verify it is truly dead**

```bash
grep -rn "InfoCasasLegacyMap\|MAP_POLYGON\|MAP_BOUNDS\|info_casas_legacy_map" app/ lib/ test/ config/
```

Expected: only the definition file itself and the `require_relative` in the adapter. If anything else shows up, STOP and report instead of deleting.

- [ ] **Step 2: Delete**

```bash
git rm app/services/sources/info_casas_legacy_map.rb
```

Remove line 4 (`require_relative "info_casas_legacy_map"`) from `app/services/sources/info_casas_api_adapter.rb`.

- [ ] **Step 3: Run the full suite**

Run: `bin/rails test`
Expected: PASS, `0 failures, 0 errors`.

- [ ] **Step 4: Commit and update state docs**

```bash
git add app/services/sources/info_casas_api_adapter.rb
git commit -m "chore: delete dead info casas legacy map"
```

Then update `.ai/STATUS.md` (Ticket 016 done; demo feed works out of the box; next milestone per roadmap) and commit as `docs: mark ticket 016 complete`.
