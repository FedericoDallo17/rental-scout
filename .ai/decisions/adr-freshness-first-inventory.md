# ADR: Freshness-First Inventory — Purge After One Week

## Status
Accepted (2026-07-06, human decision)

## Context
The app-as-search-engine pivot (adr-postgis-app-as-search-engine) made the app an
inventory owner, raising two questions the audit flagged: how to handle stale/delisted
listings, and whether the last-hour acquisition window's incompleteness is a problem.
The human resolved both by clarifying the product identity: the scraper exists to
**"be the first to find a new listing"** — a freshness product, not a search catalog.
Users who want to browse the full market should use the source sites directly.

## Decision
1. **Completeness is a non-goal.** The last-hour (or last-day, per available source
   filters) acquisition window is a feature, not a gap. Listings published while the
   scraper is down are acceptable losses; no historical backfill of old publications.
2. **Hard-delete listings after one week.** Rationale: they won't reappear in a
   last-hour feed, a week gives users ample time, and desirable rentals rarely survive
   a week anyway. Purge criterion: **not seen in 7 days** (`listings.updated_at`, which
   intake touches on every re-ingest) rather than `created_at` — sources re-publish
   ("bump") listings, and a bumped listing re-enters the last-hour feed and should get
   a fresh week, not be purged mid-visibility.
3. Purge runs as a daily Solid Queue recurring task. It deletes the listing's
   `notification_events` with it (note: `Listing has_many :notification_events,
   dependent: :restrict_with_exception` — the purge must delete events explicitly or
   that association must change). `seen_listings` nullify automatically. A listing
   re-published after purge is ingested as new and may re-notify — acceptable and
   consistent with the freshness identity.

## Alternatives Considered
- Soft delete / `delisted_at` flag: rejected — extra state and filter complexity for a
  pilot with no consumer of listing history.
- Liveness re-checks against detail pages: rejected — solves catalog accuracy, which
  is a non-goal.

## Provisional Areas
- The 7-day window — revisit with real usage data.
- If a "save/favorite listing" feature is ever built, the purge must spare saved
  listings (today no such feature exists; "time to save it" currently means time to
  act on it off-platform).

## Consequences
- The database stays small (~1 week of Montevideo rental publications) and the feed is
  inherently fresh; no staleness filtering needed in queries.
- Notification delivery history older than a week disappears with its listings —
  acceptable at pilot stage.
- Supersedes the "mark inactive" framing in Ticket 017 (ticket updated).

## Related Tickets
- 017
