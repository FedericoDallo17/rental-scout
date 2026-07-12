# Ticket: 024 - Conservative Cross-Source Deduplication

## Goal

Suppress confirmed cross-provider duplicates without fuzzy property matching.

## Acceptance Criteria

- [x] Exact normalized title, price, currency, and bedrooms reuse shared inventory.
- [x] Missing or differing signature fields keep listings separate.
- [x] The original representative and URL are not overwritten.
- [x] Every provider occurrence remains recorded in `SeenListing`.
- [x] Reused inventory is not marked new and cannot produce a duplicate notification.

## Human Approval Required?

Yes. Listing identity and duplicate-notification semantics changed; the user approved
the conservative signature on 2026-07-12.

## Definition of Done

- [x] `bin/rails test` green
- [x] `.ai/STATUS.md` updated
- [x] ADR and spec/plan committed alongside the work
