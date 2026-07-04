# User Ownership and Data Scoping Design

## Context
The app now has Devise-based authentication, an authenticated listings dashboard, and saved-search-driven feed filtering. But the current saved search model is still global: `SearchPreference` records are not attached to a user, and the listings controller currently loads all searches for every signed-in user.

That means authentication exists, but ownership does not. The first ownership ticket should make the current personalized surface safe for multi-user use without duplicating scraped inventory or prematurely forcing ownership into scraper-domain records.

The user-approved direction is:
- keep scraped listings global/shared
- avoid storing the same house separately per user
- make saved searches user-owned now
- scope listings-page search selection to the signed-in user
- prefer scoped queries like `current_user.something` to enforce boundaries

## Goals
- Make `SearchPreference` belong to `User`.
- Ensure signed-in users only see and activate their own saved searches.
- Keep the listings feed personalized through user-owned searches while continuing to read from shared global `Listing` data.
- Use query patterns centered on `current_user` ownership to reduce cross-user access risk.
- Preserve the current empty-state and feed behavior where possible.

## Non-Goals
- Making `Listing`, `ListingSource`, `ScrapingRun`, or scraper ingestion user-owned.
- Duplicating listings per user.
- Introducing per-user matched-feed records in this ticket.
- Changing scraper deduplication or ingestion behavior.
- Adding admin or cross-user visibility features.
- Reworking notification ownership in this ticket.

## Approaches Considered

### 1. User-own `SearchPreference`; keep listings and scraper records global
**Recommendation.**

Each user owns their saved searches, and the listings UI resolves active search context only from `current_user.search_preferences`. The feed remains a derived view over global listings.

Pros:
- Gives users personalized feeds without duplicating inventory.
- Keeps ownership aligned with the current user-facing product surface.
- Minimizes schema and controller churn.
- Leaves room for later favorites/matching/notification work.
- Encourages safe scoped-query patterns.

Cons:
- Does not yet create a persisted per-user match/feed layer.
- Some later personalized features will still need follow-up schema work.

### 2. User-own `SearchPreference` and add per-user matched/feed records now
Keep listings global, but add a new user-specific layer representing feed entries or matches.

Pros:
- More future-ready for notifications and favorites.
- Creates a clearer persisted personalization layer.

Cons:
- More schema and logic than the current app needs.
- Larger review and testing surface.
- Introduces product concepts that have not been designed yet.

### 3. Push ownership deeper into listings or scraper-adjacent records now
Attach broader domain data to users during the first ownership pass.

Pros:
- Stronger ownership posture immediately.

Cons:
- Conflicts with the desire to avoid duplicating the same scraped house for many users.
- Complicates ingestion and deduplication.
- Forces deeper domain decisions too early.

## Decision
Adopt the narrow ownership approach:
- make `SearchPreference` user-owned
- scope listings-page search resolution to `current_user`
- keep `Listing`, `ListingSource`, `ScrapingRun`, `SeenListing`, and current scraper ingestion global

## Design

### Ownership boundary
This ticket establishes ownership only where the current product experience actually needs it.

User-owned now:
- `SearchPreference`

Scoped by current user now:
- listings sidebar search list
- active search resolution from `params[:search_id]`
- any query deciding which saved searches a user can see or use

Still global for now:
- `Listing`
- `ListingSource`
- `ScrapingRun`
- `SeenListing`
- scraper ingestion pipeline
- notification events

This keeps shared inventory shared while making the dashboard/search layer safe for multiple users.

### Data model changes
`SearchPreference` should gain a required `user_id` foreign key to `users`.

Model relationships should become:
- `User has_many :search_preferences`
- `SearchPreference belongs_to :user`

`SearchPreference` ownership should be required at both the model and database level after migration.

### Query-scoping rules
The security posture for this ticket should rely on ownership-aware scoped queries instead of global lookups plus manual checks.

Preferred pattern:
- `current_user.search_preferences`

Avoid:
- `SearchPreference.find(...)` followed by ownership validation
- unscoped sidebar/search collections

In practice, the listings controller should:
- load sidebar searches from `current_user.search_preferences.ordered_for_sidebar`
- resolve `params[:search_id]` from that already-scoped relation
- fall back to the first saved search owned by the current user when the requested id is missing or not owned

This makes cross-user search ids naturally invisible to the query layer.

### Listings-page behavior
After this ticket:
- the sidebar shows only the signed-in user’s saved searches
- the active search can only be one of that user’s saved searches
- a foreign `search_id` is treated as unavailable, not exposed
- if the user has no saved searches, the current empty state remains
- the visible feed is still computed from global `Listing` records filtered by the active saved search

No scraper behavior changes in this ticket.

### Existing data handling
Because auth and ownership are both still early-stage and existing data is likely local/dev data, this ticket should take the simplest migration path.

Acceptable approaches for existing `search_preferences` data:
- assign records to an existing local user during migration or setup if needed
- or reset/reseed local data where that is simpler

This ticket should not add complicated legacy ownership rules or broad backfill machinery.

### Scope boundary around listings and scraper data
The feed remains personalized by filtering shared inventory through a user-owned saved search. That means:
- users get customized feeds
- the same listing is not duplicated per user
- scraper writes and deduplication rules stay unchanged

This is the key product/data-model boundary for the first ownership step.

## Testing Strategy

### 1. Ownership coverage
Add or update tests that prove:
- a user only sees their own saved searches
- a user cannot activate another user’s `search_id`
- default search selection uses that user’s first saved search only

### 2. Feed behavior coverage
Preserve coverage proving:
- global listings are still filtered by the selected saved search
- listings from unrelated locations are still excluded
- the empty state still appears when the current user has no saved searches

### 3. Model and relationship coverage
Add coverage proving:
- `SearchPreference` requires a user
- `User` owns many search preferences
- ownership-aware queries are used in the main listings flow behavior

## Risks and Mitigations
- **Risk:** A controller action accidentally uses global search queries again later.
  - **Mitigation:** Center controller lookup patterns on `current_user.search_preferences` and cover ownership behavior in integration tests.
- **Risk:** Existing local data becomes awkward during the migration.
  - **Mitigation:** Keep the migration/backfill expectations simple and acceptable for an early-stage app.
- **Risk:** The ticket grows into deeper listing or scraper ownership.
  - **Mitigation:** Keep all shared inventory records explicitly global in this design.
- **Risk:** Users infer that personalized feeds imply per-user listing storage.
  - **Mitigation:** Keep the design explicit that personalization is derived from shared listings plus owned searches.

## Sequencing
Recommended order after this ticket:
1. Auth foundation
2. User-owned saved searches and user-scoped listings search context
3. Favorites or matched-feed records, if needed
4. User-aware notifications and downstream personalization

This preserves the intended dependency chain:
- identity before ownership
- ownership before richer personalized features
- shared inventory before any deeper personalization layer

## Related Files
- `docs/superpowers/specs/2026-06-29-user-auth-ticket-design.md`
- `docs/superpowers/specs/2026-07-03-devise-auth-foundation-design.md`
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
