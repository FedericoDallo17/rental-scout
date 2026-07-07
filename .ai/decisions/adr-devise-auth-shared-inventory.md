# ADR: Devise Auth with User-Owned Searches over Shared Inventory

## Status
Accepted (retroactive record, written 2026-07-06 for work shipped 2026-07-04)

## Context
The 2026-07-03/04 cycles added authentication and data scoping. Devise was adopted and
an ownership model chosen, but no decision record was written and the roadmap/tickets
(014–017 were planned but never created) don't reflect it.

## Decision
- Devise for authentication (`authenticate_user!` globally).
- `SearchPreference` (and its zones and seen-listing state) belong to a user; all
  controller access goes through `current_user` scoping.
- `Listing` inventory is deliberately global/shared — listings are facts about the
  world, not user data.
- `users.pushover_user_key` is stored at signup time for future notification delivery.

## Alternatives Considered
- Hand-rolled auth (has_secure_password): rejected — Devise buys recoverable/rememberable
  flows for free in a pilot where auth is not the interesting problem.
- Per-user listing copies: rejected — duplicates inventory and breaks shared dedup.

## Provisional Areas
- Mailer configuration is defaulted (`from@example.com`, no host options) — must be
  fixed before any real password-reset or notification email is sent.

## Consequences
- Feed access is IDOR-safe (verified in the 2026-07-06 audit).
- Devise views/scaffolding dominate `app/views` LOC; harmless.

## Related Tickets
- Cycles: docs/superpowers/specs/2026-07-03-devise-auth-foundation-design.md,
  docs/superpowers/specs/2026-07-04-user-ownership-data-scoping-design.md
