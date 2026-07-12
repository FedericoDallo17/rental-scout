# Ticket: 023 - Grouped Run Notifications

## Goal

Send one Pushover summary per user and scraping run, linking to the persisted matches
that caused the notification.

## Acceptance Criteria

- [x] Overlapping saved searches produce one push per user per run.
- [x] The push reports the distinct listing count and links to the run results.
- [x] The authenticated results page shows persisted matches and matching search names.
- [x] Users cannot see another user's matches.
- [x] Match-level events retain delivery status and idempotency history.

## Human Approval Required?

Yes. This changes notification delivery architecture; approved by the user on
2026-07-12 before implementation.

## Definition of Done

- [x] `bin/rails test` green
- [x] `.ai/STATUS.md` updated
- [x] Spec/plan committed alongside the work
