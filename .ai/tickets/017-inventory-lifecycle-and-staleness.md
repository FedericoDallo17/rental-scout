# Ticket: 017 - Purge Stale Listings After One Week

## Goal
Implement the freshness-first inventory lifecycle (adr-freshness-first-inventory):
hard-delete listings not seen in 7 days so the inventory stays a rolling one-week
window of fresh publications.

## Acceptance Criteria
- A daily Solid Queue recurring task deletes listings whose `updated_at` is older than
  7 days (updated_at is touched by intake on re-ingest, so re-published/bumped listings
  get a fresh week).
- The purge deletes each listing's `notification_events` (the association is
  `dependent: :restrict_with_exception` — handle explicitly, in batches, in a
  transaction per batch).
- `seen_listings` are nullified (existing `dependent: :nullify` behavior).
- A purged listing that is re-published is ingested as a new listing (existing intake
  behavior); re-notification is acceptable per the ADR.
- Purge counts are logged.

## Human Approval Required?
No (window and mechanism decided in adr-freshness-first-inventory)
