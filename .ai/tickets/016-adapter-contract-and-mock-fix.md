# Ticket: 016 - Adapter Contract and Mock Adapter Fix

## Goal
Enforce the normalized listing attribute contract at intake and fix the mock adapter
so the seeded demo feed shows listings again (see adr-adapter-contract).

## Acceptance Criteria
- Required keys are defined in one place and validated at intake; violations fail
  loudly (logged, source run marked failed) instead of silently producing
  out-of-scope listings.
- `MockSourceAdapter` emits `source_city` and `operation_type`; a fresh `bin/setup`
  plus a scrape yields a non-empty demo feed.
- `info_casas_legacy_map.rb` (dead code) is deleted.

## Human Approval Required?
No
