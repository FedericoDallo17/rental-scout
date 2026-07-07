# Roadmap

Last updated: 2026-07-06. Phases A/B and most of the unplanned auth/geo work are done;
this reflects reality (see docs/superpowers/reports/2026-07-06-state-of-the-project.md).

## Done
- Discovery, look and feel, MVP scope (stub docs only)
- Mock source adapter, portal listing surface
- Deduplication + seen-listing tracking
- Real InfoCasas API adapter (superseded Ticket 013's spike gate)
- Devise auth + user-owned searches (unplanned; see adr-devise-auth-shared-inventory)
- PostGIS zones + shared Montevideo inventory (see adr-postgis-app-as-search-engine)
- Hourly job configured (Solid Queue recurring) — not yet validated end-to-end

## Now
- Ticket 014: land in-flight InfoCasas work (backfill fix, rate limiting, commit split)

## Next
- Ticket 015: notification pipeline MVP (validates hourly job end-to-end)
- Ticket 016: adapter contract enforcement + mock adapter fix (unblocks demo, source #2)

## Later
- Second real source (MercadoLibre) — gated on Ticket 016; must address currency
  handling and cross-source dedup
- Listing scoring/ranking (Ticket 006) — deferred per adr-notifications-over-ranking
- Run observability surfacing (Ticket 011)

## Dropped for now
- Map UI, match explanations (deferred in the 06-27 frontend spec)
