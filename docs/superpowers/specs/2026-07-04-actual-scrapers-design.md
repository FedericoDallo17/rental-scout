# Actual scrapers design

## Summary

Rental Scout Lite currently runs a mock source through the scraper orchestration pipeline. The next step is to introduce a real scraper source by porting the working InfoCasas API scraper from `../home_scraper` into this app. The goal of this first pass is narrow: make `info_casas_api` participate in the existing ingestion pipeline and persist real listings successfully. Broader abstraction, retries, and live smoke hardening are intentionally deferred.

## Goals

- Add one real scraper source to `rental-scout-lite`
- Reuse the proven InfoCasas API behavior from `../home_scraper`
- Keep the existing orchestration and intake flow unchanged
- Persist normalized `Listing` and `SeenListing` records through the current pipeline
- Cover the behavior with automated tests written first

## Non-goals

- Building a reusable HTTP/API scraper framework
- Porting multiple real sources in this ticket
- Adding retry logic, backoff, or richer operational hardening
- Reworking `RunOrchestrator`, `ListingIntake`, or the adapter registry contract
- Requiring live-network access in automated tests

## Context

`rental-scout-lite` already has the essential ingestion path in place:

- `RunScrapersJob`
- `Scraping::RunOrchestrator`
- `Sources::AdapterRegistry`
- source adapters returning normalized listing hashes
- `Scraping::ListingIntake` persisting `Listing` and `SeenListing`

The app currently uses a curated `MockSourceAdapter`. Meanwhile, `../home_scraper` contains a working `InfoCasasApiScraper` that already performs the remote request and parses the response. That legacy implementation is the behavioral reference for this work.

## Recommended approach

Use a thin direct port.

Create a new `Sources::InfoCasasApiAdapter` in `rental-scout-lite` by copying the essential request/response behavior from `../home_scraper/app/services/info_casas_api_scraper.rb`, then adapting its returned hashes to the normalized attributes expected by `ListingIntake`.

This is preferred over wrapper-heavy or abstraction-first approaches because it gets one real source working quickly while staying close to code that already proved useful in practice.

## Architecture

The runtime flow remains:

`RunScrapersJob` → `Scraping::RunOrchestrator` → `Sources::AdapterRegistry` → `Sources::InfoCasasApiAdapter#fetch_listings` → `Scraping::ListingIntake`

No new orchestration layer is introduced. The only new integration point is the adapter class itself plus the corresponding `ListingSource` record using:

- `name`: user-facing source label
- `adapter_key`: `info_casas_api`

The registry should continue to resolve adapter classes by camelizing `adapter_key`, so `info_casas_api` maps naturally to `Sources::InfoCasasApiAdapter`.

## Adapter responsibilities

`Sources::InfoCasasApiAdapter` should:

1. Perform the InfoCasas API request
2. Parse the returned payload using the legacy shape as the source of truth
3. Normalize each result into the attribute hash expected by `ListingIntake`
4. Return an array of normalized listing hashes

The adapter should not persist anything itself. Persistence stays inside `ListingIntake`.

## Data mapping

The adapter should map legacy InfoCasas API records into the current listing contract as directly as possible.

Core fields:

- `external_id` ← InfoCasas `id`
- `title` ← `title`
- `canonical_url` ← front-end base URL + payload `link`
- `description` ← `description`
- `price_cents` ← normalized from the API price field into the app’s integer cents-style storage

Best-effort optional fields when present and straightforward to extract:

- `bedrooms`
- `square_meters`
- `location_text`

The adapter should prefer successful ingest over exhaustive normalization. Fields that do not yet map cleanly may remain `nil` as long as deduplication and persistence still work through `external_id` and `canonical_url`.

`ListingIntake` already copies the returned attributes into `raw_payload`, so the adapter can preserve useful source data by returning a hash that contains the normalized values and any source details worth retaining for later debugging or future extraction.

## Error handling

The adapter should raise on request failures or payload-shape failures rather than swallowing them.

That matches the current orchestration model:

- `RunOrchestrator` records a failed `ScrapingSourceRun`
- the overall run continues to other active sources
- the overall `ScrapingRun` becomes `completed_with_failures` when at least one source fails

No new rescue/retry layer is needed in this first pass.

## Testing strategy

This work should follow TDD.

Required automated coverage:

1. Registry resolution for `info_casas_api`
   - prove `Sources::AdapterRegistry` resolves the new adapter from `adapter_key`

2. Adapter normalization
   - provide a representative fixed API payload shaped like the legacy InfoCasas response
   - verify `fetch_listings` returns normalized hashes with the expected core fields

3. Orchestrated ingest
   - create an active `ListingSource` with `adapter_key: "info_casas_api"`
   - stub the adapter’s HTTP response
   - verify the scraper run creates persisted `Listing`, `SeenListing`, and `ScrapingSourceRun` records successfully

Automated tests should not hit the live network. They should stub the remote response with a sample payload copied from the legacy shape so the tests are deterministic and can fail only for real application regressions.

## Implementation boundaries

This first ticket is successful when:

- the app contains `Sources::InfoCasasApiAdapter`
- `info_casas_api` resolves through the existing adapter registry
- an orchestrated run can ingest at least one representative InfoCasas listing into the current persistence pipeline
- tests cover resolution, normalization, and end-to-end ingest behavior without live network dependency

This ticket does not need to prove:

- the live endpoint is still available every time
- all optional listing metadata is perfectly normalized
- multiple real sources share a common base abstraction
- scraper operations are production hardened

## Follow-up work

After this basic ingest lands, the next iteration can address:

- live smoke verification against the current endpoint
- payload-shape drift handling
- reusable HTTP/API adapter helpers
- shared normalization utilities across future real sources
- retries, timeouts, and more explicit operational telemetry
