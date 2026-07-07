# Ticket 008 Mock Source Adapter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single-record mock source with a deterministic curated Montevideo feed and persist listing descriptions through the scraper pipeline.

**Architecture:** Keep the existing adapter contract unchanged by returning normalized hashes from `Sources::MockSourceAdapter#fetch_listings`. Add `description` to the `Listing` schema, then expand adapter and integration tests so the richer dataset is exercised end-to-end through the current intake and orchestration flow.

**Tech Stack:** Ruby on Rails 8, Active Record, Minitest

## Global Constraints

- Keep the adapter static, deterministic, and free of network access.
- Return normalized hashes from `fetch_listings`; do not change adapter resolution or orchestration interfaces.
- Default dataset should be curated, Montevideo-specific, and about 8-12 listings.
- Do not add pagination, lifecycle simulation, retries, or failure simulation.
- Use TDD for each task: failing test first, then minimal implementation, then verification.

---

## File Structure

- Create: `db/migrate/20260629120000_add_description_to_listings.rb` — adds the `description` column to `listings`.
- Modify: `db/schema.rb` — schema snapshot updated after migration.
- Modify: `app/models/listing.rb` — include `description` in validations only if needed; otherwise keep model unchanged unless tests require it.
- Modify: `app/services/sources/mock_source_adapter.rb` — replace the single-record stub with the curated deterministic dataset.
- Modify: `test/services/scraping/listing_intake_test.rb` — prove description persists through intake and remains in `raw_payload`.
- Modify: `test/services/sources/mock_source_adapter_test.rb` — validate dataset size, key shape, uniqueness, and Montevideo-specific content.
- Modify: `test/jobs/run_scrapers_job_test.rb` — update mock-source expectations to the curated dataset size and verify persisted description through job execution.

### Task 1: Persist listing descriptions through intake

**Files:**
- Create: `db/migrate/20260629120000_add_description_to_listings.rb`
- Modify: `db/schema.rb`
- Test: `test/services/scraping/listing_intake_test.rb`

**Interfaces:**
- Consumes: `Scraping::ListingIntake#call(listing_source:, attributes:, scraping_run: nil) -> Listing`
- Produces: `Listing#description -> String | nil` persisted from normalized adapter attributes

- [ ] **Step 1: Write the failing intake test**

```ruby
test "persists description from normalized adapter attributes" do
  source = ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")
  intake = Scraping::ListingIntake.new
  attributes = {
    title: "Apto Pocitos",
    canonical_url: "https://example.test/a",
    external_id: "1",
    location_text: "Pocitos",
    price_cents: 3_200_000,
    bedrooms: 2,
    square_meters: 55,
    description: "Luminoso apartamento con terraza y gastos comunes bajos"
  }

  listing = intake.call(listing_source: source, attributes: attributes)

  assert_equal "Luminoso apartamento con terraza y gastos comunes bajos", listing.description
  assert_equal attributes, listing.raw_payload.symbolize_keys.slice(*attributes.keys)
end
```

- [ ] **Step 2: Run the intake test to verify it fails**

Run: `bin/rails test test/services/scraping/listing_intake_test.rb`
Expected: FAIL with `undefined method 'description'` or unknown attribute / missing column errors for `description`

- [ ] **Step 3: Add the migration and migrate the test database**

```ruby
class AddDescriptionToListings < ActiveRecord::Migration[8.0]
  def change
    add_column :listings, :description, :text
  end
end
```

Run: `bin/rails db:migrate`

Run: `RAILS_ENV=test bin/rails db:test:prepare`

- [ ] **Step 4: Re-run the intake test and keep implementation minimal**

No intake code changes should be needed if `ListingIntake` continues using:

```ruby
def listing_attributes(attributes)
  attrs = attributes.dup
  attrs[:raw_payload] = attributes
  attrs
end
```

Run: `bin/rails test test/services/scraping/listing_intake_test.rb`
Expected: PASS

- [ ] **Step 5: Commit Task 1**

```bash
git add db/migrate db/schema.rb test/services/scraping/listing_intake_test.rb
git commit -m "feat: persist listing descriptions"
```

### Task 2: Expand the mock adapter into a curated Montevideo feed

**Files:**
- Modify: `app/services/sources/mock_source_adapter.rb`
- Test: `test/services/sources/mock_source_adapter_test.rb`

**Interfaces:**
- Consumes: `Sources::MockSourceAdapter.new.fetch_listings -> Array<Hash>`
- Produces: about 10 listing hashes with keys `:external_id, :title, :canonical_url, :location_text, :price_cents, :bedrooms, :square_meters, :description`

- [ ] **Step 1: Write the failing adapter test**

```ruby
test "returns a curated deterministic Montevideo dataset" do
  listings = Sources::MockSourceAdapter.new.fetch_listings

  assert_equal 10, listings.size
  assert_equal %i[bedrooms canonical_url description external_id location_text price_cents square_meters title].sort,
               listings.first.keys.sort

  assert_includes listings.map { |listing| listing[:location_text] }, "Pocitos, Montevideo"
  assert_includes listings.map { |listing| listing[:location_text] }, "Cordón, Montevideo"
  assert_equal listings.size, listings.map { |listing| listing[:external_id] }.uniq.size
  assert_equal listings.size, listings.map { |listing| listing[:canonical_url] }.uniq.size
  assert listings.all? { |listing| listing[:canonical_url].start_with?("https://example.test/listings/") }
  assert listings.all? { |listing| listing[:description].present? }
end
```

- [ ] **Step 2: Run the adapter test to verify it fails**

Run: `bin/rails test test/services/sources/mock_source_adapter_test.rb`
Expected: FAIL because only one listing is returned and `description`, `bedrooms`, and dataset assertions do not match

- [ ] **Step 3: Replace the stub with the curated dataset**

```ruby
module Sources
  class MockSourceAdapter
    LISTINGS = [
      {
        external_id: "mock-pocitos-2d-01",
        title: "Apartamento de 2 dormitorios con terraza en Pocitos",
        canonical_url: "https://example.test/listings/mock-pocitos-2d-01",
        location_text: "Pocitos, Montevideo",
        price_cents: 3_250_000,
        bedrooms: 2,
        square_meters: 58,
        description: "Living luminoso, cocina definida y terraza al frente a pocas cuadras de la rambla"
      },
      {
        external_id: "mock-cordon-1d-02",
        title: "Apartamento de 1 dormitorio reciclado en Cordón",
        canonical_url: "https://example.test/listings/mock-cordon-1d-02",
        location_text: "Cordón, Montevideo",
        price_cents: 2_180_000,
        bedrooms: 1,
        square_meters: 41,
        description: "Unidad reciclada con buena luz natural y conexión rápida al Centro y Tres Cruces"
      },
      {
        external_id: "mock-centro-studio-03",
        title: "Monoambiente amplio cerca de Plaza Cagancha",
        canonical_url: "https://example.test/listings/mock-centro-studio-03",
        location_text: "Centro, Montevideo",
        price_cents: 1_790_000,
        bedrooms: 0,
        square_meters: 33,
        description: "Espacio bien resuelto con kitchenette y buena locomoción en el corazón del Centro"
      },
      {
        external_id: "mock-parque-rodo-2d-04",
        title: "Apartamento de 2 dormitorios a pasos del parque",
        canonical_url: "https://example.test/listings/mock-parque-rodo-2d-04",
        location_text: "Parque Rodó, Montevideo",
        price_cents: 3_480_000,
        bedrooms: 2,
        square_meters: 64,
        description: "Planta cómoda con balcón, placares y cercanía a facultades, rambla y servicios"
      },
      {
        external_id: "mock-tres-cruces-1d-05",
        title: "Apartamento funcional de 1 dormitorio en Tres Cruces",
        canonical_url: "https://example.test/listings/mock-tres-cruces-1d-05",
        location_text: "Tres Cruces, Montevideo",
        price_cents: 2_240_000,
        bedrooms: 1,
        square_meters: 44,
        description: "Ideal para moverse por toda la ciudad, con cocina integrada y dormitorio definido"
      },
      {
        external_id: "mock-malvin-3d-06",
        title: "Apartamento familiar de 3 dormitorios en Malvín",
        canonical_url: "https://example.test/listings/mock-malvin-3d-06",
        location_text: "Malvín, Montevideo",
        price_cents: 4_650_000,
        bedrooms: 3,
        square_meters: 89,
        description: "Unidad espaciosa con vista despejada, lavadero y ambientes cómodos cerca de la costa"
      },
      {
        external_id: "mock-buceo-2d-07",
        title: "Apartamento de 2 dormitorios con garage en Buceo",
        canonical_url: "https://example.test/listings/mock-buceo-2d-07",
        location_text: "Buceo, Montevideo",
        price_cents: 3_950_000,
        bedrooms: 2,
        square_meters: 70,
        description: "Edificio moderno con ascensor, garage fijo y acceso rápido a WTC y la rambla"
      },
      {
        external_id: "mock-punta-carretas-1d-08",
        title: "Apartamento de 1 dormitorio en Punta Carretas",
        canonical_url: "https://example.test/listings/mock-punta-carretas-1d-08",
        location_text: "Punta Carretas, Montevideo",
        price_cents: 3_120_000,
        bedrooms: 1,
        square_meters: 47,
        description: "Buen metraje para un dormitorio, balcón al frente y servicios a pocas cuadras"
      },
      {
        external_id: "mock-pocitos-nuevo-2d-09",
        title: "Apartamento de 2 dormitorios en Pocitos Nuevo",
        canonical_url: "https://example.test/listings/mock-pocitos-nuevo-2d-09",
        location_text: "Pocitos Nuevo, Montevideo",
        price_cents: 3_680_000,
        bedrooms: 2,
        square_meters: 62,
        description: "Living comedor cómodo, cocina semi integrada y buena conexión con Rivera y la rambla"
      },
      {
        external_id: "mock-cordon-sur-1d-10",
        title: "Apartamento de 1 dormitorio en Cordón Sur",
        canonical_url: "https://example.test/listings/mock-cordon-sur-1d-10",
        location_text: "Cordón Sur, Montevideo",
        price_cents: 2_560_000,
        bedrooms: 1,
        square_meters: 46,
        description: "Opción práctica para estudiantes o profesionales, cerca de facultades y servicios"
      }
    ].freeze

    def fetch_listings
      LISTINGS.map(&:dup)
    end
  end
end
```

Keep the array exactly at 10 listings so the adapter and integration tests can assert a fixed deterministic dataset size.

- [ ] **Step 4: Run the adapter test to verify it passes**

Run: `bin/rails test test/services/sources/mock_source_adapter_test.rb`
Expected: PASS

- [ ] **Step 5: Commit Task 2**

```bash
git add app/services/sources/mock_source_adapter.rb test/services/sources/mock_source_adapter_test.rb
git commit -m "feat: expand mock source dataset"
```

### Task 3: Update scraper job expectations for the curated feed

**Files:**
- Modify: `test/jobs/run_scrapers_job_test.rb`
- Optionally Modify: `test/services/sources/mock_source_adapter_test.rb` if a shared dataset-size constant is introduced in a minimal way

**Interfaces:**
- Consumes: `RunScrapersJob.perform_now -> ScrapingRun`
- Produces: job-level verification that the mock source ingests the curated feed size and persists descriptions

- [ ] **Step 1: Write the failing integration assertions**

Update the mock-source job tests to expect the dataset size rather than `1`:

```ruby
test "links the run to the records it processes" do
  ListingSource.create!(name: "Mock Source", adapter_key: "mock_source")

  run = RunScrapersJob.perform_now

  assert_equal 10, run.listings.count
  assert_equal 10, run.seen_listings.count
  assert_equal run.id, Listing.last.scraping_run_id
  assert_equal run.id, SeenListing.last.scraping_run_id
  assert_predicate Listing.last.description, :present?
end
```

And update the per-source outcome expectation:

```ruby
assert_equal 10, source_run.listings_seen_count
assert_equal 10, source_run.listings_created_count
```

Also update the mixed-failure test:

```ruby
assert_equal 10, run.listings_seen_count
assert_equal 10, run.listings_created_count
```

- [ ] **Step 2: Run the job test to verify it fails**

Run: `bin/rails test test/jobs/run_scrapers_job_test.rb`
Expected: FAIL while the mock adapter still returns fewer records than the updated assertions expect, or until all count assertions match the new dataset

- [ ] **Step 3: Keep implementation minimal by using the adapter dataset as-is**

No orchestrator code changes should be required if the adapter already returns the curated dataset and the listing schema now supports `description`. The relevant integration path should remain:

```ruby
listings = Sources::AdapterRegistry.resolve(listing_source).fetch_listings

listings.each do |attributes|
  listing = intake.call(listing_source:, attributes:, scraping_run: run)
  created_count += 1 if listing.instance_variable_get(:@created_by_intake)
end
```

- [ ] **Step 4: Run focused and broader verification**

Run: `bin/rails test test/jobs/run_scrapers_job_test.rb`
Expected: PASS

Run: `bin/rails test test/services/sources/mock_source_adapter_test.rb test/services/scraping/listing_intake_test.rb test/jobs/run_scrapers_job_test.rb test/models/listing_test.rb`
Expected: PASS

- [ ] **Step 5: Commit Task 3**

```bash
git add test/jobs/run_scrapers_job_test.rb
git commit -m "test: verify curated mock scraper feed"
```

## Final Verification

- [ ] Run: `bin/rails test test/services/scraping/listing_intake_test.rb test/services/sources/mock_source_adapter_test.rb test/jobs/run_scrapers_job_test.rb test/models/listing_test.rb`
Expected: PASS

- [ ] Run: `bin/rails test`
Expected: PASS

- [ ] Run: `git status --short`
Expected: only intended tracked changes remain before any final review/PR step
