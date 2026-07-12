# Status

Last updated: 2026-07-12. New here? Read `.ai/WORKFLOW.md` first - it's the dev loop.
Full audit context: docs/superpowers/reports/2026-07-06-state-of-the-project.md

## Current Phase
Freshness-first MVP lifecycle complete; additional real sources are next product expansion

## Current Task
Provider-sample data model follow-up while MercadoLibre API keys are pending

## Status
Ticket 020 landed: Remax, Housi, and Imperium Inmobiliaria adapters are seeded as inactive sources; raw provider samples are stored under `docs/provider_samples/2026-07-12`; a controlled development scrape imported new real rows. MercadoLibre remains paused until API keys or an allowed index payload sample are available.

## Done
- Docs, tickets, governance, mock scraper pipeline, initial portal (06-27..06-29)
- Scraper domain ADR (007)
- Devise auth + user-owned saved searches, shared listing inventory (07-03..07-04)
- Real InfoCasas API adapter timeouts error handling (07-04)
- PostGIS zones: listing geometry at intake, zone-based feed filtering (07-05)
- Hourly RunScrapersJob configured via Solid Queue recurring tasks (unvalidated end-to-end)
- Full audit + decision records + roadmap refresh (07-06)
- Workflow guardrails: CSS-mirror test, STATUS structure test (replaced frozen bootstrap snapshot), ticket Definition-of-Done, shared `.claude/settings.json`, live-scrape HTTP-layer-stubbing policy lines; `.ai/WORKFLOW.md` runbook (07-11)
- Ticket 014 landed: branded header/flash styling, InfoCasas pagination max-page guard throttles, coordinate backfill repaired fetch listing detail pages directly (07-11; concurrent session stamped 07-12 in error)
- Follow-up 014: removed inline per-listing detail from `fetch_listings`; live probe showed index returns 0/50 coordinates, so fallback would guarantee 1+N detail requests during list scrape. Coordinates now come from backfill only.
- Ticket 018 planned: MercadoLibre source ticket, design spec, implementation plan written. Read-only probes to `api.mercadolibre.com/sites/MLU/search` returned `403`, so adapter normalization must not be written against guessed provider fields.
- Ticket 011 landed: signed-in scraping run observability page shows recent run status, counts, per-source rows, error messages (07-12)
- Ticket 019 landed: signed-in users can create, edit, delete own saved searches zones filters (07-12)
- Hybrid Workbench polish landed: saved-search sidebar cards show match counts, search forms include feed context, scraping runs include feed navigation plus source timelines (07-12)
- Ticket 020 landed: Remax direct RedREMAX API adapter, Housi server-rendered HTML adapter, Imperium API adapter, raw provider samples, scrape-driven parser hardening, clickable listing cards, source activation controls, studio bedroom normalization, UYU-only price filtering, and currency labels on cards (07-12)

## Doing
- Provider-sample data model follow-up: normalize expenses, parking, and property type from raw provider payloads.

## Blockers
- MercadoLibre public API and HTML probes return access/login gates from this environment; user is obtaining API keys.

## Risks
- Second source introduces currency handling and cross-source dedup risks called out in adapter-contract ADR.
- Real Pushover delivery requires runtime `PUSHOVER_API_TOKEN` and real user `pushover_user_key`; tests use injected fake clients.

## Human Input Needed
- Approve a migration for provider-derived fields such as `expenses_cents`, `parking_spaces`, and `property_type`.
- Provide `PUSHOVER_API_TOKEN` and user Pushover keys before manual end-to-end push validation.

## Next Step
After migration approval, add normalized provider fields from the saved samples; otherwise resume Ticket 018 when MercadoLibre API keys or an allowed index payload sample are available.
