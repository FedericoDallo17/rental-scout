# 020 - Port viable home_scraper sources

## Goal
Add the viable non-MercadoLibre sources from `../home_scraper` as isolated `ListingSource` adapters so the development app can ingest more real Montevideo rental inventory while MercadoLibre API keys are pending.

## Scope
- Add `remax`, `housi`, and `imperium_inmobiliaria` adapters.
- Keep each adapter bounded to one index/list request per `fetch_listings` call.
- Normalize returned rows into the existing `ListingIntake` contract.
- Seed the new `ListingSource` records inactive by default until explicitly enabled for local live runs.
- Document Sorhuet as checked but deferred: current targeted route returns no Pocitos records; broad HTML route is parseable but too noisy for a first pass.

## Out of Scope
- MercadoLibre.
- Cross-source deduplication.
- Currency conversion.
- Background job changes or automatic live scrape triggering.

## Definition of Done
- HTTP-layer tests cover each new adapter.
- New adapters handle blocked/invalid responses by returning an empty list or raising a source-specific unexpected response error caught by the orchestrator.
- `.ai/STATUS.md` and roadmap reflect the new source expansion status.
- Full test suite passes.
