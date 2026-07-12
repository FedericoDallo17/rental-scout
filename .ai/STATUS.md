# Status

Last updated: 2026-07-11. New here? Read `.ai/WORKFLOW.md` first — it's the dev loop.
Full audit context: docs/superpowers/reports/2026-07-06-state-of-the-project.md

## Current Phase
Ingest core complete; notification/ranking half not started

## Current Task
Ticket 014 — fix and land the in-flight InfoCasas work (uncommitted in working tree)

## Status
In progress

## Done
- Docs, tickets, governance, mock scraper pipeline, initial portal (06-27..06-29)
- Scraper domain ADR (007)
- Devise auth + user-owned saved searches, shared listing inventory (07-03..07-04)
- Real InfoCasas API adapter with timeouts and error handling (07-04)
- PostGIS zones: listing geometry at intake, zone-based feed filtering (07-05)
- Hourly RunScrapersJob configured via Solid Queue recurring tasks (unvalidated end-to-end)
- Full audit + decision records + roadmap refresh (07-06)
- Workflow guardrails: CSS-mirror test, STATUS structure test (replaced frozen
  bootstrap snapshot), ticket Definition-of-Done, shared `.claude/settings.json`,
  live-scrape and HTTP-layer-stubbing policy lines; `.ai/WORKFLOW.md` runbook (07-11)

## Doing
- Ticket 014: three uncommitted change sets need fixes and a 3-way commit split
  (adapter enrichment / coordinate backfill / header restyle). The backfill is
  functionally broken as written — do not commit as-is.

## Blockers
- None

## Risks
- No rate limiting or max-page guard against InfoCasas (ToS/operational risk)
- Seeded demo feed is empty (mock adapter violates the implicit contract — Ticket 016)
- Notifications remain unbuilt; the core product promise is unmet (Ticket 015)

## Human Input Needed
- Ticket 015 delivery channel (Pushover vs email) and credentials

## Next Step
Execute the plans in order — each is execution-ready (exact code, TDD steps, commit
boundaries), written for an agent with zero prior context:
1. docs/superpowers/plans/2026-07-06-ticket-014-land-in-flight-info-casas-work.md
2. docs/superpowers/plans/2026-07-06-ticket-015-notification-pipeline-mvp.md
3. docs/superpowers/plans/2026-07-06-ticket-016-adapter-contract-and-mock-fix.md (requires 014 first)
