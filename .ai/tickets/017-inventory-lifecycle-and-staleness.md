# Ticket: 017 - Inventory Lifecycle and Staleness

## Goal
Handle the consequence of the app-as-search-engine pivot (adr-postgis-app-as-search-engine):
the app now owns a growing shared inventory, but nothing ever detects that a listing was
rented or delisted, so the feed accumulates stale results forever.

## Acceptance Criteria
- Listings not seen by any scrape for a defined window (proposal: 7 days, using
  `seen_listings.last_seen_at`) are marked inactive (e.g. `delisted_at` timestamp).
- `Listing.for_search_feed` excludes inactive listings.
- Reappearing listings are reactivated by intake.
- The window and mechanism are recorded as an ADR before implementation, including how
  the last-hour scrape window interacts with staleness detection (a listing can be live
  on InfoCasas yet unseen by us for weeks — the design must account for that, e.g. via
  periodic detail-page liveness checks or a broader periodic re-scrape).

## Human Approval Required?
Yes (staleness window and re-check strategy)
