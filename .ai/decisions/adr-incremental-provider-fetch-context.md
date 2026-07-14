# ADR: Pass Fetch Context Into Source Adapters

## Status
Accepted (2026-07-14)

## Context
Provider freshness capabilities differ. InfoCasas has a publication-date window,
Remax and Imperium expose recent-first pages, and Housi has no confirmed pagination
contract. A no-argument adapter interface cannot stop recent-first traversal when it
reaches inventory already seen by that source.

## Decision
Adapters accept `known_external_ids:` and `reconciliation:` keyword arguments.
`RunOrchestrator` supplies source-local seen IDs. Incremental adapters use bounded
recent traversal and may stop after a page reaches a known ID. Reconciliation uses
larger bounds and ignores known-ID stopping. Reconciliation runs never enqueue new
listing notification fan-out.

## Alternatives Considered
- Query application models from inside each adapter: couples provider parsing to
  persistence and makes adapters harder to test.
- One generic pagination algorithm: invents capabilities Housi does not expose and
  ignores InfoCasas's stronger date-window contract.
- Notify after reconciliation: risks announcing old catalog entries as fresh.

## Provisional Areas
- Housi pagination can be added after a captured provider contract confirms the page parameter.
- Page limits can be tuned from measured run diagnostics.

## Consequences
- Adapters remain provider-specific but receive a consistent, explicit fetch context.
- Hourly request volume is bounded.
- Reconciliation can refresh deeper inventory without generating stale notifications.

## Related Tickets
- 028, 034, 017, 021

