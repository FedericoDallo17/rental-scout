# Status

Last updated: 2026-07-12. New here? Read `.ai/WORKFLOW.md` first - it's the dev loop.
Full audit context: docs/superpowers/reports/2026-07-06-state-of-the-project.md

## Current Phase
Ingest, notification MVP, and adapter contract hardening complete; stale-listing purge next

## Current Task
Ticket 017 - purge stale listings after one week

## Status
Ready to implement Ticket 017

## Done
- Docs, tickets, governance, mock scraper pipeline, initial portal (06-27..06-29)
- Scraper domain ADR (007)
- Devise auth + user-owned saved searches, shared listing inventory (07-03..07-04)
- Real InfoCasas API adapter timeouts error handling (07-04)
- PostGIS zones: listing geometry at intake, zone-based feed filtering (07-05)
- Hourly RunScrapersJob configured via Solid Queue recurring tasks (unvalidated end-to-end)
- Full audit + decision records + roadmap refresh (07-06)
- Workflow guardrails: CSS-mirror test, STATUS structure test (replaced frozen bootstrap snapshot), ticket Definition-of-Done, shared `.claude/settings.json`, live-scrape HTTP-layer-stubbing policy lines; `.ai/WORKFLOW.md` runbook (07-11)
- Ticket 014 landed: branded header/flash styling, InfoCasas pagination max-page guard throttles, coordinate backfill repaired to fetch listing detail pages directly (07-11; concurrent session stamped 07-12 in error)
- Follow-up 014: removed inline per-listing detail from `fetch_listings`; live probe showed index returns 0/50 coordinates, so fallback would guarantee 1+N detail requests during list scrape. Coordinates now come from backfill only. See `adr-no-inline-detail-fetch`; 014 plan carries amendment.
- Ticket 015 landed: new-listing notification fan-out, Pushover delivery seam/client, and `NotifyNewListingsJob` enqueued after scrape runs (07-12)
- Ticket 016 landed: intake enforces normalized adapter contract, mock adapter emits scope metadata and restores demo feed, dead InfoCasas legacy map deleted (07-12)

## Doing
- Ticket 017 is next: purge stale listings after one week per freshness-first ADR.

## Blockers
- None

## Risks
- Stale listings are not purged yet; inventory will keep growing until Ticket 017 lands.
- Real Pushover delivery requires runtime `PUSHOVER_API_TOKEN` and real user `pushover_user_key`; tests use injected fake clients.

## Human Input Needed
- Provide `PUSHOVER_API_TOKEN` and user Pushover keys before manual end-to-end push validation.

## Next Step
Execute Ticket 017 stale-listing purge plan.
