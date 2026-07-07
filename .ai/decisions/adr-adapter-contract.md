# ADR: Enforce a Normalized Adapter Contract Before Source #2

## Status
Accepted (2026-07-06)

## Context
Adapters return plain attribute hashes and the only contract is implicit: "respond to
`fetch_listings`, emit the right keys". Nothing validates the keys. The failure mode is
already live in the repo: `MockSourceAdapter` omits `source_city` and `operation_type`,
so `ListingScopeValidator` marks every mock listing out of scope and the seeded demo
feed is empty. A MercadoLibre adapter that forgets a key would fail just as silently.
Related gaps: currency is hardcoded to UYU and price filters are currency-blind; dedup
is per-source only; the scope validator matches literal Spanish tokens.

## Decision
Before any second real source is built (Ticket 016):
1. Define the normalized listing schema in one place and validate it at intake —
   missing required keys fail loudly (logged + source run marked failed), not silently.
2. Fix `MockSourceAdapter` to satisfy the contract, restoring the seeded demo feed.
3. Treat currency handling and cross-source dedup as explicit acceptance criteria of
   the future MercadoLibre ticket, not incidental follow-ups.

## Alternatives Considered
- Base class / interface module for adapters: heavier than needed; validation at the
  intake boundary catches the same errors regardless of adapter implementation style.
- Fix only the mock adapter: treats the symptom; the next adapter re-creates the bug.

## Provisional Areas
- Whether scope validation should be config-driven per source (city/operation tokens)
  or generalized into the contract itself.

## Consequences
- The demo works out of the box again.
- Source #2 becomes a mechanical task with a checkable contract instead of a silent
  correctness risk.

## Related Tickets
- 016 (new), 013, 008
