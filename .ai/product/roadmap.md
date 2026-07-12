# Roadmap

Last updated: 2026-07-12. Phases A/B and most unplanned auth/geo work are done; this reflects reality (see docs/superpowers/reports/2026-07-06-state-of-the-project.md).

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

## Now
- Second real source (MercadoLibre) - paused pending API keys or allowed index payload; must address currency handling cross-source dedup

## Next
- Listing scoring/ranking (Ticket 006) - deferred per adr-notifications-over-ranking

## Dropped now
- Map UI, match explanations (deferred in 06-27 frontend spec)
