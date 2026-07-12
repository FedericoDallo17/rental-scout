# ADR: Conservative Cross-Source Listing Deduplication

## Status
Accepted (2026-07-12)

## Context
Provider-local IDs and URLs prevent repeats within one source but syndicated rentals
can appear in several providers. The development inventory contains confirmed
InfoCasas/Remax pairs with identical titles, prices, currencies, and bedroom counts.
Fuzzy matching risks hiding distinct rentals.

## Decision
After provider-local identity lookup, intake may reuse an existing listing from
another source only when normalized title, price, currency, and bedrooms all match.
All signature fields must be present. Title normalization is limited to whitespace
and case. The original listing remains the representative record and is not
overwritten; the new provider occurrence is retained as a `SeenListing` associated
with that representative.

## Consequences
- A cross-source occurrence is not counted as a new listing and cannot trigger a
  duplicate new-listing notification.
- Provider provenance remains available through `SeenListing`.
- Near matches remain separate. This intentionally favors false negatives over false
  merges until stronger property identity data exists.
