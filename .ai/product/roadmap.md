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
- Ticket 014: landed in-flight InfoCasas work - header restyle, adapter enrichment, coordinate backfill from detail pages

## Now
- Ticket 015: notification pipeline MVP - plan: docs/superpowers/plans/2026-07-06-ticket-015-notification-pipeline-mvp.md

## Next
- Ticket 016: adapter contract + mock adapter fix - plan: docs/superpowers/plans/2026-07-06-ticket-016-adapter-contract-and-mock-fix.md

## Later
- Ticket 017: purge stale listings one week (decided in adr-freshness-first-inventory; ready plan)
- Second real source (MercadoLibre) - gated on Ticket 016; must address currency handling cross-source dedup
- Listing scoring/ranking (Ticket 006) - deferred per adr-notifications-over-ranking
- Run observability surfacing (Ticket 011)

## Dropped now
- Map UI, match explanations (deferred in 06-27 frontend spec)
