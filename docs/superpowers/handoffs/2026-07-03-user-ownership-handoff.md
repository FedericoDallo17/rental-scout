> **SUPERSEDED (2026-07-06):** point-in-time handoff; the work described here has since shipped. Current state: `.ai/STATUS.md`.

# User Ownership Handoff

## Status
Do **not** continue implementation in this session. User explicitly asked for a handoff so the next step can start in a fresh session.

## Current implementation state
This session completed substantial **auth foundation** and **auth page styling** work in the working tree, but it has **not been committed**.

Implemented and verified in the current working tree:
- Devise-based auth foundation
- `User` model with:
  - `first_name`
  - `last_name`
  - `email`
  - `encrypted_password`
  - optional `pushover_user_key`
- sign-in-first root behavior
- protected app pages
- styled auth pages for:
  - sign in
  - sign up
  - forgot password
  - reset password

Verification already run in this session:
- `bin/rails test`
- focused auth/listings integration tests
- `bin/rails routes`

The latest review result for the auth styling work was effectively: **ready to merge**, but no commit was created because the user did not ask for one.

## Next topic
Fresh session should pick up **user ownership / data scoping** after auth.

This is the next planned sequencing from the existing auth design:
1. auth foundation
2. user ownership of product data
3. user-aware scraper outputs and downstream matching/notification work

## Core unresolved question from the user
The user chose the **broadest ownership direction** when asked what the first ownership ticket should cover:

- **Saved searches + broader domain ownership**

But the key unresolved design question is still this:

> Should the first ownership ticket make only the **currently user-facing product records** user-owned, or should it start attaching ownership to **broader domain records** now?

My recommendation during brainstorming was:

### Recommended ownership boundary
**User-owned now**
- `SearchPreference`

**Scoped by current user now**
- listings page sidebar/search selection
- active search resolution
- any query that decides which searches a user can see

**Still global for now**
- `Listing`
- `ListingSource`
- `ScrapingRun`
- scraper ingestion pipeline itself

Reasoning:
- makes the app safely multi-user at the **search/dashboard layer**
- keeps scraped inventory global until per-user matching is explicitly designed
- avoids prematurely attaching ownership to records that are really shared/global inventory

## Important question to ask first in the fresh session
Fresh agent should start by confirming this exact boundary question:

> Do we want the first ownership ticket to keep **listings/scraper records global** while making **search preferences and dashboard-visible search context user-owned**, or do we want to push ownership deeper into broader domain records immediately?

That is the key unresolved product/data-model decision.

## Existing code to inspect first
Fresh agent should read these first:
- `docs/superpowers/specs/2026-06-29-user-auth-ticket-design.md`
- `docs/superpowers/specs/2026-07-03-devise-auth-foundation-design.md`
- `docs/superpowers/specs/2026-07-03-auth-page-styling-design.md`
- `app/models/user.rb`
- `app/models/search_preference.rb`
- `app/models/listing.rb`
- `app/controllers/listings_controller.rb`
- `config/routes.rb`
- `db/migrate/20260627123000_create_core_models.rb`
- `db/migrate/20260703120000_devise_create_users.rb`
- `test/controllers/listings_controller_test.rb`
- `test/integration/listings_flow_test.rb`
- `test/integration/authentication_flow_test.rb`

## Suggested next process for fresh agent
1. Use **brainstorming** first
2. Confirm the ownership boundary question above
3. Write the ownership/data-scoping spec
4. Then write the implementation plan
5. Then implement with TDD

## One-sentence summary
Auth is now in place and styled, but the next fresh session should decide whether the first ownership ticket should stop at **user-owned searches and user-scoped dashboard/search context** while keeping listings global, or whether ownership should be pushed deeper into broader domain records immediately.