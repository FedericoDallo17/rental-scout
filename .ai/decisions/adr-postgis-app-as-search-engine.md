# ADR: PostGIS Zones — the App Is the Search Engine

## Status
Accepted (retroactive record, written 2026-07-06 for work shipped 2026-07-05)

## Context
Originally the scraper forwarded narrow user-specific queries to the source. The
2026-07-05 "Montevideo shared inventory + zone search" cycle pivoted: the app now
ingests broad Montevideo rental inventory into a shared pool and performs zone matching
itself — `ST_Intersects` against PostGIS zone polygons for listings with coordinates,
neighborhood-alias matching as fallback. This was a large architectural pivot executed
via spec+plan but never recorded as a decision, leaving it open to re-litigation.

## Decision
The app owns search. Sources are ingested broadly (city-level scope), listings carry
PostGIS `geography` points built at intake, and saved searches filter the shared
inventory by zone polygons, price, and bedrooms. Zones are seeded polygons with
neighborhood aliases for coordinate-less listings.

## Alternatives Considered
- Per-search source queries (the original model): rejected — couples scrape cadence to
  search count, duplicates inventory per user, and most source APIs can't express zone
  polygons anyway.
- Geocoding neighborhood strings instead of alias matching: deferred — alias matching
  is free and reversible; geocoding adds an external dependency.

## Provisional Areas
- Fallback alias matching quality (depends on seeded aliases; empty-alias zones
  currently risk invalid `IN ()` SQL — fix tracked in Ticket 014's follow-ups).
- Scrape window (currently last-hour) vs backfill strategy for older inventory.

## Consequences
- Inventory is shared across users; data scoping applies to searches, not listings.
- Requires PostGIS everywhere (dev/test/prod) — accepted, encoded in `bin/setup`.
- Scrape parameters are source-level, not user-level; user preferences never reach the
  scraper. Anything outside the broad scope is never ingested.

## Related Tickets
- Cycle: docs/superpowers/specs/2026-07-05-montevideo-shared-inventory-zone-search-design.md
