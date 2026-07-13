# Roadmap

Last updated: 2026-07-13. Phases A/B and most unplanned auth/geo work are done; this reflects reality (see docs/superpowers/reports/2026-07-06-state-of-the-project.md).

## Done
- Discovery, look feel, MVP scope (stub docs only)
- Mock source adapter, portal listing surface
- Deduplication + seen-listing tracking
- Real InfoCasas API adapter (superseded Ticket 013's spike gate)
- Devise auth + user-owned searches (unplanned; see adr-devise-auth-shared-inventory)
- PostGIS zones + shared Montevideo inventory (see adr-postgis-app-as-search-engine)
- Hourly job configured (Solid Queue recurring) - not yet validated end-to-end
- Ticket 014: landed in-flight InfoCasas work - header restyle, adapter enrichment, coordinate backfill detail pages
- Ticket 015: notification pipeline MVP - fan-out, Pushover delivery seam, post-scrape notification job
- Ticket 016: adapter contract + mock adapter fix - intake validation, scope metadata in mock adapter, demo feed restored
- Ticket 017: purge stale listings one week - daily hard-delete job for listings not seen in 7 days
- Ticket 011: scraping runs observability - signed-in page for recent run status, source outcomes, and errors
- Ticket 019: saved search management - signed-in users create, edit, and delete their own search filters
- Ticket 006: saved-search-specific listing scoring - transient 0–100 scores rank
  matches by price fit, bedroom fit, and detail completeness with recency ties
- Ticket 021: scheduled scrape lifecycle validation - stubbed Remax HTTP response
  proves queued intake, match, delivery, and repeat-run notification idempotency
- Ticket 022: authenticated notification settings - users can configure or remove
  their Pushover key without the saved credential being rendered or logged
- Ticket 023: grouped run notifications - one summary push per user and run links
  to authenticated, persisted match results
- Ticket 024: conservative cross-source deduplication - exact complete signatures
  share inventory while retaining each provider occurrence
- Ticket 025: city-wide sources and authoritative neighborhoods - provider queries
  cover Montevideo, IDE Uruguay polygons resolve coordinates, and runs report
  location-quality diagnostics
- Ticket 026: coordinate coverage and live validation - per-source coverage metrics,
  bounded provider probes, and a daily 20-listing InfoCasas coordinate backfill
- Ticket 027: bilingual user interface - persisted English/Spanish preference and
  translated signed-in product surfaces
- Ticket 028A: aligned listing-card text tracks and product-facing `InfoCasas`
  labels without exposing internal adapter keys
- Ticket 029: preserved InfoCasas rent currency independently from peso-denominated
  common expenses and removed the acquisition-time peso-only filter
- Ticket 030: added a bilingual UYU/USD saved-search price currency and made
  bounded feed filtering and scoring currency-safe
- Ticket 031: removed the permanent Type fact from listing cards while preserving
  provider type data for future conditional use
- Ticket 032: replaced mixed-purpose coincidence points with preference-only fit,
  separate completeness, and readable bilingual presentation
- Ticket 033: added a deduplicated all-searches feed, active-search deselection,
  match labels, and bilingual server-side sorting/filtering controls

## Now
- Resolve the remaining Ticket 028 product and provider-fetch decisions.
- MercadoLibre remains paused pending API keys or allowed index payload.

## Product gaps to shape

- Ticket 028: card alignment, user-facing source names, card fact density,
  incremental provider fetching, score semantics/contrast, and feed sorting,
  filtering, deselection, and all-search aggregation.

## Next
- Implement provider-specific incremental fetching; resume MercadoLibre when API
  keys or an allowed index payload are available.

## Dropped now
- Map UI, match explanations (deferred in 06-27 frontend spec)
