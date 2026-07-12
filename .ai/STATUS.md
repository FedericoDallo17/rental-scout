# Status

Last updated: 2026-07-11. New here? Read `.ai/WORKFLOW.md` first - it's the dev loop.
Full audit context: docs/superpowers/reports/2026-07-06-state-of-the-project.md

## Current Phase
Ingest core complete; notification/ranking half not started

## Current Task
Ticket 015 - notification pipeline MVP

## Status
Ready for human delivery-channel decision, then implementation

## Done
- Docs, tickets, governance, mock scraper pipeline, initial portal (06-27..06-29)
- Scraper domain ADR (007)
- Devise auth + user-owned saved searches, shared listing inventory (07-03..07-04)
- Real InfoCasas API adapter timeouts error handling (07-04)
- PostGIS zones: listing geometry at intake, zone-based feed filtering (07-05)
- Hourly RunScrapersJob configured via Solid Queue recurring tasks (unvalidated end-to-end)
- Full audit + decision records + roadmap refresh (07-06)
- Workflow guardrails: CSS-mirror test, STATUS structure test (replaced frozen bootstrap snapshot), ticket Definition-of-Done, shared `.claude/settings.json`, live-scrape HTTP-layer-stubbing policy lines; `.ai/WORKFLOW.md` runbook (07-11)
- Ticket 014 landed: branded header/flash styling, InfoCasas pagination with max-page
  guard and throttles, coordinate backfill repaired to fetch listing detail pages
  directly (07-11; a concurrent session stamped this 07-12 in error)
- Follow-up to 014: removed the inline per-listing detail fetch from `fetch_listings`
  — a live probe showed the index returns 0/50 coordinates, so the "fallback" was a
  guaranteed 1+N (~2000 sequential GETs/run) and also fired a real HTTP request from
  the test suite. Coordinates now come from the backfill only. See
  adr-no-inline-detail-fetch; 014 plan carries the amendment spec (07-11)

## Doing
- Ticket 015 planning/implementation is next; choose delivery channel before coding.

## Blockers
- None

## Risks
- Seeded demo feed is empty (mock adapter violates the implicit contract - Ticket 016)
- Notifications remain unbuilt; the core product promise is unmet (Ticket 015)

## Human Input Needed
- Ticket 015 delivery channel (Pushover vs email) and credentials

## Next Step
Decide Ticket 015 delivery channel (Pushover vs email), then execute `docs/superpowers/plans/2026-07-06-ticket-015-notification-pipeline-mvp.md`.
