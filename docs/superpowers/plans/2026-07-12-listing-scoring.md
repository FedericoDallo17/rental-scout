# Ticket 006 Listing Scoring Implementation Plan

1. Add focused unit tests for score boundaries, neutral defaults, completeness,
   explanations, and deterministic clamping.
2. Implement a small `ListingMatchScore` value object with no persistence or
   external dependencies.
3. Add an integration test proving the feed ranks by score, uses recency as a
   tie-breaker, and renders score explanations.
4. Wire scoring into `ListingsController` and the listing card.
5. Add minimal score styling to both mirrored stylesheets.
6. Update Ticket 006, roadmap, and status; run the full suite and commit.
