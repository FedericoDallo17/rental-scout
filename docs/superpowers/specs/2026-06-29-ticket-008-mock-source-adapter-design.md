# Ticket 008 Mock Source Adapter Design

## Context
Ticket 008 should upgrade the current mock source adapter from a single demo listing into a deterministic, curated feed that better supports the app's current frontend and scraper flow.

The current `Sources::MockSourceAdapter` returns one minimal hard-coded listing. That is enough to exercise the plumbing, but it is too thin to support realistic feed browsing, filter testing, and frontend card iteration.

The accepted scraper ADR defines `Listing` as the app's normalized apartment record and keeps the source adapter contract simple: adapters should return normalized listing attributes without introducing source-specific scraping complexity into the rest of the system.

The user-approved direction for Ticket 008 is:
- static, not simulated
- deterministic, not random
- curated Montevideo-specific listings
- around 8-12 listings by default
- useful for feed browsing and filtering

## Goals
- Replace the single-record mock adapter output with a curated deterministic feed of about 10 listings.
- Keep the adapter contract unchanged: `fetch_listings` returns normalized hashes.
- Make the listings realistic enough for frontend card design and saved-search feed browsing.
- Ensure the dataset exercises location, price, bedroom, and size variation.
- Persist a `description` field on `Listing` so richer listing content can flow through the app.

## Non-Goals
- Simulating listings appearing or disappearing across runs.
- Simulating failures, retries, or pagination.
- Performing real HTTP scraping.
- Introducing provider-specific scraping logic.
- Turning the mock adapter into a seed-driven or database-driven source.

## Approaches Considered

### 1. Static curated dataset inside the mock adapter
**Recommendation.**

Store the curated dataset directly in `Sources::MockSourceAdapter` and keep `fetch_listings` as a deterministic method returning normalized hashes.

Pros:
- Smallest change from the current implementation.
- Keeps behavior extremely easy to understand and test.
- Matches the existing adapter contract and orchestration flow.
- Best fit for a dataset of roughly 10 records.

Cons:
- The adapter file will contain a moderately large hard-coded dataset.

### 2. Static curated dataset extracted to a separate fixture or constant file
Keep the same behavior, but move the listing payload out of the adapter file.

Pros:
- Slightly tidier separation between behavior and data.
- Easier to expand later if the dataset grows.

Cons:
- Adds indirection without much benefit at this size.
- Slightly more moving parts for a still-simple mock source.

### 3. Database-backed mock source
Have the adapter read from seeded records instead of returning static hashes.

Pros:
- More flexible if the feed later needs richer lifecycle behavior.

Cons:
- Too heavy for this ticket.
- Less deterministic unless setup is tightly controlled.
- Adds coupling to persistence for what should remain a simple adapter.

## Decision
Implement Ticket 008 using a static curated dataset inside `Sources::MockSourceAdapter`.

The adapter will remain deterministic and return an array of normalized hashes from `fetch_listings`. The rest of the scraping pipeline will remain unchanged.

## Design

### Adapter behavior
`Sources::MockSourceAdapter#fetch_listings` will return roughly 10 normalized listing hashes representing curated Montevideo apartment rentals.

The adapter remains:
- in-process
- static
- deterministic
- free of network access

It will not simulate changing source behavior across runs.

### Listing data shape
Each returned listing hash should include:
- `external_id`
- `title`
- `canonical_url`
- `location_text`
- `price_cents`
- `bedrooms`
- `square_meters`
- `description`

These fields should be populated consistently for every mock listing.

### Dataset rules
The curated dataset should follow these rules:
- about 10 records by default
- all locations are recognizable Montevideo neighborhoods
- all `external_id` values are unique
- all `canonical_url` values are unique
- URLs are clearly fake and remain under `https://example.test/...`
- prices, bedroom counts, square meters, and wording vary enough to make filters and cards meaningfully different
- records are complete rather than sparse

Suggested neighborhoods include combinations such as:
- Pocitos
- Cordón
- Centro
- Parque Rodó
- Tres Cruces
- Malvín
- Buceo
- Punta Carretas

### Persistence change
Add a `description` column to the `listings` table.

No special intake logic should be required beyond that schema addition, because `Scraping::ListingIntake` already assigns incoming attributes onto `Listing` through `assign_attributes`. Once the model and schema support `description`, the existing flow should persist it automatically and preserve it inside `raw_payload` as part of the original attributes hash.

### Integration impact
No changes are needed to:
- `Sources::AdapterRegistry`
- `Scraping::RunOrchestrator`
- the adapter resolution contract

The main behavior change is simply that the mock source now returns a richer and larger normalized feed, and the listing schema now stores `description`.

## Testing Strategy

### 1. Mock adapter unit test
Update `test/services/sources/mock_source_adapter_test.rb` to verify:
- the adapter returns roughly 10 listings
- each listing includes the full normalized key set including `description`
- the dataset includes Montevideo-specific locations
- `external_id` values are unique
- `canonical_url` values are unique

### 2. Scraper job/orchestration coverage
Update `test/jobs/run_scrapers_job_test.rb` so the mock source expectations match the new dataset size rather than 1 listing.

At minimum, tests should verify:
- the mock source run succeeds
- `listings_seen_count` equals the dataset size
- `listings_created_count` equals the dataset size on first ingestion
- aggregate run counts reflect the curated feed size

### 3. Persistence coverage for description
Add or update test coverage proving that a listing ingested from the adapter persists `description` on the resulting `Listing` record.

This should protect the schema change and ensure the richer normalized field actually survives intake.

## Consequences
- The frontend gets a much more useful feed for browsing and styling work.
- Search filters get more realistic coverage without real scraping.
- The adapter remains easy to reason about and stable under test.
- The `Listing` model becomes slightly richer by storing `description`.

## Related Files
- `.ai/tickets/008-mock-source-adapter.md`
- `.ai/decisions/adr-scraper-domain.md`
- `app/services/sources/mock_source_adapter.rb`
- `app/services/scraping/listing_intake.rb`
- `app/models/listing.rb`
- `test/services/sources/mock_source_adapter_test.rb`
- `test/jobs/run_scrapers_job_test.rb`
