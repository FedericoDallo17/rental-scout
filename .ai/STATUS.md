# Status

Last updated: 2026-07-12. New here? Read `.ai/WORKFLOW.md` first - it's the dev loop.
Full audit context: docs/superpowers/reports/2026-07-06-state-of-the-project.md

## Current Phase
Freshness-first MVP lifecycle complete; additional real sources are next product expansion

## Current Task
Provider-sample data model follow-up complete; MercadoLibre API keys pending

## Status
Provider-sample data model follow-up landed: listings now persist expenses, expenses currency, parking spaces, and property type where providers expose them; listing cards show those details. MercadoLibre remains paused until API keys or an allowed index payload sample are available.

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
- Provider-sample data model follow-up landed: `expenses_cents`, `expenses_currency`, `parking_spaces`, and `property_type` columns; adapters populate available fields; cards render provider detail rows (07-12)

## Doing
- Waiting for MercadoLibre API keys or next product gap selection.

## Blockers
- MercadoLibre public API and HTML probes return access/login gates from this environment; user is obtaining API keys.

## Risks
- Second source introduces currency handling and cross-source dedup risks called out in adapter-contract ADR.
- Real Pushover delivery requires runtime `PUSHOVER_API_TOKEN` and real user `pushover_user_key`; tests use injected fake clients.

## Human Input Needed
- Provide `PUSHOVER_API_TOKEN` and user Pushover keys before manual end-to-end push validation.

## Next Step
Resume Ticket 018 when MercadoLibre API keys or an allowed index payload sample are available; otherwise choose the next small unblocked product gap.
