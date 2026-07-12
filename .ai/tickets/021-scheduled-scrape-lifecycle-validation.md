# Ticket: 021 - Scheduled Scrape Lifecycle Validation

## Goal

Prove the configured scrape job carries a provider result through intake, matching,
notification fan-out, and delivery without making a live request.

## Acceptance Criteria

- [x] The test exercises a real adapter with its HTTP boundary stubbed.
- [x] The queued notification job delivers the newly ingested matching listing.
- [x] A second identical run does not create or deliver a duplicate notification.
- [x] The recurring configuration remains covered for every environment.

## Human Approval Required?

No. This validates existing approved jobs, provider, and idempotency rules; it does
not enable a new integration or change retry behavior.

## Definition of Done

- [x] `bin/rails test` green
- [x] `.ai/STATUS.md` updated
- [x] Spec/plan committed alongside the test
