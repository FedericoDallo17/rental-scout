# Ticket: 014 - Land In-Flight InfoCasas Work

## Goal
Fix and commit the three mingled uncommitted change sets (adapter enrichment,
coordinate backfill, header restyle) identified in the 2026-07-06 audit.

## Acceptance Criteria
- Backfill fetches coordinates via each listing's `canonical_url` detail page instead
  of the last-hour search feed, and fetches once (not per batch).
- Adapter pagination has a max-page guard and rate limiting; detail-fetch errors are
  logged, not silently swallowed.
- Work lands as three commits: adapter enrichment, backfill, header restyle.
- The `public/stylesheets` mirror comment is restored (it is not a Propshaft artifact).

## Human Approval Required?
No
