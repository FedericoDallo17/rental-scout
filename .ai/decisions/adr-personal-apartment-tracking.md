# ADR: Private apartment history survives shared-inventory purge

## Status
Accepted. User approved the concrete proposal and migration on 2026-10-08.

## Context
Rental Scout hard-deletes inventory unseen for seven days. The user now needs favorites and independent dated contacts, visits and rejections.

## Decision
Keep a user-owned `listing_tracks` row with an optional inventory foreign key and a snapshot of the displayed property details. Nullify the inventory reference on deletion. Identify tracks uniquely by user, adapter key and external ID (canonical URL when no external ID exists). Reingestion reuses existing history. Feed tracking loads in one batch, personal history paginates independently of saved-search matches. Dates are editable independent marks, not a mutually exclusive state machine.

Persist optional min/max square meters on saved searches and apply them through the shared criteria filter. When bounded, unknown area does not match. Temporary dashboard controls retain their explicit include-unknown option.

## Alternatives Considered
- Preserve saved inventory rows: changes freshness retention and keeps stale property records in shared matching.
- Cascading tracking deletion: loses the personal history the feature is intended to preserve.
- Single status field: cannot retain a contact and visit after rejection.

## Provisional Areas
Snapshots reflect details at the last tracking save; original portals may remove their linked pages. Stable identity is source-local and does not infer new cross-source equivalence.

## Consequences
Personal history outlives shared inventory and is removed with its owning user. Existing searches have no added area restriction. No new dependency, worker or external request is introduced.

## Related Tickets
- User-requested apartment tracking and search area, 2026-10-08.
- Supersedes the favorite-retention provisional section of adr-freshness-first-inventory; shared inventory retention remains unchanged.
