# Ticket: 025 - City-Wide Sources and Authoritative Neighborhoods

## Goal

Build a city-wide inventory and classify coordinate-bearing listings with official
Montevideo neighborhood boundaries instead of provider query bias.

## Acceptance Criteria

- [x] Remax, Housi, and Imperium queries are not restricted to Pocitos.
- [x] Missing provider neighborhoods remain unresolved instead of defaulting to Pocitos.
- [x] IDE Uruguay's 62 Montevideo neighborhood polygons import reproducibly with provenance.
- [x] Coordinate-derived neighborhoods override conflicting provider metadata.
- [x] Provider address text remains preserved while cards show the resolved neighborhood.
- [x] Scraping observability reports spatial, fallback, unresolved, and provider-mismatch counts.

## Human Approval Required?

Yes. The user approved city-wide provider queries, the IDE Uruguay boundary source,
the zone provenance migration, and location-quality observability on 2026-07-12.

## Definition of Done

- [x] `bin/rails test` green
- [x] `.ai/STATUS.md` updated
- [x] Existing PostGIS ADR remains authoritative; no new architectural decision required
- [x] Spec/plan committed alongside the work (`docs/superpowers/`)
- [x] Superseded Pocitos-only behavior removed rather than left undocumented
