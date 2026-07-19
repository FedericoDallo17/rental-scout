# CLAUDE.md

Rental Scout Lite — Rails 8 pilot for an AI-driven dev workflow around a real product:
scrape rental sources hourly, dedupe into a shared Montevideo inventory, match against
user-owned saved searches (PostGIS zones + price/bedrooms), and (eventually) notify.

Product identity: **freshness-first** — "be the first to find a new listing," not a
complete catalog. Inventory is a rolling ~1-week window (see
`.ai/decisions/adr-freshness-first-inventory.md`); design features with that lens.

## Read first

- `.ai/WORKFLOW.md` — how to continue this project (the dev loop, step by step)
- `.ai/STATUS.md` — truthful current state and next step
- `docs/superpowers/reports/2026-07-06-state-of-the-project.md` — full audit: what's
  solid, what's scaffolding, ranked risks
- `.ai/decisions/` — ADRs; do not re-litigate decisions recorded there
- `.ai/product/roadmap.md` — priority order; `.ai/tickets/` — work items

## Setup / test / run

- `bin/setup` (needs local PostgreSQL with PostGIS; seeds create demo@example.com /
  password123, zones, saved searches)
- `bin/rails test` — full suite, ~2s. Keep it green.
- Background jobs: Solid Queue (`bin/jobs` or `SOLID_QUEUE_IN_PUMA`); hourly scrape is
  a recurring task in `config/recurring.yml`.

## Architecture (one paragraph)

`RunScrapersJob` → `Scraping::RunOrchestrator` iterates active `ListingSource`s,
resolves adapters via `Sources::AdapterRegistry` (`"Sources::#{key.camelize}Adapter"`),
each adapter's `fetch_listings` returns normalized attribute hashes →
`Scraping::ListingIntake` dedupes (external_id, then canonical_url), builds PostGIS
geometry (`ListingGeometryBuilder`), sets `in_scope` (`ListingScopeValidator`), tracks
`SeenListing` → feed reads `Listing.for_search_feed` (ST_Intersects on zones, alias
fallback, price/bedroom filters). Auth is Devise; searches are user-owned; listing
inventory is deliberately shared.

## Conventions and gotchas

- Conventional commits (`feat:`/`fix:`/`docs:`/`test:`). Dev loop: spec in
  `docs/superpowers/specs/`, plan in `docs/superpowers/plans/`, then implement.
- End every session with commits at ticket boundaries, or a dated note in
  `docs/superpowers/handoffs/` saying what's in flight and what's known broken.
  Never leave unlabeled work in the tree.
- **Backward pressure rule (the loop's known weakness): after meaningful changes,
  update `.ai/STATUS.md`; record architectural decisions as ADRs in `.ai/decisions/`
  (template: `.ai/templates/adr.md`); commit specs/plans with the work. Mark
  superseded docs instead of abandoning them.**
- Propshaft serves `app/assets/stylesheets/application.css`; the legacy
  `public/stylesheets/application.css` compatibility copy remains a hand-maintained
  byte-identical mirror (enforced by `test/assets/stylesheet_mirror_test.rb`).
- Adapter contract is implicit: missing keys (e.g. `source_city`, `operation_type`)
  silently mark listings out of scope. Ticket 016 fixes this; until then, check
  `in_scope` when a feed looks empty.
- Scraping hits a live third-party API (InfoCasas). Be conservative: timeouts exist,
  rate limiting does not yet (Ticket 014). **Never trigger a live scrape**
  (`RunScrapersJob`, `bin/jobs`, a runner calling an adapter) unless the user
  explicitly asks for one in this session.
- Tests stub `fetch_listings` wholesale — green tests do not prove live-API behavior
  (this hid a functionally dead backfill once; prefer stubbing at the HTTP layer).
