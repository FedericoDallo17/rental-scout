# Home Scraper Source Expansion Design

## Decision
Port the viable old `../home_scraper` sources as independent adapters behind the existing source registry. The first implementation adds Remax, Housi, and Imperium Inmobiliaria. Sorhuet is recorded as investigated but deferred because the current targeted Pocitos rental URL returns an empty result set and the broader route would add lower-confidence normalization.

## Source Findings
- Remax: static search page embeds the same RedREMAX API response, and the direct API endpoint returns JSON for the old Pocitos rental query.
- Housi: the search page is server-rendered Tokko HTML. No standalone listing API was exposed by the page scripts, but the index HTML contains property ids, URLs, prices, titles, addresses, property type, and area.
- Imperium Inmobiliaria: the old Heroku API is reachable with correctly quoted query params and returns JSON rows under `response.result[].property`.
- Sorhuet: JavaScript only builds filter URLs and dependent select values. Broad rental HTML has cards; the old targeted apartment/Pocitos route returns "No se encontraron propiedades".

## Architecture
Each source gets a focused `Sources::*Adapter` with one public `fetch_listings` method returning normalized listing hashes. The adapters do not share a base class yet; duplication is small, and keeping source-specific parsing explicit makes provider changes easier to isolate.

All adapters use `Net::HTTP` with explicit open/read timeouts and browser-ish headers. They make one list/index request only. Tests stub the HTTP layer, not `fetch_listings`.

## Normalization
Adapters must emit:
- `external_id`
- `title`
- `canonical_url`
- `price_cents`
- `currency`
- `location_text`
- `source_neighborhood`
- `source_city`
- `operation_type`
- optional `bedrooms`, `square_meters`, `latitude`, `longitude`, `description`

No currency conversion is performed. USD listings remain `currency: "USD"` with USD cents.

## Activation
Seed records are added inactive by default. This lets the development app display configured sources without triggering additional live providers during existing scrape runs until the user explicitly activates them.

## Testing
Add HTTP-layer unit tests with compact inline fixtures for each adapter:
- Remax API JSON normalization and request shape.
- Housi HTML card normalization.
- Imperium API JSON normalization and filtering of non-residential or bedroomless rows.
- Invalid/empty provider payload handling.
