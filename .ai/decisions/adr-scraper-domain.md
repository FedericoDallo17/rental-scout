# ADR: Scraper Domain

## Status
Accepted

## Context
Rental Scout Lite continues a validated idea. `../home_scraper` proved the scraper-and-notification loop in practice. `../scraper` was the hand-built attempt to wrap that behavior in a fuller application, and its technical decisions still reflect the intended app direction.

The project therefore needs a domain record that says:
- scraper behavior should stay close to `../home_scraper`
- application/domain structure should be heavily inspired by `../scraper`
- the current core entities are stable enough for the next tickets, but some areas remain explicitly provisional

## Decision
The scraper domain is defined around these concepts:
- `Listing`: normalized apartment record used by the app
- `ListingSource`: source registry/runtime anchor for one provider feed
- `ScrapingRun`: one top-level scheduler-triggered scraping execution
- `ScrapingSourceRun`: one source-specific outcome inside a `ScrapingRun`
- `SeenListing`: deduplication memory used for repeated-run safety
- `NotificationEvent`: recorded notification-worthy event, distinct from delivery

Deduplication rules:
1. Prefer `source + external_id` when external ID exists.
2. Fallback to `source + canonical_url` when external ID is absent or unstable.

"New listing" means newly discovered relative to deduplication state, not merely present in the latest scrape.

Notification idempotency rule:
- the same listing should not create duplicate notification events for the same logical notification context once already recognized and recorded.

Relationship to prior systems:
- keep scraper loop behavior close to `../home_scraper`
- keep application/domain direction heavily inspired by `../scraper`

Provisional areas:
- how far saved-search modeling should converge with `../scraper`
- whether `Match` becomes a persisted model
- whether source registry and adapter identity should separate further later

## Consequences
- Tickets 008 and 009 now have an explicit domain baseline.
- Current bootstrap models are acceptable as a starting point, but not beyond review or reshaping.
- Future scraper changes should be justified against this ADR instead of implicit chat history.

## Related Tickets
- 007-scraper-domain-design
- 008-mock-source-adapter
- 009-hourly-scraping-job
