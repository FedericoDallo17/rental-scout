# Status

Last updated: 2026-07-12. New here? Read `.ai/WORKFLOW.md` first - it's the dev loop.
Full audit context: docs/superpowers/reports/2026-07-06-state-of-the-project.md

## Current Phase
Freshness-first MVP lifecycle complete; bilingual signed-in experience complete

## Current Task
Ticket 027 bilingual user interface complete

## Status
Ticket 026 live probes confirm city-wide neighborhood diversity and valid canonical URLs. Remax supplies coordinates for every sampled result; InfoCasas, Housi, and Imperium index responses do not. InfoCasas detail JSON-LD supplies coordinates, so its existing backfill is now capped and scheduled daily. MercadoLibre remains paused until API keys or an allowed index payload sample are available.

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
- Ticket 006 landed: transient saved-search scoring ranks the feed and displays concise match explanations without a migration (07-12)
- Ticket 021 landed: scheduled scrape-to-notification lifecycle validated without live provider or notification calls, including repeat-run idempotency (07-12)
- Ticket 022 landed: secure authenticated Pushover user-key settings close the notification configuration UI gap (07-12)
- Ticket 023 landed: grouped per-user run summaries link to persisted, user-isolated match results; live Pushover credentials and delivery validated (07-12)
- Ticket 024 landed: conservative cross-source identity suppresses confirmed syndicated duplicates without fuzzy merging (07-12)
- InfoCasas location follow-up: explicit Villa del Cerro and misspelled Buce0 titles normalize to Cerro/Buceo and override incorrect Centro provider fallbacks (07-12)
- Remax URL follow-up: canonical detail URLs now use the provider's `/listings/:slug` route without an invented trailing ID (07-12)
- Source coverage follow-up: Remax, Housi, and Imperium queries are Montevideo-wide instead of Pocitos-only; missing neighborhoods are no longer mislabeled as Pocitos (07-12)
- Authoritative neighborhoods: IDE Uruguay's 62-feature Montevideo GeoJSON has a reproducible import task and coordinate-based labels override provider metadata (07-12)
- Ticket 025 landed: the runs workbench reports spatial, provider-fallback, unresolved, and provider-versus-polygon mismatch counts (07-12)
- Ticket 026 landed: per-source coordinate coverage is visible; one-page probes validated all four real providers; InfoCasas detail backfill succeeded for 3/3 sampled listings and is scheduled daily with a limit of 20 (07-12)
- Ticket 027 landed: each user can persist English or Spanish; signed-in navigation, feed, searches, runs, notifications, flashes, and score explanations render request-scoped translations (07-12)

## Doing
- Waiting for MercadoLibre API keys or next product gap selection.

## Blockers
- MercadoLibre public API and HTML probes return access/login gates from this environment; user is obtaining API keys.

## Risks
- Second source introduces currency handling and cross-source dedup risks called out in adapter-contract ADR.
- Real Pushover delivery requires runtime `PUSHOVER_API_TOKEN` and real user `pushover_user_key`; tests use injected fake clients.

## Human Input Needed
- Provide runtime `PUSHOVER_API_TOKEN` before manual end-to-end push validation;
  users can now enter their own Pushover keys in the app.

## Next Step
Resume Ticket 018 when MercadoLibre API keys or an allowed index payload sample are available; otherwise evaluate cached address geocoding for Housi and Imperium or choose another small unblocked product gap.
