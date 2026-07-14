# Ticket: 034 - Incremental Provider Fetching

## Goal

Keep hourly acquisition freshness-first without repeatedly walking provider catalogs,
while retaining a bounded reconciliation path for edits and removals.

## Acceptance Criteria

- InfoCasas hourly fetches retain the publication-date window; reconciliation removes it.
- Remax and Imperium fetch bounded recent pages and stop after a page reaches a known ID.
- Housi remains a bounded single recent page because no pagination contract is confirmed.
- The orchestrator supplies each adapter with source-local known external IDs.
- Weekly reconciliation uses larger page bounds and never triggers new-listing notifications.
- All provider behavior is verified through HTTP-level stubs; no live scrape is run.

## Human Approval

Approved by the user on 2026-07-14.

## Definition of Done

- [x] Provider behavior covered with HTTP-level stubs
- [x] Full Rails test suite green
- [x] Architecture decision recorded
- [x] Status and roadmap updated
