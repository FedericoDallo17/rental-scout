# User Auth and Ownership Ticket Design

## Context
The current ticket set assumes a portal/dashboard, saved preferences, listing scoring, scraping runs, and later notifications, but it does not yet define how the app identifies a user.

That gap matters because several planned behaviors are inherently user-specific:
- dashboard data should eventually belong to one user
- preferences and saved searches should eventually belong to one user
- matches and favorites should eventually be user-scoped
- notification delivery will later need a per-user destination

The user-approved direction is:
- add auth as new work, not as an implicit assumption
- use email/password authentication
- keep external notification identity separate from login
- keep the auth foundation ticket narrow
- split follow-up ownership, favorites, and notification identity into separate tickets

## Goals
- Define a clean ticket split for introducing user identity into the product plan.
- Add a foundational auth ticket that establishes accounts and session authentication.
- Keep ownership migration and later user features out of the auth foundation ticket.
- Preserve room for later Pushover-based notification identity without mixing it into authentication.

## Non-Goals
- Implementing the tickets in this spec.
- Attaching existing domain records to users in the auth foundation ticket.
- Designing phone-based or external-identity login.
- Designing favorites behavior in the auth foundation ticket.
- Designing notification sending in the auth foundation ticket.

## Approaches Considered

### 1. Split into focused dependent tickets
**Recommendation.**

Create one foundational authentication ticket, then follow it with separate ownership, favorites, and notification identity tickets.

Pros:
- Keeps authentication small and testable.
- Avoids mixing identity, authorization, and product features in one change.
- Creates a clear dependency chain for future work.
- Reduces the chance of over-scoping schema and UI work.

Cons:
- Requires more ticket management.
- Some user-visible value arrives across multiple tickets instead of one.

### 2. Put auth and ownership in one ticket
Create a larger ticket covering accounts, sessions, and immediate user-scoping of dashboard/search data.

Pros:
- Fewer tickets.
- Faster path to a truly personalized app surface.

Cons:
- Blurs the boundary between authentication and domain ownership.
- Harder to test and review incrementally.
- More likely to force premature schema decisions.

### 3. Create one full user-system ticket
Bundle auth, ownership, favorites, and notification identity together.

Pros:
- Single top-level work item.

Cons:
- Too large for clean implementation.
- High review and regression risk.
- Encourages unclear boundaries between account identity and app behavior.

## Decision
Use the split-ticket approach.

Add a foundational authentication ticket first, then separate follow-up tickets for ownership, favorites, and notification identity.

## Ticket Additions

### Ticket 014 — User Accounts and Session Authentication

#### Goal
Introduce email/password user accounts and session authentication so the app can identify a current user consistently.

#### Acceptance Criteria
- Users can register with email and password.
- Users can log in with email and password.
- Users can log out.
- A `User` model exists with a unique email.
- Passwords are stored securely rather than in plain text.
- Authenticated session state persists across requests.
- Protected pages require an authenticated user.
- Guest users are redirected to sign in.
- Tests cover registration, login, logout, and protected-route access.

#### Human Approval Required?
Yes

#### Scope Boundary
Included:
- base `User` identity record
- email/password credentials
- registration flow
- login flow
- logout flow
- session handling
- initial authenticated-only route protection

Excluded:
- attaching preferences, searches, listings, or matches to users
- favorites
- notification identity or notification delivery
- account settings beyond what auth requires

### Ticket 015 — User-Owned Dashboard and Search Data

#### Goal
Attach product data and dashboard visibility to the authenticated user so each user sees and manages only their own app data.

#### Acceptance Criteria
- Preferences are associated with `User`.
- Saved searches are associated with `User`.
- Any dashboard-visible search results or match/feed records used by the app at implementation time are associated with `User` or are derived only from that user's owned records.
- User-facing data queries are scoped to the current user.
- A user cannot view another user's dashboard/search data through normal app flows.
- Tests cover ownership and access boundaries.

#### Human Approval Required?
Yes

### Ticket 016 — Favorites for Searches and Matches

#### Goal
Allow users to save favorites for searches and matches without coupling that behavior to authentication itself.

#### Acceptance Criteria
- Users can favorite saved searches.
- Users can favorite the user-visible listing or match records that appear in the personalized dashboard/feed at implementation time.
- Favorites are scoped to the current user.
- Tests cover favorite creation and retrieval behavior.

#### Human Approval Required?
Yes

### Ticket 017 — Pushover Notification Identity

#### Goal
Store the user-specific notification identity/config needed for later Pushover delivery, while keeping it separate from login credentials.

#### Acceptance Criteria
- The user model or a related record can store the notification identity/config needed for Pushover.
- Notification identity is explicitly separate from authentication credentials.
- Later notification work can depend on this ticket without changing the login approach.
- Tests cover persistence and basic validation of the notification identity fields.

#### Human Approval Required?
Yes

## Sequencing
Recommended order:
1. Ticket 014 — establish who the current user is
2. Ticket 015 — establish which app data belongs to that user
3. Ticket 016 — add user-level favorites
4. Ticket 017 — add notification identity for later delivery work

This order preserves a clean dependency chain:
- authentication before ownership
- ownership before user-personalized features
- notification destination before notification sending

## Design Notes

### Authentication model
Authentication should be conventional email/password auth with session-based login.

External identifiers are not part of login. Notification destination data will be modeled later for Pushover and should remain conceptually separate from account authentication.

### Why Ticket 014 stays narrow
Ticket 014 should only answer: "who is the current user and can they sign in securely?"

It should not also answer:
- which preferences belong to which user
- how favorites behave
- where notifications for that user should be sent

That separation makes later ownership and product decisions easier to review and change.

### Relationship to existing tickets
- Ticket 004 introduced a general dashboard view but not user identity.
- Ticket 005 introduced preferences but not ownership.
- Ticket 009 and later scraper tickets will benefit from a stable notion of the current user before user-scoped views and notifications are added.

## Risks and Mitigations
- **Risk:** Auth ticket grows to include ownership work.
  - **Mitigation:** Keep Ticket 014 acceptance criteria limited to accounts and sessions only.
- **Risk:** Notification identity gets conflated with login identity.
  - **Mitigation:** Keep Pushover config in Ticket 017 and state that it is not used for authentication.
- **Risk:** Favorites implementation depends on ownership details not yet settled.
  - **Mitigation:** Make Ticket 016 depend on Ticket 015.

## Related Files
- `.ai/tickets/004-static-listings-dashboard.md`
- `.ai/tickets/005-search-preferences.md`
- `.ai/tickets/009-hourly-scraping-job.md`
- `.ai/tickets/011-scraping-runs-observability.md`
- `.ai/tickets/012-notification-events.md`
- `.ai/templates/ticket.md`
