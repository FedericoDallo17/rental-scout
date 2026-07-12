# MercadoLibre Source Design

## Goal
Add MercadoLibre Uruguay as the second real source for the freshness-first rental feed while preserving the existing scraper pipeline: adapters fetch provider data, emit normalized listing attributes, and `Scraping::ListingIntake` owns validation, scope marking, deduplication, and persistence.

## Current Constraints
- The app currently has one real adapter, `Sources::InfoCasasApiAdapter`, and source resolution is convention-based through `Sources::AdapterRegistry`.
- `Scraping::ListingIntake` requires `title`, `canonical_url`, `source_city`, and `operation_type` before persistence.
- The app stores `price_cents` and `currency`, but saved-search price filters are currently currency-blind.
- Existing deduplication is source-local: `listing_source + external_id`, falling back to `listing_source + canonical_url`.
- A read-only public MercadoLibre API probe from this environment returned `403` for `https://api.mercadolibre.com/sites/MLU/search?...`, and the public website path asked for login. The adapter implementation must therefore begin by capturing a permitted MercadoLibre index payload before final normalization.

## Approach
Implement `Sources::MercadoLibreApiAdapter` as a normal source adapter, not a separate ingestion path. It should fetch a bounded MercadoLibre Uruguay rental apartment index, normalize each result to the app's existing listing attribute contract, and let `Scraping::RunOrchestrator` and `Scraping::ListingIntake` handle persistence.

The first implementation task is a payload-capture spike. If MercadoLibre's public API remains blocked, stop and record the response details rather than scraping around login gates. If a permitted index response is available, save a compact test fixture containing only fields needed for normalization tests.

## Normalization Rules
- `external_id`: provider result id.
- `title`: provider result title.
- `canonical_url`: provider permalink or equivalent public listing URL.
- `description`: index summary if available; otherwise `nil`.
- `price_cents`: provider numeric price multiplied by 100.
- `currency`: provider currency id as returned, such as `UYU` or `USD`; do not convert.
- `location_text`: human-readable location assembled from provider address/location fields.
- `source_neighborhood`: provider neighborhood or best available location label.
- `source_city`: provider city/department normalized to `Montevideo` only when the provider payload supports that conclusion.
- `operation_type`: `alquiler` only when category, listing type, or query/index metadata supports that conclusion.
- `bedrooms`, `square_meters`, `latitude`, `longitude`: mapped from index attributes when available; otherwise `nil`.

## Currency Behavior
This ticket stores MercadoLibre currency explicitly and avoids exchange-rate logic. Saved-search price filters must not compare USD listings against UYU budgets as if they were the same currency. The narrow implementation is to apply price bounds only when the listing currency matches the search currency assumption, currently UYU, and leave exchange-rate support for a later ticket.

## Cross-Source Dedup Behavior
This ticket keeps source-local deduplication. Cross-source duplicates between InfoCasas and MercadoLibre remain possible unless MercadoLibre exposes a reliable shared property/listing identifier. Fuzzy matching by title, price, neighborhood, or photos is out of scope because false merges would be worse than duplicate cards in the pilot.

## Testing
- Adapter tests use HTTP-layer stubs and compact MercadoLibre fixture payloads.
- Intake contract tests prove missing required normalized keys fail loudly.
- Feed/filter tests cover mixed currency listings so price bounds do not silently hide or include USD listings incorrectly.
- Seed tests or existing seed checks cover the new `ListingSource`.

## Out of Scope
- Currency conversion.
- Cross-source fuzzy deduplication.
- Authenticated MercadoLibre API integration.
- Browser automation through login-gated MercadoLibre pages.
- Ranking/scoring changes.
