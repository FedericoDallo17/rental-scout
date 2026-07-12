# ADR: List Scrapes Never Fetch Per-Listing Detail Pages Inline

## Status
Accepted (2026-07-11)

## Context
The InfoCasas adapter's `normalized_listing` fetches a listing's detail HTML page
whenever the search index omits coordinates. A live probe (2026-07-11, single
request, 50 entries) showed the `searchFast` payload has **no coordinate fields at
all** — 0/50 entries carried `lat`/`lng` in any form — so the "fallback" fires for
100% of listings. Every scrape run is therefore pages + one blocking, sequential
detail GET per listing (up to ~2000 at MAX_PAGES, each with a 15s read timeout): a
guaranteed 1+N against a third-party site with no rate limiting on our side, coupling
fast list ingestion to the slowest and most failure-prone requests. It also
duplicates the coordinate backfill service, which fetches the same detail pages out
of band. Coordinates genuinely require the detail page (JSON-LD `geo` block); there
is no batch endpoint. The N requests are unavoidable — the defect is *where* they run.

## Decision
1. `fetch_listings` must never perform per-listing HTTP requests. One request per
   index page, nothing else.
2. Adapters map `latitude`/`longitude` from the index payload when the source
   provides them; otherwise they emit nil and intake resolves location via the
   neighborhood fallback.
3. Out-of-band enrichment (the coordinate backfill job) is the only place detail
   pages are fetched, batched and throttled, via the adapter's public
   `detail_coordinates_for_url`.
4. The adapter contract (Ticket 016) records `latitude`/`longitude` as optional
   index-time keys — sources that return geolocation on the index (a future source
   may) supply them for free; sources that don't defer to the backfill.

## Alternatives Considered
- Keep the inline fetch but parallelize/throttle it: still couples ingestion to N
  slow requests and still duplicates the backfill; freshness-first wants the list
  scrape fast so new listings enter the feed immediately (fallback zone matching
  works without coordinates).
- Inline fetch only for listings matching a saved-search neighborhood: premature
  optimization of the wrong layer; intake doesn't know match state.

## Provisional Areas
- Whether the backfill becomes a recurring task chained after each scrape run or
  stays manually/enqueued (decide in Ticket 014/017 territory).

## Consequences
- Scrape wall-clock drops from O(pages + listings) HTTP calls to O(pages).
- Fresh listings appear in the feed before coordinates resolve (fallback matching by
  neighborhood alias covers the gap); spatial matching upgrades when the backfill
  lands coordinates.
- The 014 plan is amended accordingly (see its PLAN UPDATE 2026-07-11 section).
  Timing: 014 executed from the unamended plan while this ADR was being written, so
  the inline fetch briefly landed on master and was removed in an immediate
  follow-up commit.

## Related Tickets
- 014 (amended plan), 016 (contract records optional index geolocation), 017
