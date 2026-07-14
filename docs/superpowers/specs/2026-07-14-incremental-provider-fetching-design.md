# Ticket 034: Incremental Provider Fetching

Hourly acquisition is optimized per provider rather than forced into a false shared
pagination model. The orchestrator calls every adapter with source-local known
external IDs and an explicit reconciliation flag.

- InfoCasas already offers a publication-date window. Hourly runs keep it; weekly
  reconciliation removes the window but retains the existing hard page cap.
- Remax is recent-first and page-addressable. Hourly runs inspect at most three pages
  and stop after returning the first page containing any known ID. Weekly
  reconciliation ignores known-ID stopping and permits up to twenty pages.
- Imperium exposes `currentPage`. It follows the same 3/20 bounds and known-ID rule.
- Housi has no confirmed pagination contract in the captured HTML, so it remains one
  bounded recent result page rather than guessing a parameter.

Page results that repeat the same IDs terminate pagination, protecting against
providers that ignore page parameters. A page that triggers known-ID stopping is
still returned so `SeenListing#last_seen_at` stays current.

Weekly reconciliation runs at 03:30 Sunday and deliberately skips notification fan
out. This prevents older catalog discoveries from being announced as fresh. Hourly
notification idempotency remains unchanged.

